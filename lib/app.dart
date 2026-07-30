import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/sync/refresh_policy.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class JuroviaApp extends ConsumerWidget {
  const JuroviaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode modo =
        ref.watch(temaProvider).valueOrNull ?? ThemeMode.system;

    // El observador de ciclo de vida recarga al volver a primer plano (§11.3).
    return ObservadorCicloVida(
      child: MaterialApp.router(
        title: 'Jurovia',
        debugShowCheckedModeBanner: false,
        theme: JvTheme.claro,
        darkTheme: JvTheme.oscuro,
        themeMode: modo,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
