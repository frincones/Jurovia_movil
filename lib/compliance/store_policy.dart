/// Constantes de política de tienda, compiladas.
///
/// No son configuración: son **invariantes del producto**. Cada una tiene una
/// prueba en `test/compliance/store_policy_test.dart` que falla si cambia, para
/// enterarnos en el *pull request* y no en la revisión de Apple tres semanas
/// después.
///
/// Ver `AuditCheck.md` §3.3 y `ARQUITECTURA_APP_MOVIL_V2.md` §4.5.
abstract final class StorePolicy {
  /// ¿La app puede vender algo dentro?
  ///
  /// **No.** Apple 3.1.1 exige In-App Purchase para desbloquear funciones
  /// digitales, y Google Play lo equivalente. Jurovia cobra en la web con
  /// Paddle (modelo Web2App). Encender esto sin implementar IAP = rechazo.
  static const bool allowsInAppPurchase = false;

  /// ¿Puede la app enlazar a un checkout externo?
  ///
  /// **No.** Apple solo lo permite en la tienda de EE. UU. y el mercado de
  /// Jurovia es Colombia. Incluye enlaces, botones y **texto** que sugiera
  /// pagar fuera ("suscríbete en la web", "facturación en juroviapp.com").
  static const bool allowsExternalPurchaseLink = false;

  /// ¿Hay algún SDK de publicidad o atribución?
  ///
  /// **No.** Mantenerlo así evita App Tracking Transparency, los dominios de
  /// rastreo del privacy manifest y una categoría entera de rechazos. La
  /// atribución del embudo ya se hace server-side en la web.
  static const bool hasAdvertisingSdk = false;

  /// ¿Hay login social (Google, Apple, Facebook…)?
  ///
  /// **No.** Solo OTP por correo con Supabase. Por eso la regla 4.8 (que
  /// obligaría a ofrecer Sign in with Apple) no aplica.
  static const bool hasThirdPartyLogin = false;

  /// Proveedor de IA al que se envía el contenido del usuario.
  ///
  /// Apple 5.1.2(i) exige **nombrarlo** en el consentimiento, no basta con
  /// decir "servicios de terceros".
  static const String aiProvider = 'Anthropic (Claude)';
}
