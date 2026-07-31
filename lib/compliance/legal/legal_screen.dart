import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import 'disclaimer.dart';

/// S15 · Legal.
///
/// **AuditCheck A3.27 (Apple 5.1.1(i)):** la política de privacidad debe estar
/// enlazada *dentro* de la app, de forma accesible, no solo en la ficha de la
/// tienda.
///
/// ⚠️ Ninguno de estos enlaces lleva a comprar. Son documentos legales, no
/// *steering* (Apple 3.1.3).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            const DisclaimerBanner(),
            const SizedBox(height: 24),
            Text('DOCUMENTOS', style: JvText.de(context).etiqueta),
            const SizedBox(height: 10),
            const _Documento(
              titulo: 'Términos y condiciones',
              url: TextosLegales.urlTerminos,
            ),
            const _Documento(
              titulo: 'Política de privacidad',
              url: TextosLegales.urlPrivacidad,
            ),
            const _Documento(
              titulo: 'Política de cancelación',
              url: TextosLegales.urlCancelacion,
            ),
            const SizedBox(height: 24),
            Text('SOBRE JUROVIA', style: JvText.de(context).etiqueta),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: JvShapes.rCampo,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Jurovia · TDX Transformación Digital S.A.S.',
                    style: JvText.cuerpoMedio,
                  ),
                  const SizedBox(height: 4),
                  Text('Medellín, Colombia', style: JvText.de(context).menor),
                  const SizedBox(height: 10),
                  Text(
                    'El contenido normativo y jurisprudencial citado pertenece '
                    'a sus fuentes oficiales. Jurovia lo referencia y contrasta, '
                    'no reclama su titularidad.',
                    style: JvText.de(context).menor.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Documento extends StatelessWidget {
  const _Documento({required this.titulo, required this.url});

  final String titulo;
  final String url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          borderRadius: JvShapes.rLista,
          onTap: () async {
            final Uri uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.article_outlined,
                  size: 18,
                  color: JvColors.de(context).secundario,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(titulo, style: JvText.cuerpoMedio)),
                Icon(
                  Icons.open_in_new,
                  size: 15,
                  color: JvColors.de(context).terciario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
