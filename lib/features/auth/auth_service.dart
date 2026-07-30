import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';

/// Autenticación contra Supabase.
///
/// **Solo OTP por correo.** Sin login social: por eso la regla 4.8 de Apple
/// (que obligaría a ofrecer Sign in with Apple) no aplica. Ver
/// `StorePolicy.hasThirdPartyLogin`.
///
/// El backend verifica la **firma** del JWT por JWKS y resuelve `org_id`
/// server-side desde `memberships`. La app solo envía `Authorization: Bearer`.
class AuthService implements TokenProvider {
  AuthService(this._supabase);

  final SupabaseClient _supabase;

  Session? get sesion => _supabase.auth.currentSession;
  User? get usuario => _supabase.auth.currentUser;
  bool get autenticado => sesion != null;

  Stream<AuthState> get cambios => _supabase.auth.onAuthStateChange;

  /// Envía el código de 6 dígitos al correo.
  ///
  /// `shouldCreateUser: true` permite registrarse desde la app: el registro
  /// gratuito **sí** está permitido por las tiendas; lo prohibido es vender.
  Future<void> enviarCodigo(String correo) async {
    await _supabase.auth.signInWithOtp(
      email: correo.trim().toLowerCase(),
      shouldCreateUser: true,
      emailRedirectTo: AppConfig.authRedirectUrl,
    );
  }

  /// Verifica el código de 6 dígitos e inicia sesión.
  Future<void> verificarCodigo({
    required String correo,
    required String codigo,
  }) async {
    await _supabase.auth.verifyOTP(
      type: OtpType.email,
      email: correo.trim().toLowerCase(),
      token: codigo.trim(),
    );
  }

  Future<void> cerrar() async {
    await _supabase.auth.signOut();
  }

  // ───────────────────── TokenProvider ─────────────────────

  @override
  Future<String?> accessToken() async =>
      _supabase.auth.currentSession?.accessToken;

  @override
  Future<String?> refrescar() async {
    try {
      final AuthResponse r = await _supabase.auth.refreshSession();
      return r.session?.accessToken;
    } on Object {
      // El refresh token también caducó o fue revocado.
      return null;
    }
  }

  @override
  Future<void> cerrarSesion() => cerrar();
}
