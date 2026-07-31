import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';

/// Un archivo elegido por el usuario, listo para subir.
class Adjunto {
  const Adjunto({required this.ruta, required this.nombre, this.tamano});

  final String ruta;
  final String nombre;
  final int? tamano;

  File get archivo => File(ruta);

  String get tamanoLegible {
    final int? b = tamano;
    if (b == null) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// Selector de adjuntos.
///
/// **Los permisos se piden en contexto, no al arrancar** (AuditCheck §12.1):
/// la cámara solo cuando el usuario toca "Escanear". Un permiso pedido sin
/// motivo aparente es causa de rechazo y de desinstalación.
abstract final class SelectorAdjuntos {
  /// Hoja con las tres formas de adjuntar.
  static Future<Adjunto?> mostrar(BuildContext context) {
    return showModalBottomSheet<Adjunto>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(c).colorScheme.outlineVariant,
                    borderRadius: JvShapes.rPill,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Adjuntar', style: JvText.tituloHoja),
              const SizedBox(height: 16),
              _Opcion(
                icono: Icons.photo_camera_outlined,
                titulo: 'Escanear con la cámara',
                detalle: 'Fotografía un documento físico',
                onTap: () async {
                  final Adjunto? a = await camara();
                  if (c.mounted) Navigator.of(c).pop(a);
                },
              ),
              _Opcion(
                icono: Icons.photo_library_outlined,
                titulo: 'Imagen de la galería',
                onTap: () async {
                  final Adjunto? a = await galeria();
                  if (c.mounted) Navigator.of(c).pop(a);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Adjuntar documentos (PDF, DOCX…) — **pendiente**.
  ///
  /// Bloqueado por incompatibilidad de terceros: `file_picker` todavía aplica
  /// el Kotlin Gradle Plugin antiguo y Flutter 3.44 migró a *Built-in Kotlin*,
  /// así que el build de Android falla al enlazarlo.
  ///
  /// Alternativas cuando se retome: esperar a que `file_picker` migre, o
  /// implementar el selector con un canal de plataforma propio (Storage Access
  /// Framework en Android, UIDocumentPicker en iOS). Mientras tanto, escanear
  /// con la cámara cubre el caso principal en móvil.
  static Future<Adjunto?> documento() async => null;

  /// Cámara. El permiso lo pide el propio `image_picker` en este momento.
  static Future<Adjunto?> camara() async {
    try {
      final XFile? x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (x == null) return null;
      return Adjunto(ruta: x.path, nombre: x.name, tamano: await x.length());
    } on Object {
      return null;
    }
  }

  static Future<Adjunto?> galeria() async {
    try {
      final XFile? x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (x == null) return null;
      return Adjunto(ruta: x.path, nombre: x.name, tamano: await x.length());
    } on Object {
      return null;
    }
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.detalle,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          onTap: onTap,
          borderRadius: JvShapes.rLista,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(icono, size: 20, color: JvColors.purpura),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(titulo, style: JvText.cuerpoMedio),
                      if (detalle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(detalle!, style: JvText.de(context).menor),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip del adjunto seleccionado, sobre el composer.
class ChipAdjunto extends StatelessWidget {
  const ChipAdjunto({
    super.key,
    required this.adjunto,
    required this.onQuitar,
    this.subiendo = false,
  });

  final Adjunto adjunto;
  final VoidCallback onQuitar;
  final bool subiendo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: JvShapes.rCampo,
      ),
      child: Row(
        children: <Widget>[
          if (subiendo)
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.attach_file,
              size: 15,
              color: JvColors.de(context).secundario,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              adjunto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JvText.de(context).menor,
            ),
          ),
          if (adjunto.tamanoLegible.isNotEmpty)
            Text(adjunto.tamanoLegible, style: JvText.de(context).menor),
          if (!subiendo)
            IconButton(
              icon: const Icon(Icons.close, size: 15),
              tooltip: 'Quitar adjunto',
              visualDensity: VisualDensity.compact,
              onPressed: onQuitar,
            ),
        ],
      ),
    );
  }
}
