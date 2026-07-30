import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';

/// Glifo "J" de Jurovia, calcado del prototipo.
///
/// El SVG original es `viewBox="14 12 68 76"` con el trazo
/// `M38 26 H60 V58 a16 16 0 1 1 -32 0` más un punto en (70, 67).
class _GlifoJ extends CustomPainter {
  const _GlifoJ({required this.color});

  final Color color;

  // Sistema de coordenadas del SVG original.
  static const double _vbX = 14, _vbY = 12, _vbW = 68, _vbH = 76;

  @override
  void paint(Canvas canvas, Size size) {
    final double escala = size.width / _vbW;
    canvas
      ..save()
      ..scale(escala, size.height / _vbH)
      ..translate(-_vbX, -_vbY);

    final Paint trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path j = Path()
      ..moveTo(38, 26)
      ..lineTo(60, 26)
      ..lineTo(60, 58)
      ..arcToPoint(
        const Offset(28, 58),
        radius: const Radius.circular(16),
        largeArc: true,
      );

    canvas
      ..drawPath(j, trazo)
      ..drawCircle(const Offset(70, 67), 6.5, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_GlifoJ old) => old.color != color;
}

/// Cuadrado con el gradiente aurora y el glifo J. Es la marca de la app.
class JuroviaMark extends StatelessWidget {
  const JuroviaMark({super.key, this.tamano = 38, this.sombra = true});

  final double tamano;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    // `Align` con factores de tamaño hace que el widget se ajuste al hijo aunque
    // el padre imponga restricciones ajustadas — por ejemplo dentro de un
    // ListView, donde si no la marca se estiraría a todo el ancho.
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          gradient: JvColors.aurora,
          borderRadius: BorderRadius.circular(tamano * 0.3),
          boxShadow: sombra ? JvShapes.sombraAurora : null,
        ),
        padding: EdgeInsets.all(tamano * 0.18),
        child: CustomPaint(painter: const _GlifoJ(color: Colors.white)),
      ),
    );
  }
}

/// Logotipo completo: "Jurov" en color de texto + "·ia" con degradado aurora.
class JuroviaLogo extends StatelessWidget {
  const JuroviaLogo({
    super.key,
    this.estilo,
    this.conMarca = false,
    this.tamanoMarca = 38,
  });

  final TextStyle? estilo;
  final bool conMarca;
  final double tamanoMarca;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = estilo ?? JvText.logo;
    final Color txt = Theme.of(context).colorScheme.onSurface;

    final Widget palabra = RichText(
      text: TextSpan(
        style: base.copyWith(color: txt),
        children: <InlineSpan>[
          const TextSpan(text: 'Jurov'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              // El degradado se aplica al texto "·ia": es el remate de la marca.
              shaderCallback: (Rect r) => JvColors.auroraCorta.createShader(r),
              child: Text('·ia', style: base.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (!conMarca) return palabra;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        JuroviaMark(tamano: tamanoMarca),
        const SizedBox(width: 11),
        palabra,
      ],
    );
  }
}

/// Avatar del agente en las respuestas del chat.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, this.tamano = 24});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    // Igual que en JuroviaMark: no debe estirarse si el padre da restricciones
    // ajustadas (listas, filas con stretch).
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          gradient: JvColors.aurora,
          borderRadius: BorderRadius.circular(tamano * 0.3),
        ),
        padding: EdgeInsets.all(tamano * 0.16),
        child: CustomPaint(painter: const _GlifoJ(color: Colors.white)),
      ),
    );
  }
}
