import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/aurora_button.dart';
import '../../shared/widgets/verified_chip.dart';

/// S02 · Onboarding de 3 diapositivas.
///
/// La tercera incluye el **aviso legal** exigido por AuditCheck C8.16
/// (Apple 1.4.1: apps que dan asesoría profesional).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Diapositiva {
  const _Diapositiva(this.titulo, this.cuerpo, {this.legal});
  final String titulo;
  final String cuerpo;
  final String? legal;
}

const List<_Diapositiva> _slides = <_Diapositiva>[
  _Diapositiva(
    'Redacta en minutos',
    'Demandas, contestaciones y tutelas con el estilo de tu despacho. '
        'Tú revisas y decides.',
  ),
  _Diapositiva(
    'Verifica antes de firmar',
    'Cada norma y sentencia se contrasta contra la fuente oficial. '
        'Si no es verificable, Jurovia no lo cita.',
  ),
  _Diapositiva(
    'Vigila cada movimiento',
    'Vigilancia automática de tus procesos y avisos T−7, T−2 y T−0 antes de '
        'que venza el término.',
    // AuditCheck C8.16 · Apple 1.4.1
    legal:
        'Jurovia es una herramienta de apoyo y no sustituye la asesoría '
        'de un profesional del derecho. Sus respuestas pueden contener errores '
        'y deben verificarse antes de usarse.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _i = 0;

  void _siguiente() {
    if (_i == _slides.length - 1) {
      context.go(Rutas.login);
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Diapositiva s = _slides[_i];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(Rutas.login),
                  child: Text(
                    'Saltar',
                    style: JvText.chip.copyWith(color: JvColors.txtTerciario),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 240,
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: JvColors.borde),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            JvColors.rosa.withValues(alpha: 0.14),
                            JvColors.purpura.withValues(alpha: 0.12),
                            JvColors.azul.withValues(alpha: 0.10),
                          ],
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[VerifiedChip()],
                      ),
                    ),
                    const SizedBox(height: 34),
                    AnimatedSwitcher(
                      duration: JvMotion.efectiva(context, JvMotion.fade),
                      child: Column(
                        key: ValueKey<int>(_i),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.titulo,
                            style: JvText.tituloPantalla.copyWith(fontSize: 28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.cuerpo,
                            style: JvText.cuerpo.copyWith(
                              color: JvColors.txtSecundario,
                            ),
                          ),
                          if (s.legal != null) ...<Widget>[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: JvColors.sutil,
                                borderRadius: JvShapes.rCampo,
                              ),
                              child: Text(
                                s.legal!,
                                style: JvText.menor.copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: List<Widget>.generate(_slides.length, (int i) {
                      final bool activo = i == _i;
                      return AnimatedContainer(
                        duration: JvMotion.efectiva(context, JvMotion.fade),
                        margin: const EdgeInsets.only(right: 7),
                        width: activo ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: activo
                              ? JvColors.purpura
                              : JvColors.bordeFuerte,
                          borderRadius: JvShapes.rPill,
                        ),
                      );
                    }),
                  ),
                  AuroraButton(
                    texto: _i == _slides.length - 1 ? 'Empezar' : 'Siguiente',
                    ancho: 150,
                    onPressed: _siguiente,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
