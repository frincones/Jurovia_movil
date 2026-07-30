/// Modelos de Mission Control: casos (misiones), actuaciones y términos.
///
/// ⚠️ Los nombres de campo salen de `_mission_shape` en `app/api/missions.py`
/// y de `list_deadlines` en `app/api/deadlines.py`. El backend **no** devuelve
/// los nombres de las columnas: los remapea. Verificado contra el código, no
/// asumido.
library;

/// Término asociado a un caso, tal como lo devuelve `nextTerm`.
class ProximoTermino {
  const ProximoTermino({this.titulo, this.diasRestantes, this.severidad});

  final String? titulo;
  final int? diasRestantes;
  final String? severidad;

  bool get critico => severidad == 'critico' || (diasRestantes ?? 99) <= 2;

  String get etiqueta {
    final int? d = diasRestantes;
    if (d == null) return 'Sin término';
    if (d < 0) return 'Vencido';
    return 'T−$d';
  }

  static ProximoTermino? desde(Object? v) {
    if (v is! Map) return null;
    final Map<String, dynamic> j = Map<String, dynamic>.from(v);
    return ProximoTermino(
      titulo: j['title'] as String?,
      diasRestantes: (j['daysLeft'] as num?)?.toInt(),
      severidad: j['severity'] as String?,
    );
  }
}

/// Caso / expediente (misión).
class Caso {
  const Caso({
    required this.id,
    required this.nombre,
    this.codigo,
    this.radicado,
    this.estado = 'active',
    this.materia,
    this.juzgado,
    this.demandante,
    this.demandado,
    this.progreso = 0,
    this.proximaAccion,
    this.proximoTermino,
    this.vigilanciaActiva = false,
    this.ultimaRevision,
    this.hechosClave,
  });

  final String id;

  /// Nombre legible. El backend expone **`display`** (Capa A); `title` es el
  /// prompt crudo con el que se creó la misión y NO sirve para mostrar.
  final String nombre;

  /// Código global `JUR-XXXX-XXXX`. Es el identificador con el que el abogado
  /// se refiere al caso: se muestra en monoespaciada y se puede buscar por él.
  final String? codigo;

  final String? radicado;
  final String estado;
  final String? materia;
  final String? juzgado;
  final String? demandante;
  final String? demandado;
  final int progreso;
  final String? proximaAccion;
  final ProximoTermino? proximoTermino;

  /// Vigilancia judicial (autopilot) encendida para este proceso.
  final bool vigilanciaActiva;
  final DateTime? ultimaRevision;
  final String? hechosClave;

  bool get archivado => estado == 'closed' || estado == 'archivado';
  bool get fallado => estado == 'fallado';

  /// ¿Se puede afirmar que este proceso está vigilado?
  ///
  /// Exige **las dos cosas**: la vigilancia encendida Y un radicado real. Sin
  /// radicado no hay nada que consultar en la Rama Judicial, así que el tag
  /// estaría prometiendo algo que no ocurre. Misma regla que el dorado de
  /// «fuente verificada»: no se promete lo que no se hace.
  bool get vigilanciaVerificable => vigilanciaActiva && radicado != null;

  /// El backend usa "—" como marcador de vacío; se normaliza a null.
  static String? _limpio(Object? v) {
    final String s = (v as String?)?.trim() ?? '';
    return (s.isEmpty || s == '—' || s == '-') ? null : s;
  }

  String get partes {
    final List<String> p = <String>[?demandante, ?demandado];
    return p.join(' vs. ');
  }

  String get ultimaRevisionLegible {
    final DateTime? t = ultimaRevision;
    if (t == null) return 'sin revisar todavía';
    final int h = DateTime.now().difference(t).inHours;
    if (h < 1) return 'revisado hace minutos';
    if (h < 24) return 'revisado hace $h h';
    return 'revisado hace ${h ~/ 24} d';
  }

  factory Caso.fromJson(Map<String, dynamic> j) => Caso(
    id: j['id'] as String? ?? '',
    // Orden deliberado: `display` (legible) > `title` (prompt crudo) > `name`.
    nombre:
        _limpio(j['display']) ??
        _limpio(j['title']) ??
        _limpio(j['name']) ??
        'Caso sin nombre',
    codigo: _limpio(j['code']),
    radicado: _limpio(j['radicado']),
    estado: j['status'] as String? ?? 'active',
    materia: _limpio(j['area']),
    juzgado: _limpio(j['juzgado']),
    demandante: _limpio(j['demandante']),
    demandado: _limpio(j['demandado']),
    progreso: (j['progress'] as num?)?.toInt() ?? 0,
    proximaAccion: _limpio(j['nextBestAction']),
    proximoTermino: ProximoTermino.desde(j['nextTerm']),
    vigilanciaActiva: j['autopilot_on'] as bool? ?? false,
    ultimaRevision: DateTime.tryParse(j['last_check'] as String? ?? ''),
    hechosClave: _limpio(j['keyFacts']),
  );
}

/// Actuación del timeline procesal.
class Actuacion {
  const Actuacion({
    required this.titulo,
    this.detalle,
    this.fecha,
    this.tipo = '',
  });

  final String titulo;
  final String? detalle;
  final DateTime? fecha;
  final String tipo;

  bool get corriendoTermino =>
      tipo == 'termino' || (detalle ?? '').toLowerCase().contains('término');

  String get fechaLegible {
    final DateTime? t = fecha;
    if (t == null) return '';
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
    return '${t.day} ${m[t.month - 1]} ${t.year}';
  }

  factory Actuacion.fromJson(Map<String, dynamic> j) => Actuacion(
    titulo:
        j['title'] as String? ??
        j['event'] as String? ??
        j['summary'] as String? ??
        'Actuación',
    detalle: j['detail'] as String? ?? j['description'] as String?,
    fecha: DateTime.tryParse(
      j['date'] as String? ?? j['created_at'] as String? ?? '',
    ),
    tipo: j['type'] as String? ?? j['kind'] as String? ?? '',
  );
}

/// Término procesal pendiente (`GET /api/deadlines`).
class Termino {
  const Termino({
    required this.id,
    required this.titulo,
    this.vence,
    this.diasRestantes,
    this.severidad,
    this.fundamento,
    this.confianza,
    this.autoCreado = false,
    this.matterId,
    this.caso,
  });

  final String id;
  final String titulo;
  final DateTime? vence;

  /// Lo calcula el backend: no se recalcula en el cliente.
  final int? diasRestantes;
  final String? severidad;
  final String? fundamento;
  final String? confianza;

  /// Lo dedujo el Autopilot a partir de una actuación, no lo escribió nadie.
  final bool autoCreado;

  final String? matterId;
  final String? caso;

  String get etiqueta {
    final int? d = diasRestantes;
    if (d == null) return 'Agenda';
    if (d < 0) return 'Vencido';
    return 'T−$d';
  }

  bool get urgente => severidad == 'critico' || (diasRestantes ?? 99) <= 2;

  /// `tentativo` significa que el agente lo dedujo pero no está confirmado.
  ///
  /// Hay que decirlo, no presentarlo como un hecho: un término auto-creado que
  /// el abogado tome por confirmado le puede costar el proceso.
  bool get tentativo => confianza == 'tentativo' || autoCreado;

  String get dia =>
      vence != null ? vence!.day.toString().padLeft(2, '0') : '--';

  String get mes {
    if (vence == null) return '';
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
    return m[vence!.month - 1];
  }

  factory Termino.fromJson(Map<String, dynamic> j) => Termino(
    id: j['id'] as String? ?? '',
    titulo: j['title'] as String? ?? 'Pendiente',
    // El backend expone `deadline_at`, no `due_at`.
    vence: DateTime.tryParse(j['deadline_at'] as String? ?? ''),
    diasRestantes: (j['daysLeft'] as num?)?.toInt(),
    severidad: j['severity'] as String?,
    fundamento: j['fundamento'] as String?,
    confianza: j['confidence'] as String?,
    autoCreado: j['auto_created'] as bool? ?? false,
    // …y `expId`, no `matter_id`.
    matterId: j['expId'] as String? ?? j['matter_id'] as String?,
    caso: j['caso'] as String?,
  );
}

/// Notificación de la bandeja.
class Notificacion {
  const Notificacion({
    required this.id,
    required this.titulo,
    this.cuerpo = '',
    this.tipo = '',
    this.canal = 'inapp',
    this.leida = false,
    this.creadaEn,
    this.matterId,
  });

  final String id;
  final String titulo;
  final String cuerpo;

  /// `deadline | actuacion | draft_ready | missing_doc | parte_diario`
  final String tipo;

  /// `inapp | email | …`
  final String canal;

  final bool leida;
  final DateTime? creadaEn;
  final String? matterId;

  /// El Parte Diario abre el Inicio, no un caso.
  bool get esParteDiario => tipo == 'parte_diario';

  String get cuando {
    final DateTime? t = creadaEn;
    if (t == null) return '';
    final DateTime hoy = DateTime.now();
    final int dias = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (dias == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
    }
    if (dias == 1) return 'Ayer';
    const List<String> d = <String>[
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
      'Dom',
    ];
    if (dias < 7) return d[t.weekday - 1];
    return '${t.day}/${t.month}';
  }

  String get grupo {
    final DateTime? t = creadaEn;
    if (t == null) return 'Antes';
    final int dias = DateTime.now().difference(t).inDays;
    if (dias == 0) return 'Hoy';
    if (dias < 7) return 'Esta semana';
    return 'Antes';
  }

  /// ⚠️ `/api/notifications` devuelve `campaign_type` y `related_matter_id`,
  /// NO `kind` ni `matter_id`. Leer los nombres equivocados dejaba todos los
  /// avisos con el icono genérico y sin navegación al caso.
  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
    id: j['id'] as String? ?? '',
    titulo: j['title'] as String? ?? 'Aviso',
    cuerpo: j['body'] as String? ?? '',
    tipo: j['campaign_type'] as String? ?? '',
    canal: j['channel'] as String? ?? 'inapp',
    leida: j['read_at'] != null,
    creadaEn: DateTime.tryParse(j['created_at'] as String? ?? ''),
    matterId: j['related_matter_id'] as String?,
  );
}
