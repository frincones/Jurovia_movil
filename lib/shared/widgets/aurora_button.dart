import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';

/// CTA principal de Jurovia: píldora con el gradiente aurora y sombra teñida.
///
/// Es el botón de mayor jerarquía. Debe haber **uno solo** por pantalla.
class AuroraButton extends StatelessWidget {
  const AuroraButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.ancho = double.infinity,
    this.icono,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final double ancho;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final bool activo = onPressed != null && !cargando;

    return Opacity(
      opacity: activo ? 1 : 0.55,
      child: Container(
        width: ancho,
        decoration: BoxDecoration(
          gradient: JvColors.aurora,
          borderRadius: JvShapes.rPill,
          boxShadow: activo ? JvShapes.sombraAurora : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: activo ? onPressed : null,
            borderRadius: JvShapes.rPill,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (cargando) ...<Widget>[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (icono != null) ...<Widget>[
                    Icon(icono, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      texto,
                      style: JvText.boton,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario: superficie blanca con borde. Sin gradiente.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.ancho = double.infinity,
    this.destructivo = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final double ancho;
  final bool destructivo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = destructivo ? JvColors.peligro : cs.onSurface;

    return SizedBox(
      width: ancho,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: destructivo
                ? JvColors.peligro.withValues(alpha: 0.4)
                : cs.outlineVariant,
          ),
        ),
        child: Text(texto, style: JvText.cuerpoFuerte.copyWith(color: color)),
      ),
    );
  }
}
