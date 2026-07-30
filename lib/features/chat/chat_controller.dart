import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../compliance/ai_consent/ai_consent_gate.dart';
import '../../core/data_providers.dart';
import '../../core/network/sse_event.dart';
import '../../core/providers.dart';
import '../../shared/models/chat.dart';
import 'chat_repository.dart';

/// Genera un UUID v4. El backend hace upsert de la sesión con este id.
String nuevoSessionId() {
  final math.Random r = math.Random.secure();
  String h(int n) =>
      List<String>.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-a${h(3)}-${h(12)}';
}

/// Caso ligado a la conversación, tal como lo anunció el servidor.
class CasoDelChat {
  const CasoDelChat({
    required this.matterId,
    required this.nombre,
    this.codigo,
  });

  final String matterId;
  final String nombre;
  final String? codigo;
}

/// Propuesta del agente para convertir la conversación en caso.
class SugerenciaCaso {
  const SugerenciaCaso({
    this.nombre,
    this.cliente,
    this.contraparte,
    this.materia,
    this.radicado,
  });

  final String? nombre;
  final String? cliente;
  final String? contraparte;
  final String? materia;
  final String? radicado;

  /// Lo que se manda a `promote-to-case`. Se omiten los nulos para no pisar
  /// con vacíos lo que el servidor pueda deducir mejor.
  Map<String, dynamic> get cuerpo => <String, dynamic>{
    if (nombre != null) 'nombre': nombre,
    if (cliente != null) 'cliente': cliente,
    if (contraparte != null) 'contraparte': contraparte,
    if (materia != null) 'materia': materia,
    if (radicado != null) 'radicado': radicado,
  };
}

/// Estado de la pantalla de chat.
class ChatState {
  const ChatState({
    required this.sessionId,
    this.mensajes = const <Mensaje>[],
    this.enCurso = false,
    this.cargando = false,
    this.errorCarga,
    this.creditos,
    this.tituloSesion,
    this.caso,
    this.sugerencia,
    this.promocionando = false,
  });

  final String sessionId;
  final List<Mensaje> mensajes;

  /// Caso al que quedó ligada la conversación, si lo hay.
  ///
  /// A partir de aquí **todos** los turnos van con `matter_id`: el trabajo se
  /// guarda dentro del expediente, no suelto en un chat.
  final CasoDelChat? caso;

  /// Propuesta pendiente de convertir el chat en caso. Se descarta en cuanto
  /// existe [caso].
  final SugerenciaCaso? sugerencia;

  /// Hay una promoción a caso en vuelo (evita el doble toque).
  final bool promocionando;

  /// Hay un turno generándose **desde este dispositivo**.
  final bool enCurso;

  /// Se está cargando el historial de la sesión.
  final bool cargando;
  final String? errorCarga;
  final int? creditos;
  final String? tituloSesion;

  /// ¿Hay un turno generándose en **otro** dispositivo?
  ///
  /// Se detecta al cargar: un mensaje del asistente en `streaming` que no
  /// lanzamos nosotros. Mientras dure, el composer se bloquea para no colisionar
  /// en el `seq` (arquitectura §11.5).
  bool get generandoEnOtroDispositivo =>
      !enCurso &&
      mensajes.any(
        (Mensaje m) =>
            !m.esUsuario && m.clasificar() == EstadoMensaje.generando,
      );

  bool get composerBloqueado => enCurso || generandoEnOtroDispositivo;

  ChatState copyWith({
    String? sessionId,
    List<Mensaje>? mensajes,
    bool? enCurso,
    bool? cargando,
    String? errorCarga,
    bool limpiarError = false,
    int? creditos,
    String? tituloSesion,
    CasoDelChat? caso,
    SugerenciaCaso? sugerencia,
    bool limpiarSugerencia = false,
    bool? promocionando,
  }) => ChatState(
    sessionId: sessionId ?? this.sessionId,
    mensajes: mensajes ?? this.mensajes,
    enCurso: enCurso ?? this.enCurso,
    cargando: cargando ?? this.cargando,
    errorCarga: limpiarError ? null : (errorCarga ?? this.errorCarga),
    creditos: creditos ?? this.creditos,
    tituloSesion: tituloSesion ?? this.tituloSesion,
    caso: caso ?? this.caso,
    sugerencia: limpiarSugerencia ? null : (sugerencia ?? this.sugerencia),
    promocionando: promocionando ?? this.promocionando,
  );
}

/// Controlador del chat.
///
/// Reglas que implementa y que no se pueden relajar (arquitectura §10.3):
///  · **Nunca reenvía un turno** tras una caída: el backend ya persistió lo
///    hecho y reenviar duplicaría el mensaje y volvería a cobrar créditos.
///    En su lugar recarga la sesión.
///  · El silencio no es desconexión: eso lo gestiona [SseClient] con los latidos.
///  · Al recibir `blocked` **informa y no vende** (Apple 3.1.1 / 3.1.3).
class ChatController extends AutoDisposeFamilyNotifier<ChatState, String?> {
  StreamSubscription<SseEvent>? _sub;
  DateTime? _inicioTurno;
  ChatRepository? _repo;

  @override
  ChatState build(String? sessionId) {
    ref.onDispose(() {
      _sub?.cancel();
      _repo?.cancelar();
    });

    final String id = sessionId ?? nuevoSessionId();
    if (sessionId != null) {
      // Sesión existente: se pide SIEMPRE fresca, nunca de caché (§11.3).
      Future<void>.microtask(cargarHistorial);
      return ChatState(sessionId: id, cargando: true);
    }
    return ChatState(sessionId: id);
  }

  /// Carga el historial completo desde el servidor.
  Future<void> cargarHistorial() async {
    state = state.copyWith(cargando: true, limpiarError: true);
    try {
      final Map<String, dynamic> j = await ref
          .read(apiClientProvider)
          .get('/api/sessions/${state.sessionId}');

      final List<dynamic> crudos =
          (j['messages'] as List<dynamic>?) ?? <dynamic>[];
      // El backend ya los devuelve ordenados (`order=seq.asc`) y APLANADOS:
      // el índice del array es el orden. No hay `seq` que ordenar.
      final List<Mensaje> mensajes = <Mensaje>[];
      for (int i = 0; i < crudos.length; i++) {
        final dynamic m = crudos[i];
        if (m is Map) {
          mensajes.add(
            Mensaje.fromJson(Map<String, dynamic>.from(m), indice: i),
          );
        }
      }

      state = state.copyWith(
        mensajes: mensajes,
        cargando: false,
        tituloSesion: j['title'] as String?,
        // El servidor sí lo devuelve el día que lo exponga; mientras tanto se
        // recupera del dispositivo (ver [_ligarACaso]).
        caso: _casoDe(j) ?? await _casoRecordado(),
      );
    } on Object catch (e) {
      state = state.copyWith(cargando: false, errorCarga: '$e');
    }
  }

  /// Lee el caso de la respuesta de la sesión **si** el backend lo incluye.
  ///
  /// Hoy `get_session` solo selecciona `id,title`, así que esto devuelve null.
  /// Se deja escrito para que el día que se añada el campo la app lo tome sola,
  /// sin tener que acordarse de este archivo.
  static CasoDelChat? _casoDe(Map<String, dynamic> j) {
    final String? id = j['matter_id'] as String?;
    if (id == null || id.isEmpty) return null;
    return CasoDelChat(
      matterId: id,
      nombre: j['matter_name'] as String? ?? j['name'] as String? ?? 'Caso',
      codigo: j['matter_code'] as String? ?? j['code'] as String?,
    );
  }

  /// Envía un turno.
  ///
  /// Devuelve `false` si no hay consentimiento de IA: el token no se puede
  /// emitir y el repositorio del agente no se puede construir.
  bool enviar(
    String texto, {
    String? matterId,
    List<String>? documentIds,
    String? editArtifactId,
    String? seleccion,
  }) {
    final String limpio = texto.trim();
    if (limpio.isEmpty || state.composerBloqueado) return false;

    final AiConsentToken? token = AiConsentGate.tokenPara(
      ref.read(aiConsentProvider).valueOrNull,
    );
    if (token == null) return false;

    _repo = ChatRepository(
      sse: ref.read(sseClientProvider),
      consentimiento: token,
    );

    final String idTurno = DateTime.now().microsecondsSinceEpoch.toString();
    final Mensaje pregunta = Mensaje(
      id: 'u$idTurno',
      esUsuario: true,
      texto: limpio,
      creadoEn: DateTime.now(),
      seq: state.mensajes.length,
    );
    final Mensaje respuesta = Mensaje(
      id: 'a$idTurno',
      esUsuario: false,
      status: 'streaming',
      creadoEn: DateTime.now(),
      seq: state.mensajes.length + 1,
    );

    _inicioTurno = DateTime.now();
    state = state.copyWith(
      mensajes: <Mensaje>[...state.mensajes, pregunta, respuesta],
      enCurso: true,
    );

    _sub = _repo!
        .enviar(
          sessionId: state.sessionId,
          mensaje: limpio,
          // Una vez la conversación tiene caso, **todos** los turnos van con
          // él aunque la pantalla no lo pase: si no, el trabajo se guardaría
          // fuera del expediente que el propio agente acaba de crear.
          matterId: matterId ?? state.caso?.matterId,
          documentIds: documentIds,
          editArtifactId: editArtifactId,
          seleccion: seleccion,
        )
        .listen(
          (SseEvent e) => _procesar(e, respuesta),
          onDone: _cerrarTurno,
          onError: (Object _) => _cerrarTurno(),
        );
    return true;
  }

  void _cerrarTurno() {
    if (!state.enCurso) return;
    // Si el stream murió sin `done`, el turno quedó a medias en el servidor.
    // Se recarga la sesión: NUNCA se reenvía.
    final Mensaje? ultimo = state.mensajes.isNotEmpty
        ? state.mensajes.last
        : null;
    if (ultimo != null && !ultimo.esUsuario && ultimo.status == 'streaming') {
      ultimo.status = 'complete';
      if (!ultimo.tieneContenido && ultimo.error == null) {
        ultimo.error = 'La respuesta se interrumpió. Desliza para recargar.';
      }
    }
    state = state.copyWith(
      enCurso: false,
      mensajes: <Mensaje>[...state.mensajes],
    );
  }

  void _procesar(SseEvent e, Mensaje m) {
    switch (e) {
      case Thinking(:final String texto):
        m.razonamiento += texto;

      case TextDelta(:final String texto):
        if (m.segundosPensando == null && _inicioTurno != null) {
          m.segundosPensando = DateTime.now()
              .difference(_inicioTurno!)
              .inSeconds;
        }
        m.texto += texto;

      case Phase(:final String nombre, :final String estado):
        final PasoActividad? existente = m.pasos
            .where((PasoActividad p) => p.nombre == nombre)
            .firstOrNull;
        if (existente != null) {
          existente.estado = estado;
        } else {
          m.pasos.add(PasoActividad(nombre: nombre, estado: estado));
        }

      case AgentStep(:final Map<String, dynamic> datos):
        final String nombre =
            datos['name'] as String? ?? datos['step'] as String? ?? 'paso';
        m.pasos.add(PasoActividad(nombre: nombre, estado: 'done'));

      case ToolCall(:final String id, :final String nombre):
        m.pasos.add(PasoActividad(nombre: _nombreLegible(nombre), detalle: id));

      case ToolResult(:final Map<String, dynamic> datos):
        final String? id = datos['id'] as String?;
        for (final PasoActividad p in m.pasos) {
          if (p.detalle == id) p.estado = 'done';
        }
        // Algunas herramientas devuelven fuentes consultadas o verificadas.
        final List<dynamic>? fuentes =
            (datos['sources'] ?? datos['fuentes']) as List<dynamic>?;
        if (fuentes != null) {
          for (final dynamic f in fuentes) {
            if (f is Map) {
              m.fuentes.add(Fuente.fromJson(Map<String, dynamic>.from(f)));
            }
          }
        }

      case VerifyProgress(:final String estado):
        final PasoActividad? verif = m.pasos
            .where((PasoActividad p) => p.nombre == 'Verificando fuentes')
            .firstOrNull;
        if (verif == null) {
          m.pasos.add(
            PasoActividad(nombre: 'Verificando fuentes', estado: estado),
          );
        } else {
          verif.estado = estado;
        }

      case Artifact(:final Map<String, dynamic> datos):
        m.artefactos.add(Artefacto.fromJson(datos));

      case Hooks(hooks: final List<Hook> hs):
        m.hooks
          ..clear()
          ..addAll(
            hs.map(
              (Hook h) => HookAccion(
                etiqueta: h.etiqueta,
                prompt: h.prompt,
                tipo: h.tipo,
              ),
            ),
          );

      case CaseSuggestion(
        :final String? nombre,
        :final String? cliente,
        :final String? contraparte,
        :final String? materia,
        :final String? radicado,
      ):
        // Si el caso ya existe, la sugerencia llega tarde y se ignora.
        if (state.caso == null) {
          state = state.copyWith(
            sugerencia: SugerenciaCaso(
              nombre: nombre,
              cliente: cliente,
              contraparte: contraparte,
              materia: materia,
              radicado: radicado,
            ),
          );
        }

      case CaseCreated(
        :final String matterId,
        :final String nombre,
        :final String? codigo,
      ):
        _ligarACaso(
          CasoDelChat(matterId: matterId, nombre: nombre, codigo: codigo),
        );

      case Credits(:final int? saldo):
        state = state.copyWith(creditos: saldo);

      case Blocked(:final String? mensaje):
        // ⚠️ Informar, NO vender: sin botón ni enlace de compra.
        m
          ..status = 'complete'
          ..bloqueado = true
          ..error = mensaje ?? 'Alcanzaste el límite de tu plan.';

      case ErrorEvent(:final String mensaje):
        m
          ..status = 'complete'
          ..error = mensaje;

      case Done():
        m.status = 'complete';
        // El turno pudo consumir cuota: se refresca el estado de la cuenta.
        unawaited(ref.read(meProvider.notifier).refrescar());

      case Usage():
      case ApprovalRequest():
      case Heartbeat():
      case SseUnknown():
        return; // no afectan a la UI en esta fase
    }
    // Se reemplaza la lista para que Riverpod detecte el cambio.
    state = state.copyWith(mensajes: <Mensaje>[...state.mensajes]);
  }

  /// Deja constancia de que la conversación pertenece a un caso.
  ///
  /// Se guarda **también en el dispositivo** porque `GET /api/sessions/{id}`
  /// hoy no devuelve el `matter_id` de la sesión (solo `id` y `title`): sin
  /// esto, al reabrir la conversación la app volvería a mandar los turnos
  /// sueltos y el trabajo se guardaría fuera del expediente. En cuanto el
  /// backend exponga el campo, esta caché deja de hacer falta y basta con
  /// leerlo en [cargarHistorial].
  void _ligarACaso(CasoDelChat c) {
    state = state.copyWith(caso: c, limpiarSugerencia: true);
    unawaited(_recordarCaso(c));
    // El caso nuevo cambia la lista y el briefing del Inicio.
    ref
      ..invalidate(casosProvider)
      ..invalidate(briefingProvider);
  }

  static String _clave(String sessionId) => 'jv_caso_sesion_$sessionId';

  Future<void> _recordarCaso(CasoDelChat c) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(
        _clave(state.sessionId),
        jsonEncode(<String, dynamic>{
          'matter_id': c.matterId,
          'name': c.nombre,
          'code': c.codigo,
        }),
      );
    } on Object {
      // Perder la caché solo cuesta el banner: nunca debe romper el chat.
    }
  }

  Future<CasoDelChat?> _casoRecordado() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final String? crudo = p.getString(_clave(state.sessionId));
      if (crudo == null) return null;
      final Map<String, dynamic> j = jsonDecode(crudo) as Map<String, dynamic>;
      final String? id = j['matter_id'] as String?;
      if (id == null || id.isEmpty) return null;
      return CasoDelChat(
        matterId: id,
        nombre: j['name'] as String? ?? 'Caso',
        codigo: j['code'] as String?,
      );
    } on Object {
      return null;
    }
  }

  /// Convierte la conversación en un caso (`POST /promote-to-case`).
  ///
  /// El endpoint es **idempotente**: si la sesión ya tenía caso, devuelve el
  /// existente con `already: true` en vez de crear un duplicado. Por eso se
  /// puede reintentar sin miedo tras un fallo de red.
  Future<CasoDelChat?> promoverACaso() async {
    if (state.promocionando || state.caso != null) return state.caso;
    state = state.copyWith(promocionando: true);
    try {
      final Map<String, dynamic> r = await ref
          .read(apiClientProvider)
          .post(
            '/api/sessions/${state.sessionId}/promote-to-case',
            cuerpo: state.sugerencia?.cuerpo ?? <String, dynamic>{},
          );
      final String? id = r['matter_id'] as String?;
      if (r['ok'] != true || id == null || id.isEmpty) {
        state = state.copyWith(promocionando: false);
        return null;
      }
      final CasoDelChat c = CasoDelChat(
        matterId: id,
        nombre: r['name'] as String? ?? state.sugerencia?.nombre ?? 'Caso',
        codigo: r['code'] as String?,
      );
      _ligarACaso(c);
      state = state.copyWith(promocionando: false);
      return c;
    } on Object {
      state = state.copyWith(promocionando: false);
      return null;
    }
  }

  /// Descarta la propuesta sin crear nada.
  void descartarSugerencia() => state = state.copyWith(limpiarSugerencia: true);

  static String _nombreLegible(String herramienta) => switch (herramienta) {
    'buscar_norma' || 'buscar_normativa' => 'Buscando normativa',
    'verificar_fuente' => 'Verificando fuentes',
    'web_search' || 'brave_search' => 'Buscando en la web',
    'web_fetch' => 'Leyendo fuente',
    'generar_documento' || 'crear_documento' => 'Redactando documento',
    'buscar_jurisprudencia' => 'Buscando jurisprudencia',
    _ => herramienta.replaceAll('_', ' '),
  };

  /// Detiene la escucha del stream en este dispositivo.
  ///
  /// **No detiene el turno en el servidor**: el backend sigue y persiste el
  /// resultado. Al volver, la UI lo recupera recargando la sesión.
  /// Lanza el workflow del caso (F3.07). Mismo contrato SSE que un turno.
  bool ejecutarWorkflow(String matterId) {
    if (state.composerBloqueado) return false;
    final AiConsentToken? token = AiConsentGate.tokenPara(
      ref.read(aiConsentProvider).valueOrNull,
    );
    if (token == null) return false;

    _repo = ChatRepository(
      sse: ref.read(sseClientProvider),
      consentimiento: token,
    );

    final String idTurno = DateTime.now().microsecondsSinceEpoch.toString();
    final Mensaje respuesta = Mensaje(
      id: 'w$idTurno',
      esUsuario: false,
      status: 'streaming',
      creadoEn: DateTime.now(),
      seq: state.mensajes.length,
    );
    _inicioTurno = DateTime.now();
    state = state.copyWith(
      mensajes: <Mensaje>[...state.mensajes, respuesta],
      enCurso: true,
    );

    _sub = _repo!
        .ejecutarWorkflow(matterId: matterId)
        .listen(
          (SseEvent e) => _procesar(e, respuesta),
          onDone: _cerrarTurno,
          onError: (Object _) => _cerrarTurno(),
        );
    return true;
  }

  void detener() {
    _sub?.cancel();
    _repo?.cancelar();
    _cerrarTurno();
  }
}

final AutoDisposeNotifierProviderFamily<ChatController, ChatState, String?>
chatControllerProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatState, String?>(ChatController.new);

/// Historial de conversaciones (`GET /api/sessions`).
final AutoDisposeFutureProvider<List<SesionChat>> sesionesProvider =
    FutureProvider.autoDispose<List<SesionChat>>((Ref ref) async {
      final List<dynamic> crudas = await ref
          .watch(apiClientProvider)
          .getLista('/api/sessions');
      return crudas
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> s) =>
                SesionChat.fromJson(Map<String, dynamic>.from(s)),
          )
          .toList();
    });
