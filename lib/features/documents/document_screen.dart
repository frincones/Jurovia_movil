import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../compliance/legal/disclaimer.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/models/chat.dart';
import '../../shared/widgets/aurora_button.dart';

/// Texto de ayuda del visor. Se declara aparte para poder extraer de él la
/// selección del usuario sin repetirlo.
const String _kAyuda =
    'Este documento lo generó Jurovia a partir de tu consulta.\n\n'
    'Selecciona un fragmento y toca «Editar con Jurovia» para pedir un cambio '
    'puntual: el asistente lo aplica preservando el formato del archivo '
    'original.';

/// S07 · Visor de documento generado.
///
/// La **edición vuelve por el chat** (`edit_artifact_id` + `selection`), igual
/// que en la web: el DOCX no se edita en el cliente, lo hace el backend
/// preservando el formato.
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({super.key, required this.documentoId, this.artefacto});

  final String documentoId;
  final Artefacto? artefacto;

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  bool _descargando = false;
  String? _seleccion;

  String get _nombre => widget.artefacto?.nombre ?? 'Documento';

  /// Descarga el artefacto y abre la hoja de compartir del sistema (F2.25).
  Future<void> _compartir() async {
    setState(() => _descargando = true);
    try {
      final Response<List<int>> r = await ref
          .read(apiClientProvider)
          .dio
          .get<List<int>>(
            '/api/artifacts/${widget.documentoId}/download',
            options: Options(responseType: ResponseType.bytes),
          );
      final Directory dir = await getTemporaryDirectory();
      final File f = File('${dir.path}/$_nombre');
      await f.writeAsBytes(r.data ?? <int>[]);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(f.path)], subject: _nombre),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos preparar el archivo.')),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  /// Abre el chat pidiendo el cambio sobre ESTE artefacto (F2.26).
  ///
  /// Se pasan el id del artefacto y, si hay texto seleccionado, el fragmento.
  /// El backend los recibe como `edit_artifact_id` y `selection`, y devuelve
  /// una versión nueva conservando el formato.
  void _editar() {
    final Uri destino = Uri(
      path: Rutas.chat,
      queryParameters: <String, String>{
        'artefacto': widget.documentoId,
        'prompt': _seleccion == null
            ? 'Revisa y ajusta el documento $_nombre'
            : 'Reescribe este fragmento de $_nombre',
        'seleccion': ?_seleccion,
      },
    );
    context.push(destino.toString());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Column(
          children: <Widget>[
            Text(
              _nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
            ),
            Text(
              widget.artefacto?.subtitulo ?? 'Borrador',
              style: JvText.de(context).menor.copyWith(fontSize: 11.5),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Compartir documento',
            icon: _descargando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share, size: 20),
            onPressed: _descargando ? null : _compartir,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: JvShapes.rTarjeta,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: JvColors.de(context).secundario,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(_nombre, style: JvText.cuerpoFuerte),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SelectableText(
                          _kAyuda,
                          style: JvText.documento,
                          onSelectionChanged: (TextSelection s, _) {
                            final String t = s.textInside(_kAyuda).trim();
                            _seleccion = t.isEmpty ? null : t;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const AiLabel(),
                  const SizedBox(height: 16),
                  const DisclaimerBanner(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AuroraButton(
                      texto: 'Editar con Jurovia',
                      icono: Icons.edit_outlined,
                      onPressed: _editar,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _descargando ? null : _compartir,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: const Icon(Icons.download_outlined, size: 20),
                    ),
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
