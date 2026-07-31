import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';

/// Escudo con el "check" del prototipo.
class _Escudo extends CustomPainter {
  const _Escudo({required this.color, this.grosor = 2.4});

  final Color color;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final double e = size.width / 24; // el SVG original es de 24×24
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z
    final Path escudo = Path()
      ..moveTo(12 * e, 22 * e)
      ..cubicTo(12 * e, 22 * e, 20 * e, 18 * e, 20 * e, 12 * e)
      ..lineTo(20 * e, 5 * e)
      ..lineTo(12 * e, 2 * e)
      ..lineTo(4 * e, 5 * e)
      ..lineTo(4 * e, 12 * e)
      ..cubicTo(4 * e, 18 * e, 12 * e, 22 * e, 12 * e, 22 * e)
      ..close();

    // M9 12l2 2 4-4
    final Path check = Path()
      ..moveTo(9 * e, 12 * e)
      ..lineTo(11 * e, 14 * e)
      ..lineTo(15 * e, 10 * e);

    canvas
      ..drawPath(escudo, p)
      ..drawPath(check, p);
  }

  @override
  bool shouldRepaint(_Escudo old) => old.color != color;
}

/// Insignia "Fuente verificada".
///
/// ⚠️ **El dorado significa verificación real contra fuente oficial.**
/// No usar este componente —ni sus colores— con contenido no contrastado:
/// es la promesa central del producto y afecta a la regla 2.3 de Apple
/// (metadata veraz).
class VerifiedChip extends StatelessWidget {
  const VerifiedChip({super.key, this.texto = 'Fuente verificada'});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: JvShapes.rPill,
        border: Border.all(color: JvColors.borde),
        boxShadow: JvShapes.sombraTarjeta,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 13,
            height: 13,
            child: CustomPaint(
              painter: const _Escudo(color: JvColors.verificado, grosor: 3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: JvText.chip.copyWith(color: JvColors.verificadoTxt),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de fuente verificada que aparece bajo la respuesta del agente.
class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.titulo,
    required this.detalle,
    this.onTap,
  });

  final String titulo;
  final String detalle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: JvColors.verificadoFondo,
      borderRadius: JvShapes.rCampo,
      child: InkWell(
        onTap: onTap,
        borderRadius: JvShapes.rCampo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: JvShapes.rCampo,
            border: Border.all(color: JvColors.verificadoBorde),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: JvColors.verificadoIcono,
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.all(6),
                child: CustomPaint(
                  painter: const _Escudo(color: Colors.white, grosor: 3),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JvText.cuerpoFuerte.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JvText.de(
                        context,
                      ).menor.copyWith(color: JvColors.verificadoTxt),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: JvColors.verificadoTxt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
