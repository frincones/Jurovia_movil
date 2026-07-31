import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/theme/typography.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Falla temprano y con mensaje claro si falta configuración, en vez de dar
  // errores de red confusos más adelante.
  if (!AppConfig.configurado) {
    runApp(_SinConfigurar(faltantes: AppConfig.faltantes()));
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // El SDK renombró `anonKey` a `publishableKey`; acepta la misma llave.
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const ProviderScope(child: JuroviaApp()));
}

/// Pantalla de arranque cuando falta un `--dart-define` obligatorio.
class _SinConfigurar extends StatelessWidget {
  const _SinConfigurar({required this.faltantes});

  final List<String> faltantes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: JvTheme.claro,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.settings_outlined,
                  size: 40,
                  color: JvColors.de(context).terciario,
                ),
                const SizedBox(height: 18),
                Text('Falta configuración', style: JvText.tituloHoja),
                const SizedBox(height: 10),
                Text(
                  'Esta compilación no trae:\n${faltantes.map((String f) => '· $f').join('\n')}',
                  style: JvText.cuerpoMedio.copyWith(
                    color: JvColors.de(context).secundario,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Se inyectan con --dart-define al compilar.\n'
                  'Ver core/config/app_config.dart',
                  style: JvText.de(context).menor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
