/// Modelo del **briefing del día** (`GET /api/briefing`).
///
/// Es el mismo objeto que alimenta el Parte Diario por correo, así que lo que
/// el abogado ve al abrir la app es literalmente lo que le llegó al buzón. Eso
/// no es un detalle de implementación: es la razón de existir del endpoint.
///
/// ⚠️ Nombres verificados contra `app/agent/briefing.py`, no asumidos. Ojo con
/// dos diferencias respecto de otros endpoints:
///   · `atencion.terminos` usa **`matter_id`** (aquí sí), no `expId`.
///   · `procesos[].name` ya viene resuelto por `display_name()` en el servidor.
library;

/// 🛡️ Racha del despacho: la promesa que Jurovia está cumpliendo.
class Escudo {
  const Escudo({this.diasSinVencer, this.vigilados = 0, this.perdidos = 0});

  /// Días sin dejar vencer un término. `null` = todavía no hay historia.
  final int? diasSinVencer;

  /// Procesos con vigilancia **efectiva** (el backend ya exige radicado).
  final int vigilados;

  final int perdidos;

  /// Sin procesos vigilados no hay racha que presumir: el bloque cambia de
  /// tono en vez de mostrar ceros, que se leen como fracaso.
  bool get aspiracional => vigilados == 0;

  factory Escudo.desde(Object? v) {
    if (v is! Map) return const Escudo();
    final Map<String, dynamic> j = Map<String, dynamic>.from(v);
    return Escudo(
      diasSinVencer: (j['dias_sin_vencer'] as num?)?.toInt(),
      vigilados: (j['vigilados'] as num?)?.toInt() ?? 0,
      perdidos: (j['perdidos'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 🌙 Un movimiento que el agente hizo mientras el abogado no estaba.
class Movimiento {
  const Movimiento({
    required this.matterId,
    required this.nombre,
    this.codigo,
    this.tipo,
    this.resumen = '',
  });

  final String matterId;
  final String nombre;
  final String? codigo;
  final String? tipo;
  final String resumen;

  factory Movimiento.fromJson(Map<String, dynamic> j) => Movimiento(
    matterId: j['matter_id'] as String? ?? '',
    nombre: j['name'] as String? ?? 'un proceso',
    codigo: j['code'] as String?,
    tipo: j['event_type'] as String?,
    resumen: j['summary'] as String? ?? '',
  );
}

/// 🔴 Un término dentro de `atencion`. Distinto de `/api/deadlines`: aquí el
/// caso viene por `matter_id` y no trae el nombre resuelto.
class TerminoBriefing {
  const TerminoBriefing({
    required this.id,
    required this.titulo,
    this.vence,
    this.diasRestantes,
    this.severidad,
    this.matterId,
    this.confianza,
  });

  final String id;
  final String titulo;
  final DateTime? vence;
  final int? diasRestantes;
  final String? severidad;
  final String? matterId;
  final String? confianza;

  bool get critico => severidad == 'critico' || (diasRestantes ?? 99) <= 2;
  bool get tentativo => confianza == 'tentativo';

  String get etiqueta {
    final int? d = diasRestantes;
    if (d == null) return 'Agenda';
    if (d < 0) return 'Vencido';
    if (d == 0) return 'Hoy';
    return 'T−$d';
  }

  factory TerminoBriefing.fromJson(Map<String, dynamic> j) => TerminoBriefing(
    id: j['id'] as String? ?? '',
    titulo: j['title'] as String? ?? 'Término',
    vence: DateTime.tryParse(j['deadline_at'] as String? ?? ''),
    diasRestantes: (j['daysLeft'] as num?)?.toInt(),
    severidad: j['severity'] as String?,
    matterId: j['matter_id'] as String?,
    confianza: j['confidence'] as String?,
  );
}

/// Fila simple de `atencion`: borrador por aprobar o pendiente abierto.
class ItemAtencion {
  const ItemAtencion({
    required this.id,
    required this.titulo,
    this.matterId,
    this.vence,
    this.prioridad,
  });

  final String id;
  final String titulo;
  final String? matterId;
  final DateTime? vence;
  final String? prioridad;

  factory ItemAtencion.fromJson(Map<String, dynamic> j) => ItemAtencion(
    id: j['id'] as String? ?? '',
    titulo: j['title'] as String? ?? 'Pendiente',
    matterId: j['matter_id'] as String?,
    vence: DateTime.tryParse(j['due_date'] as String? ?? ''),
    prioridad: j['priority'] as String?,
  );
}

/// Lo que requiere al abogado hoy.
class Atencion {
  const Atencion({
    this.terminos = const <TerminoBriefing>[],
    this.borradores = const <ItemAtencion>[],
    this.pendientes = const <ItemAtencion>[],
  });

  final List<TerminoBriefing> terminos;
  final List<ItemAtencion> borradores;
  final List<ItemAtencion> pendientes;

  bool get vacia =>
      terminos.isEmpty && borradores.isEmpty && pendientes.isEmpty;

  int get total => terminos.length + borradores.length + pendientes.length;

  factory Atencion.desde(Object? v) {
    if (v is! Map) return const Atencion();
    final Map<String, dynamic> j = Map<String, dynamic>.from(v);
    return Atencion(
      terminos: _lista(j['terminos'], TerminoBriefing.fromJson),
      borradores: _lista(j['borradores'], ItemAtencion.fromJson),
      pendientes: _lista(j['pendientes'], ItemAtencion.fromJson),
    );
  }
}

/// 📁 Proceso priorizado por el servidor (`score` determinista).
class ProcesoPrioritario {
  const ProcesoPrioritario({
    required this.id,
    required this.nombre,
    this.codigo,
    this.progreso = 0,
    this.radicado,
    this.vigilanciaActiva = false,
    this.diasRestantes,
    this.score = 0,
  });

  final String id;
  final String nombre;
  final String? codigo;
  final int progreso;
  final String? radicado;
  final bool vigilanciaActiva;
  final int? diasRestantes;
  final int score;

  /// Misma regla que en la lista de casos: vigilar exige radicado.
  bool get vigilanciaVerificable => vigilanciaActiva && radicado != null;

  bool get urgente => (diasRestantes ?? 99) <= 2;

  String? get etiquetaTermino {
    final int? d = diasRestantes;
    if (d == null) return null;
    if (d < 0) return 'Vencido';
    if (d == 0) return 'Hoy';
    return 'T−$d';
  }

  static String? _limpio(Object? v) {
    final String s = (v as String?)?.trim() ?? '';
    return (s.isEmpty || s == '—' || s == '-') ? null : s;
  }

  factory ProcesoPrioritario.fromJson(Map<String, dynamic> j) =>
      ProcesoPrioritario(
        id: j['id'] as String? ?? '',
        nombre: _limpio(j['name']) ?? 'Caso sin nombre',
        codigo: _limpio(j['code']),
        progreso: (j['progress'] as num?)?.toInt() ?? 0,
        radicado: _limpio(j['radicado']),
        vigilanciaActiva: j['autopilot_on'] as bool? ?? false,
        diasRestantes: (j['daysLeft'] as num?)?.toInt(),
        score: (j['score'] as num?)?.toInt() ?? 0,
      );
}

/// Un tema de la inteligencia jurídica del día.
///
/// [askQuery] es la consulta lista para enviarle al agente: el servidor genera
/// **temas**, no fuentes, y es el agente quien las verifica al hacer clic. Por
/// eso nunca se muestra como un hecho citable.
class TemaDelDia {
  const TemaDelDia({
    required this.titulo,
    required this.askQuery,
    this.tipo = 'tema',
    this.resumen = '',
  });

  final String titulo;
  final String askQuery;

  /// `consulta | norma | tema`
  final String tipo;
  final String resumen;

  static TemaDelDia? desde(Object? v) {
    if (v is! Map) return null;
    final Map<String, dynamic> j = Map<String, dynamic>.from(v);
    final String t = (j['titulo'] as String? ?? '').trim();
    final String q = (j['ask_query'] as String? ?? '').trim();
    if (t.isEmpty || q.isEmpty) return null;
    return TemaDelDia(
      titulo: t,
      askQuery: q,
      tipo: j['tipo'] as String? ?? 'tema',
      resumen: j['resumen'] as String? ?? '',
    );
  }
}

/// Capa 1: lo que le sirve al abogado aunque no tenga ni un caso cargado.
class InteligenciaDelDia {
  const InteligenciaDelDia({
    this.area = 'general',
    this.temas = const <TemaDelDia>[],
    this.tip,
  });

  final String area;
  final List<TemaDelDia> temas;
  final TemaDelDia? tip;

  bool get vacia => temas.isEmpty && tip == null;

  static InteligenciaDelDia? desde(Object? v) {
    if (v is! Map) return null;
    final Map<String, dynamic> j = Map<String, dynamic>.from(v);
    final List<TemaDelDia> temas = (j['items'] as List<dynamic>? ?? <dynamic>[])
        .map(TemaDelDia.desde)
        .whereType<TemaDelDia>()
        .toList();
    final TemaDelDia? tip = TemaDelDia.desde(j['tip']);
    if (temas.isEmpty && tip == null) return null;
    return InteligenciaDelDia(
      area: j['area'] as String? ?? 'general',
      temas: temas,
      tip: tip,
    );
  }
}

/// Qué tan lleno viene el briefing. Lo decide el servidor.
enum Compuerta {
  /// Hay movimiento real: términos, borradores o avances de anoche.
  rica,

  /// Hay casos, pero hoy no pasó nada. No es un error: es un buen día.
  tranquila,

  /// Todavía no hay nada que vigilar. El Inicio debe **activar**, no informar.
  activacion;

  static Compuerta desde(Object? v) => switch (v) {
    'rich' => Compuerta.rica,
    'quiet' => Compuerta.tranquila,
    _ => Compuerta.activacion,
  };
}

/// El briefing completo.
class Briefing {
  const Briefing({
    this.escudo = const Escudo(),
    this.movimientos = const <Movimiento>[],
    this.atencion = const Atencion(),
    this.procesos = const <ProcesoPrioritario>[],
    this.inteligencia,
    this.area = 'general',
    this.compuerta = Compuerta.activacion,
  });

  final Escudo escudo;
  final List<Movimiento> movimientos;
  final Atencion atencion;
  final List<ProcesoPrioritario> procesos;
  final InteligenciaDelDia? inteligencia;
  final String area;
  final Compuerta compuerta;

  /// Briefing vacío para el estado inicial y para degradar sin romper nada.
  static const Briefing vacio = Briefing();

  factory Briefing.fromJson(Map<String, dynamic> j) => Briefing(
    escudo: Escudo.desde(j['escudo']),
    movimientos: _lista(
      (j['overnight'] as Map<dynamic, dynamic>?)?['movimientos'],
      Movimiento.fromJson,
    ),
    atencion: Atencion.desde(j['atencion']),
    procesos: _lista(j['procesos'], ProcesoPrioritario.fromJson),
    inteligencia: InteligenciaDelDia.desde(j['legal_intel']),
    area: j['area'] as String? ?? 'general',
    compuerta: Compuerta.desde(j['gate']),
  );
}

List<T> _lista<T>(Object? v, T Function(Map<String, dynamic>) desde) {
  if (v is! List) return <T>[];
  return v
      .whereType<Map<dynamic, dynamic>>()
      .map((Map<dynamic, dynamic> m) => desde(Map<String, dynamic>.from(m)))
      .toList();
}
