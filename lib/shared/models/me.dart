/// Identidad y estado del usuario, tal como los devuelve `GET /api/me`.
///
/// Es **la** llamada de arranque: decide onboarding, qué módulos se ven
/// (`features`), qué puede hacer (`entitlements`) y qué muro mostrar (`access`).
///
/// Contrato real del backend (`app/api/missions.py`):
/// ```json
/// { "user_id", "email", "org_id", "features", "plan",
///   "trial_ends_at", "entitlements", "onboarded", "access" }
/// ```
class Me {
  const Me({
    this.userId,
    this.email,
    this.orgId,
    this.plan = 'free',
    this.trialEndsAt,
    this.onboarded = false,
    this.features = const <String, dynamic>{},
    this.entitlements = const <String, dynamic>{},
    this.access = const Access(),
  });

  final String? userId;
  final String? email;
  final String? orgId;
  final String plan;
  final DateTime? trialEndsAt;
  final bool onboarded;
  final Map<String, dynamic> features;
  final Map<String, dynamic> entitlements;
  final Access access;

  bool get esPago => plan != 'free' && plan != 'trial';

  /// Nombre a mostrar. El backend no devuelve nombre en `/api/me`, así que se
  /// deriva del correo hasta que se cargue el perfil.
  String get nombreCorto {
    final String local = (email ?? '').split('@').first;
    if (local.isEmpty) return 'Abogado';
    final String limpio = local.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (limpio.isEmpty) return 'Abogado';
    return limpio.split(' ').first.replaceRange(0, 1, limpio[0].toUpperCase());
  }

  String get iniciales {
    final String base = nombreCorto;
    return base.isEmpty
        ? 'JV'
        : base.substring(0, base.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory Me.fromJson(Map<String, dynamic> j) => Me(
    userId: j['user_id'] as String?,
    email: j['email'] as String?,
    orgId: j['org_id'] as String?,
    plan: j['plan'] as String? ?? 'free',
    trialEndsAt: DateTime.tryParse(j['trial_ends_at'] as String? ?? ''),
    onboarded: j['onboarded'] as bool? ?? false,
    features: _mapa(j['features']),
    entitlements: _mapa(j['entitlements']),
    access: Access.fromJson(_mapa(j['access'])),
  );

  static Map<String, dynamic> _mapa(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  /// Constructor para pruebas.
  factory Me.prueba({
    String plan = 'pro',
    bool onboarded = true,
    String? email = 'prueba@juroviapp.com',
  }) => Me(
    userId: 'u1',
    email: email,
    orgId: 'o1',
    plan: plan,
    onboarded: onboarded,
  );
}

/// Modelo de acceso: la app **ramifica según [model]**, no asume créditos.
///
/// El backend puede devolver `{model: 'credits'}` o `{model: 'trial_daily'}`
/// con turnos por día. Pintar siempre créditos rompería el segundo caso
/// (arquitectura §14, contradicción 5).
class Access {
  const Access({
    this.model = 'credits',
    this.balance,
    this.cap,
    this.turnsLeft,
    this.turnsPerDay,
    this.blocked = false,
  });

  final String model;
  final int? balance;
  final int? cap;
  final int? turnsLeft;
  final int? turnsPerDay;
  final bool blocked;

  bool get esTrialDiario => model == 'trial_daily';

  /// Texto de cuota listo para pintar, según el modelo vigente.
  String get resumen {
    if (esTrialDiario) {
      final int quedan = turnsLeft ?? 0;
      final int total = turnsPerDay ?? 0;
      return total > 0 ? '$quedan de $total turnos hoy' : '$quedan turnos hoy';
    }
    final int saldo = balance ?? 0;
    return '$saldo créditos';
  }

  factory Access.fromJson(Map<String, dynamic> j) => Access(
    model: j['model'] as String? ?? 'credits',
    balance: (j['balance'] as num?)?.toInt(),
    cap: (j['cap'] as num?)?.toInt(),
    turnsLeft: (j['turns_left'] as num?)?.toInt(),
    turnsPerDay: (j['turns_per_day'] as num?)?.toInt(),
    blocked: j['blocked'] as bool? ?? false,
  );
}
