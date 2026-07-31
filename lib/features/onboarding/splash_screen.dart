import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/jurovia_logo.dart';

/// S01 · Splash. Mientras el router resuelve sesión y consentimiento.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Halos radiales del prototipo.
          const Positioned.fill(child: _Halos()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const JuroviaMark(tamano: 96),
                const SizedBox(height: 22),
                JuroviaLogo(estilo: JvText.display),
                const SizedBox(height: 8),
                Text(
                  'Tú revisas y decides.',
                  style: JvText.cuerpoMedio.copyWith(
                    color: JvColors.de(context).secundario,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 78,
            child: Column(
              children: <Widget>[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verificando sesión…',
                  style: JvText.de(
                    context,
                  ).menor.copyWith(color: JvColors.de(context).terciario),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Halos extends StatelessWidget {
  const _Halos();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.65),
          radius: 1.1,
          colors: <Color>[
            JvColors.rosa.withValues(alpha: 0.16),
            JvColors.purpura.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.55, 1],
        ),
      ),
    );
  }
}
