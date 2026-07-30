import 'package:dio/dio.dart';

/// Error de API con mensaje presentable al usuario.
///
/// Nunca se muestra una traza técnica: el usuario es un abogado, no un
/// desarrollador. El detalle técnico queda en [detalle] para telemetría.
class ApiException implements Exception {
  const ApiException({
    required this.mensaje,
    this.codigo,
    this.detalle,
    this.tipo = ApiErrorTipo.desconocido,
  });

  final String mensaje;
  final int? codigo;
  final String? detalle;
  final ApiErrorTipo tipo;

  bool get esNoAutorizado => codigo == 401;
  bool get esSinPermiso => codigo == 403;
  bool get esNoEncontrado => codigo == 404;
  bool get esDeRed => tipo == ApiErrorTipo.red || tipo == ApiErrorTipo.timeout;

  factory ApiException.desdeDio(DioException e) {
    final int? codigo = e.response?.statusCode;

    final ApiErrorTipo tipo = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiErrorTipo.timeout,
      DioExceptionType.connectionError => ApiErrorTipo.red,
      DioExceptionType.cancel => ApiErrorTipo.cancelado,
      _ => codigo != null ? ApiErrorTipo.servidor : ApiErrorTipo.desconocido,
    };

    return ApiException(
      mensaje: _mensajeAmigable(tipo, codigo, e.response?.data),
      codigo: codigo,
      detalle: e.message,
      tipo: tipo,
    );
  }

  static String _mensajeAmigable(
    ApiErrorTipo tipo,
    int? codigo,
    Object? cuerpo,
  ) {
    // El backend devuelve {"detail": "..."} en los errores de FastAPI.
    if (cuerpo is Map && cuerpo['detail'] is String) {
      final String detalle = cuerpo['detail'] as String;
      // No se filtran mensajes internos de infraestructura.
      if (detalle.length < 120 && !detalle.contains('Traceback')) {
        return detalle;
      }
    }

    return switch (tipo) {
      ApiErrorTipo.timeout =>
        'La conexión tardó demasiado. Revisa tu red e inténtalo de nuevo.',
      ApiErrorTipo.red => 'Sin conexión. Comprueba tu internet.',
      ApiErrorTipo.cancelado => 'Operación cancelada.',
      // `codigo` es nullable: se normaliza antes de usar patrones relacionales.
      ApiErrorTipo.servidor => switch (codigo ?? 0) {
        401 => 'Tu sesión expiró. Vuelve a iniciar sesión.',
        403 => 'No tienes permiso para esta acción.',
        404 => 'No encontramos lo que buscabas.',
        429 => 'Demasiadas solicitudes. Espera un momento.',
        >= 500 => 'El servicio no está disponible. Inténtalo en unos minutos.',
        _ => 'No pudimos completar la operación.',
      },
      ApiErrorTipo.desconocido => 'Ocurrió un error inesperado.',
    };
  }

  @override
  String toString() => 'ApiException($codigo, $tipo): $mensaje';
}

enum ApiErrorTipo { red, timeout, servidor, cancelado, desconocido }
