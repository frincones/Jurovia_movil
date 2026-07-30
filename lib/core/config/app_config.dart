/// Configuración de compilación.
///
/// Los valores entran con `--dart-define` en tiempo de compilación, así que
/// cambiar de entorno no requiere tocar código:
///
/// ```
/// flutter run --dart-define=SUPABASE_ANON_KEY=...
/// ```
///
/// ⚠️ Todo lo que se pasa por `--dart-define` queda **dentro del binario** que
/// se publica. Solo valores públicos: la anon key de Supabase lo es por diseño
/// y está protegida por RLS. Nunca la `service_role` ni llaves de proveedores:
/// esas viven en el backend de Railway.
library;

abstract final class AppConfig {
  /// Backend en Railway. Es el único que la app consume; no se despliega nada
  /// de backend en las tiendas.
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://legal-ai-backend-production-bdd2.up.railway.app',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tfhhcokgrpagwwlctjtz.supabase.co',
  );

  /// Pública por diseño. Se inyecta en CI.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// development | preview | production
  static const String flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'production',
  );

  /// Deep link registrado en `Info.plist` y `AndroidManifest.xml`.
  ///
  /// Debe estar también en Supabase → Auth → URL Configuration como
  /// `jurovia://**`, o el código OTP no puede devolver a la app.
  static const String authRedirectUrl = 'jurovia://auth-callback';

  static bool get esProduccion => flavor == 'production';

  /// Configuración obligatoria que falta. Se muestra en pantalla en vez de
  /// fallar más tarde con un error de red confuso.
  static List<String> faltantes() => <String>[
    if (backendUrl.isEmpty) 'BACKEND_URL',
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];

  static bool get configurado => faltantes().isEmpty;
}
