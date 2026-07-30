import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';

/// Dictado por voz → texto.
///
/// Graba con el micrófono y envía el audio a `POST /api/transcribe`, que en el
/// backend usa Whisper. El permiso de micrófono lo pide `record` **en el
/// momento de grabar**, no al arrancar la app (AuditCheck §12.1).
class Dictado {
  Dictado(this._api);

  final ApiClient _api;
  final AudioRecorder _grabadora = AudioRecorder();
  String? _rutaActual;

  Future<bool> get puedeGrabar => _grabadora.hasPermission();

  Future<bool> iniciar() async {
    if (!await _grabadora.hasPermission()) return false;
    final Directory dir = await getTemporaryDirectory();
    _rutaActual =
        '${dir.path}/jv_dictado_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _grabadora.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: _rutaActual!,
    );
    return true;
  }

  /// Detiene, sube y devuelve la transcripción. `null` si algo falló.
  Future<String?> detenerYTranscribir() async {
    final String? ruta = await _grabadora.stop();
    final String? destino = ruta ?? _rutaActual;
    if (destino == null) return null;

    final File audio = File(destino);
    if (!audio.existsSync() || audio.lengthSync() < 1024) {
      // Grabación demasiado corta para tener contenido.
      _limpiar(audio);
      return null;
    }

    try {
      final FormData form = FormData.fromMap(<String, dynamic>{
        'file': await MultipartFile.fromFile(destino, filename: 'dictado.m4a'),
      });
      final Response<dynamic> r = await _api.dio.post<dynamic>(
        '/api/transcribe',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final dynamic d = r.data;
      if (d is Map) {
        return (d['text'] ?? d['transcript'] ?? d['texto']) as String?;
      }
      return null;
    } on Object {
      return null;
    } finally {
      // El audio es efímero: no se conserva en el dispositivo.
      _limpiar(audio);
    }
  }

  Future<void> cancelar() async {
    await _grabadora.cancel();
    final String? r = _rutaActual;
    if (r != null) _limpiar(File(r));
  }

  void _limpiar(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } on Object {
      // Si no se puede borrar ahora, el SO limpia el temporal.
    }
  }

  Future<void> liberar() => _grabadora.dispose();
}

/// Indicador de grabación sobre el composer.
class BarraDictado extends StatelessWidget {
  const BarraDictado({
    super.key,
    required this.segundos,
    required this.onDetener,
    required this.onCancelar,
    this.transcribiendo = false,
  });

  final int segundos;
  final VoidCallback onDetener;
  final VoidCallback onCancelar;
  final bool transcribiendo;

  String get _tiempo {
    final int m = segundos ~/ 60;
    final int s = segundos % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: JvColors.peligro.withValues(alpha: 0.07),
        borderRadius: JvShapes.rCampo,
        border: Border.all(color: JvColors.peligro.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          if (transcribiendo) ...<Widget>[
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text('Transcribiendo…', style: JvText.menor)),
          ] else ...<Widget>[
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: JvColors.peligro,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Grabando · $_tiempo',
              style: JvText.menor.copyWith(color: JvColors.peligro),
            ),
            const Spacer(),
            TextButton(onPressed: onCancelar, child: const Text('Cancelar')),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onDetener,
              style: FilledButton.styleFrom(
                backgroundColor: JvColors.purpura,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                'Listo',
                style: JvText.chip.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
