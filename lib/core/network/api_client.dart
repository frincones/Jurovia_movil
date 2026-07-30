import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// De dónde salen (y cómo se renuevan) los tokens.
///
/// Se abstrae para poder probar el interceptor sin Supabase.
abstract interface class TokenProvider {
  /// JWT actual, o `null` si no hay sesión.
  Future<String?> accessToken();

  /// Fuerza la renovación. Devuelve el token nuevo o `null` si falló.
  Future<String?> refrescar();

  /// Cierra la sesión: el refresh falló de forma irrecuperable.
  Future<void> cerrarSesion();
}

/// Añade `Authorization: Bearer` y reintenta **una sola vez** ante un 401.
///
/// El backend valida la firma del JWT por JWKS y resuelve `org_id`
/// server-side; la app nunca envía `org_id` ni nada equivalente.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._tokens);

  final TokenProvider _tokens;

  /// Marca para no entrar en bucle de reintentos.
  static const String _yaReintentado = 'jv_retry';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final String? token = await _tokens.accessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions req = err.requestOptions;
    final bool esAuth = err.response?.statusCode == 401;
    final bool reintentable = esAuth && req.extra[_yaReintentado] != true;

    if (!reintentable) return handler.next(err);

    final String? nuevo = await _tokens.refrescar();
    if (nuevo == null || nuevo.isEmpty) {
      // El refresh falló: la sesión está muerta de verdad.
      await _tokens.cerrarSesion();
      return handler.next(err);
    }

    try {
      final Options opciones = Options(
        method: req.method,
        headers: <String, dynamic>{
          ...req.headers,
          'Authorization': 'Bearer $nuevo',
        },
        responseType: req.responseType,
        contentType: req.contentType,
      );
      final Dio dio = Dio(BaseOptions(baseUrl: req.baseUrl));
      final Response<dynamic> respuesta = await dio.request<dynamic>(
        req.path,
        data: req.data,
        queryParameters: req.queryParameters,
        options: opciones..extra = <String, dynamic>{_yaReintentado: true},
      );
      return handler.resolve(respuesta);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}

/// Cliente HTTP contra el backend de Railway.
///
/// La app solo conoce dos hosts: este backend y Supabase (auth). Ningún
/// proveedor externo se invoca desde el cliente.
class ApiClient {
  ApiClient({required TokenProvider tokens, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = AppConfig.backendUrl
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 45)
      ..headers['Content-Type'] = 'application/json';
    _dio.interceptors.add(AuthInterceptor(tokens));
  }

  final Dio _dio;

  Dio get dio => _dio;

  Future<Map<String, dynamic>> get(
    String ruta, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final Response<dynamic> r = await _dio.get<dynamic>(
        ruta,
        queryParameters: query,
      );
      return _comoMapa(r.data);
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }

  Future<List<dynamic>> getLista(
    String ruta, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final Response<dynamic> r = await _dio.get<dynamic>(
        ruta,
        queryParameters: query,
      );
      final dynamic d = r.data;
      if (d is List) return d;
      if (d is Map && d.values.isNotEmpty) {
        final Object? primera = d.values.firstWhere(
          (Object? v) => v is List,
          orElse: () => null,
        );
        if (primera is List) return primera;
      }
      return <dynamic>[];
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }

  Future<Map<String, dynamic>> post(String ruta, {Object? cuerpo}) async {
    try {
      final Response<dynamic> r = await _dio.post<dynamic>(ruta, data: cuerpo);
      return _comoMapa(r.data);
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }

  Future<Map<String, dynamic>> patch(String ruta, {Object? cuerpo}) async {
    try {
      final Response<dynamic> r = await _dio.patch<dynamic>(ruta, data: cuerpo);
      return _comoMapa(r.data);
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }

  static Map<String, dynamic> _comoMapa(Object? d) {
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }
}
