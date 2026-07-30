import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';

/// Textos legales de la app. Un solo sitio para poder auditarlos.
abstract final class TextosLegales {
  /// AuditCheck C8.16 · Apple 1.4.1 (apps de asesoría profesional).
  static const String noEsAsesoria =
      'Jurovia es una herramienta de apoyo y no sustituye la asesoría de un '
      'profesional del derecho. Sus respuestas pueden contener errores y deben '
      'verificarse antes de usarse.';

  /// AuditCheck C8.8 + C8.17: etiquetado de IA + verificación.
  static const String piePorRespuesta =
      'Generado por IA · Tú revisas y decides.';

  /// Lema de marca.
  static const String lema = 'Tú revisas y decides.';

  static const String urlTerminos = 'https://juroviapp.com/terminos';
  static const String urlPrivacidad = 'https://juroviapp.com/privacidad';
  static const String urlCancelacion = 'https://juroviapp.com/cancelacion';
  static const String urlEliminarCuenta =
      'https://juroviapp.com/eliminar-cuenta';
}

/// Etiqueta "Generado por IA" + descargo, al pie de cada respuesta del agente.
///
/// **AuditCheck C8.8 (etiquetado de contenido de IA) y C8.17 (descargo).**
/// Ambas tiendas exigen que el usuario sepa que el contenido lo generó una IA.
/// No es decorativo: quitarlo hace rechazable la app.
class AiLabel extends StatelessWidget {
  const AiLabel({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.auto_awesome, size: 12, color: JvColors.txtTerciario),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            compacto ? 'Generado por IA' : TextosLegales.piePorRespuesta,
            style: JvText.menor.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Aviso legal en bloque, para onboarding y pantallas de ajustes.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, this.texto});

  final String? texto;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: JvShapes.rCampo,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 16,
            color: JvColors.txtTerciario,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto ?? TextosLegales.noEsAsesoria,
              style: JvText.menor.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
