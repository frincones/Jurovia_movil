/// Modelos del chat: sesiones, mensajes y sus partes.
///
/// Reflejan el esquema real del backend (`messages` + `message_parts`), no una
/// invención del cliente.
library;

/// Estado de un mensaje al **cargar una sesión** (no durante el streaming).
///
/// El backend persiste el mensaje del asistente con `status: 'streaming'` y
/// **sin partes** al EMPEZAR el turno, y las partes al terminar. Si se abre la
/// sesión a mitad —por ejemplo porque el turno corre en otro dispositivo— hay
/// que distinguir estos tres casos o se pinta una burbuja vacía, que parece un
/// fallo del producto (arquitectura §11.4).
enum EstadoMensaje {
  /// Terminado y con contenido.
  completo,

  /// Generándose ahora mismo, aquí o en otro dispositivo.
  generando,

  /// `streaming` que lleva demasiado tiempo: nadie lo va a terminar.
  huerfano,
}

/// Umbral tras el cual un `streaming` se considera abandonado.
const Duration kUmbralHuerfano = Duration(minutes: 10);

/// Una parte de un mensaje: texto, razonamiento, artefacto, hooks…
class ParteMensaje {
  const ParteMensaje({required this.tipo, this.texto, this.datos});

  final String tipo;
  final String? texto;
  final Map<String, dynamic>? datos;

  bool get esTexto => tipo == 'text';
  bool get esRazonamiento => tipo == 'thinking';
  bool get esArtefacto => tipo == 'artifact';
  bool get esHooks => tipo == 'hooks';
  bool get esPaso => tipo == 'agent_step' || tipo == 'phase';

  factory ParteMensaje.fromJson(Map<String, dynamic> j) => ParteMensaje(
    tipo: j['type'] as String? ?? 'text',
    texto: j['text'] as String?,
    datos: j['data'] is Map
        ? Map<String, dynamic>.from(j['data'] as Map)
        : null,
  );
}

/// Fuente citada por el agente.
///
/// `verificada` distingue lo contrastado contra fuente oficial (dorado) de lo
/// meramente consultado. **No se pinta dorado si no está verificada.**
class Fuente {
  const Fuente({
    required this.titulo,
    this.detalle = '',
    this.url,
    this.verificada = false,
  });

  final String titulo;
  final String detalle;
  final String? url;
  final bool verificada;

  factory Fuente.fromJson(Map<String, dynamic> j) => Fuente(
    titulo: j['title'] as String? ?? j['titulo'] as String? ?? 'Fuente',
    detalle: j['meta'] as String? ?? j['detalle'] as String? ?? '',
    url: j['url'] as String?,
    verificada: j['verified'] as bool? ?? j['verificada'] as bool? ?? false,
  );
}

/// Documento generado por el agente (evento `artifact`).
class Artefacto {
  const Artefacto({
    required this.id,
    required this.nombre,
    this.paginas,
    this.tipo = 'docx',
    this.descripcion,
  });

  final String id;
  final String nombre;
  final int? paginas;
  final String tipo;
  final String? descripcion;

  String get subtitulo {
    final List<String> partes = <String>[
      if (paginas != null) '$paginas páginas',
      descripcion ?? 'borrador generado',
    ];
    return partes.join(' · ');
  }

  factory Artefacto.fromJson(Map<String, dynamic> j) => Artefacto(
    id: j['id'] as String? ?? '',
    nombre:
        j['name'] as String? ??
        j['filename'] as String? ??
        j['title'] as String? ??
        'Documento',
    paginas: (j['pages'] as num?)?.toInt(),
    tipo: j['kind'] as String? ?? j['type'] as String? ?? 'docx',
    descripcion: j['description'] as String?,
  );
}

/// Sugerencia de próxima acción.
class HookAccion {
  const HookAccion({
    required this.etiqueta,
    required this.prompt,
    this.tipo = '',
  });

  final String etiqueta;
  final String prompt;
  final String tipo;
}

/// Paso de actividad del agente, para el timeline vivo.
class PasoActividad {
  PasoActividad({required this.nombre, this.estado = 'running', this.detalle});

  final String nombre;
  String estado;
  String? detalle;

  bool get terminado => estado == 'done' || estado == 'ok';
}

/// Mensaje del chat.
class Mensaje {
  Mensaje({
    required this.id,
    required this.esUsuario,
    this.texto = '',
    this.razonamiento = '',
    this.status = 'complete',
    this.creadoEn,
    this.seq = 0,
    List<Fuente>? fuentes,
    List<Artefacto>? artefactos,
    List<HookAccion>? hooks,
    List<PasoActividad>? pasos,
    this.error,
    this.bloqueado = false,
    this.segundosPensando,
  }) : fuentes = fuentes ?? <Fuente>[],
       artefactos = artefactos ?? <Artefacto>[],
       hooks = hooks ?? <HookAccion>[],
       pasos = pasos ?? <PasoActividad>[];

  final String id;
  final bool esUsuario;
  String texto;
  String razonamiento;
  String status;
  final DateTime? creadoEn;
  final int seq;
  final List<Fuente> fuentes;
  final List<Artefacto> artefactos;
  final List<HookAccion> hooks;
  final List<PasoActividad> pasos;
  String? error;
  bool bloqueado;
  int? segundosPensando;

  bool get generandoAhora => status == 'streaming';
  bool get tieneContenido => texto.trim().isNotEmpty;

  /// Clasifica el mensaje al cargarlo de la API. Ver [EstadoMensaje].
  EstadoMensaje clasificar({DateTime? ahora}) {
    if (esUsuario || status == 'complete') return EstadoMensaje.completo;
    if (status != 'streaming') return EstadoMensaje.completo;
    // Ya tiene contenido: se está viendo llegar, no está vacío.
    if (tieneContenido) return EstadoMensaje.generando;
    final DateTime t = ahora ?? DateTime.now();
    final DateTime nacido = creadoEn ?? t;
    return t.difference(nacido) > kUmbralHuerfano
        ? EstadoMensaje.huerfano
        : EstadoMensaje.generando;
  }

  /// Deserializa un mensaje de `GET /api/sessions/{id}`.
  ///
  /// ⚠️ **El backend NO devuelve `message_parts`**: `app/api/sessions.py` los
  /// aplana y reconstruye antes de responder. La forma real es:
  ///
  /// ```json
  /// {"role":"assistant", "text":"…", "thinking":"…", "durationMs":6200,
  ///  "steps":[{"name","input","output","durationMs","sources"}],
  ///  "artifacts":[{"id","version_id","kind","title","version","uri","blocks"}],
  ///  "hooks":[{"label","tipo","prompt"}]}
  /// ```
  ///
  /// Tampoco trae `id`, `seq` ni `status`: el endpoint solo devuelve turnos ya
  /// terminados, así que el orden es el del array y el estado es `complete`.
  factory Mensaje.fromJson(Map<String, dynamic> j, {int indice = 0}) {
    final bool esUsuario = (j['role'] as String?) == 'user';

    final List<Artefacto> artefactos =
        ((j['artifacts'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> a) =>
                  Artefacto.fromJson(Map<String, dynamic>.from(a)),
            )
            .toList();

    final List<HookAccion> hooks =
        ((j['hooks'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> h) => HookAccion(
                etiqueta: h['label'] as String? ?? '',
                prompt: h['prompt'] as String? ?? '',
                tipo: h['tipo'] as String? ?? '',
              ),
            )
            .toList();

    // Los pasos traen además las fuentes que consultó cada herramienta.
    final List<PasoActividad> pasos = <PasoActividad>[];
    final List<Fuente> fuentes = <Fuente>[];
    for (final dynamic p in (j['steps'] as List<dynamic>?) ?? <dynamic>[]) {
      if (p is! Map) continue;
      final Map<String, dynamic> paso = Map<String, dynamic>.from(p);
      pasos.add(
        PasoActividad(
          nombre: paso['name'] as String? ?? 'paso',
          estado: 'done',
          detalle: paso['output'] as String?,
        ),
      );
      for (final dynamic f
          in (paso['sources'] as List<dynamic>?) ?? <dynamic>[]) {
        if (f is Map) {
          fuentes.add(Fuente.fromJson(Map<String, dynamic>.from(f)));
        }
      }
    }

    final int? ms = (j['durationMs'] as num?)?.toInt();

    return Mensaje(
      id: (j['id'] as String?) ?? '${esUsuario ? 'u' : 'a'}$indice',
      esUsuario: esUsuario,
      texto: j['text'] as String? ?? '',
      razonamiento: j['thinking'] as String? ?? '',
      // El endpoint solo devuelve turnos completos.
      status: 'complete',
      seq: indice,
      creadoEn: DateTime.tryParse(j['created_at'] as String? ?? ''),
      artefactos: artefactos,
      hooks: hooks,
      pasos: pasos,
      fuentes: fuentes,
      segundosPensando: ms == null ? null : (ms / 1000).round(),
    );
  }
}

/// Conversación del historial.
class SesionChat {
  const SesionChat({
    required this.id,
    required this.titulo,
    this.actualizadaEn,
    this.matterId,
  });

  final String id;
  final String titulo;
  final DateTime? actualizadaEn;
  final String? matterId;

  /// "Hoy", "Ayer", "Vie", "23 jul" — como el prototipo.
  String get cuando {
    final DateTime? t = actualizadaEn;
    if (t == null) return '';
    final DateTime hoy = DateTime.now();
    final int dias = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (dias == 0) return 'Hoy';
    if (dias == 1) return 'Ayer';
    if (dias < 7) {
      const List<String> d = <String>[
        'Lun',
        'Mar',
        'Mié',
        'Jue',
        'Vie',
        'Sáb',
        'Dom',
      ];
      return d[t.weekday - 1];
    }
    const List<String> m = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${t.day} ${m[t.month - 1]}';
  }

  factory SesionChat.fromJson(Map<String, dynamic> j) => SesionChat(
    id: j['id'] as String? ?? '',
    titulo: (j['title'] as String?)?.trim().isNotEmpty == true
        ? j['title'] as String
        : 'Conversación sin título',
    actualizadaEn: DateTime.tryParse(
      j['updated_at'] as String? ?? j['created_at'] as String? ?? '',
    ),
    matterId: j['matter_id'] as String?,
  );
}
