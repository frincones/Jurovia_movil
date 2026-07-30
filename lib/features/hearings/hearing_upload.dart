import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

/// Estado de una subida de audiencia.
class ProgresoSubida {
  const ProgresoSubida({
    required this.enviados,
    required this.total,
    this.fase = 'subiendo',
  });

  final int enviados;
  final int total;
  final String fase;

  double get fraccion => total <= 0 ? 0 : (enviados / total).clamp(0.0, 1.0);
  int get porcentaje => (fraccion * 100).round();

  String get legible {
    if (total <= 0) return '';
    final double mb = total / 1024 / 1024;
    final double hechos = enviados / 1024 / 1024;
    return '${hechos.toStringAsFixed(1)} de ${mb.toStringAsFixed(1)} MB';
  }
}

/// Sube la grabación de una audiencia.
///
/// **Tres pasos, y el archivo NO pasa por el backend** (arquitectura §11.1):
///  1. `POST /api/audiencias/upload-url` → URL firmada de **Supabase Storage**
///     (bucket `audiencia_tmp`, ruta `{org_id}/{uuid}.bin`).
///  2. La app sube el archivo **directo a Supabase Storage**.
///  3. `POST /api/audiencias` encola el job; el `audiencia-worker` de Railway lo
///     descarga, transcribe y borra el temporal.
///
/// Un audio de audiencia puede durar horas: subirlo a través del backend lo
/// tumbaría.
class SubidaAudiencia {
  SubidaAudiencia(this._api);

  final ApiClient _api;
  CancelToken? _cancelacion;

  /// Tamaño a partir del cual se avisa de que conviene usar Wi-Fi.
  static const int umbralWifi = 25 * 1024 * 1024;

  bool get enCurso => _cancelacion != null && !_cancelacion!.isCancelled;

  /// Ejecuta los tres pasos. Devuelve el `job_id` o `null` si algo falló.
  Future<String?> subir({
    required File archivo,
    required String nombre,
    void Function(ProgresoSubida)? onProgreso,
    String? matterId,
  }) async {
    _cancelacion = CancelToken();
    final int total = await archivo.length();

    try {
      // ── 1. URL firmada ────────────────────────────────────────────────
      onProgreso?.call(
        ProgresoSubida(enviados: 0, total: total, fase: 'preparando'),
      );
      final Map<String, dynamic> firma = await _api.post(
        '/api/audiencias/upload-url',
      );
      final String? url = firma['upload_url'] as String?;
      final String? ruta = firma['storage_path'] as String?;
      if (url == null || ruta == null) return null;

      // ── 2. Subida directa a Supabase Storage ──────────────────────────
      // Se usa un Dio limpio: esta petición NO lleva el bearer del backend,
      // la URL ya viene firmada.
      final Dio directo = Dio();
      await directo.put<void>(
        url,
        data: archivo.openRead(),
        cancelToken: _cancelacion,
        options: Options(
          headers: <String, dynamic>{
            Headers.contentLengthHeader: total,
            'Content-Type': 'application/octet-stream',
          },
          // Una audiencia larga puede tardar mucho: sin timeout de envío.
          sendTimeout: null,
          receiveTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: (int enviados, int _) =>
            onProgreso?.call(ProgresoSubida(enviados: enviados, total: total)),
      );

      // ── 3. Encolar el job ─────────────────────────────────────────────
      onProgreso?.call(
        ProgresoSubida(enviados: total, total: total, fase: 'encolando'),
      );
      final Map<String, dynamic> job = await _api.post(
        '/api/audiencias',
        cuerpo: <String, dynamic>{
          'storage_path': ruta,
          'filename': nombre,
          'matter_id': ?matterId,
        },
      );
      return (job['job_id'] ?? job['id']) as String?;
    } on Object {
      return null;
    } finally {
      _cancelacion = null;
    }
  }

  /// Encola una audiencia desde un enlace (YouTube, Rama Judicial…).
  Future<String?> desdeEnlace(String enlace, {String? matterId}) async {
    try {
      final Map<String, dynamic> job = await _api.post(
        '/api/audiencias',
        cuerpo: <String, dynamic>{'url': enlace.trim(), 'matter_id': ?matterId},
      );
      return (job['job_id'] ?? job['id']) as String?;
    } on Object {
      return null;
    }
  }

  /// Consulta el estado de un job (para el *polling*).
  Future<Map<String, dynamic>?> estado(String jobId) async {
    try {
      return await _api.get('/api/audiencias/$jobId');
    } on Object {
      return null;
    }
  }

  void cancelar() {
    if (_cancelacion != null && !_cancelacion!.isCancelled) {
      _cancelacion!.cancel('cancelado por el usuario');
    }
    _cancelacion = null;
  }
}
