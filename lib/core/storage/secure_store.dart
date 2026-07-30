import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../compliance/ai_consent/ai_consent_gate.dart';

/// Almacenamiento cifrado del sistema (Keychain en iOS, Keystore en Android).
///
/// Aquí van los datos que **no pueden** estar en `SharedPreferences`: tokens de
/// sesión y el registro de consentimiento. La app maneja expedientes con datos
/// de clientes de abogados; no es información ordinaria.
class SecureStore {
  SecureStore({FlutterSecureStorage? almacen})
    : _s =
          almacen ??
          const FlutterSecureStorage(
            // En Android el cifrado ya es el comportamiento por defecto del
            // paquete; `encryptedSharedPreferences` quedó obsoleto.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _s;

  static const String _kConsentIa = 'jv_consent_ia';

  // ─────────────────── Consentimiento de IA (local) ───────────────────
  // Ver la nota de AiConsent: el backend no tiene todavía columna ni endpoint
  // para este consentimiento, así que vive en el dispositivo.

  Future<AiConsent> leerConsentimientoIa() async {
    try {
      final String? crudo = await _s.read(key: _kConsentIa);
      if (crudo == null || crudo.isEmpty) return AiConsent.ninguno;
      final Object? j = jsonDecode(crudo);
      if (j is Map<String, dynamic>) return AiConsent.fromJson(j);
      return AiConsent.ninguno;
    } on Object {
      // Un almacén corrupto no debe impedir usar la app: se vuelve a pedir.
      return AiConsent.ninguno;
    }
  }

  Future<void> guardarConsentimientoIa(AiConsent c) async {
    await _s.write(key: _kConsentIa, value: jsonEncode(c.toJson()));
  }

  Future<void> revocarConsentimientoIa() async {
    await _s.delete(key: _kConsentIa);
  }

  /// Purga total. Se llama al cerrar sesión y al eliminar la cuenta.
  Future<void> purgar() async {
    await _s.deleteAll();
  }
}
