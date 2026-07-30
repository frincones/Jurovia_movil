import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'sse_event.dart';
import 'sse_parser.dart';

/// Cliente SSE del chat.
///
/// **Por qué no se usa `EventSource` ni ningún paquete SSE de pub.dev:**
/// el backend expone el chat como `POST /api/chat/{id}` con cuerpo JSON y
/// responde `text/event-stream`. `EventSource` solo hace `GET` y no permite
/// enviar cuerpo ni cabeceras, así que no sirve. Se lee el stream a mano, igual
/// que el frontend web hace con `fetch` + `getReader()`.
///
/// Reglas no negociables (arquitectura §10.3):
///  1. El silencio **no** es desconexión antes de [ventanaSilencio]: el backend
///     emite latidos `:hb` antes de los bloques largos sin salida.
///  2. Si el stream cae, **nunca** se reenvía el turno: el backend ya persistió
///     lo hecho y reenviar duplica el mensaje y vuelve a cobrar créditos.
///  3. Sin timeouts agresivos: un turno de investigación tarda minutos.
class SseClient {
  // Dart no permite parámetros con nombre privado, así que el campo se asigna
  // en la lista de inicialización: la regla no aplica a este caso.
  SseClient({
    required Dio dio,
    this.ventanaSilencio = const Duration(seconds: 90),
  })
    // ignore: prefer_initializing_formals
    : _dio = dio;

  final Dio _dio;

  /// Tiempo máximo sin recibir **nada** (ni siquiera un latido) antes de
  /// considerar el stream caído. 90 s con holgura sobre la cadencia real.
  final Duration ventanaSilencio;

  CancelToken? _cancelToken;

  /// ¿Hay un stream abierto ahora mismo?
  bool get activo => _cancelToken != null && !_cancelToken!.isCancelled;

  /// Abre el stream y emite los eventos según llegan.
  ///
  /// El [Stream] se cierra con `done`, con `error`, al cancelar, o si se supera
  /// [ventanaSilencio].
  Stream<SseEvent> stream({
    required String ruta,
    Map<String, dynamic>? cuerpo,
  }) {
    final StreamController<SseEvent> salida = StreamController<SseEvent>();
    final SseParser parser = SseParser();
    final CancelToken cancel = CancelToken();
    _cancelToken = cancel;

    Timer? vigia;
    StreamSubscription<List<int>>? suscripcion;

    void reiniciarVigia() {
      vigia?.cancel();
      vigia = Timer(ventanaSilencio, () {
        // Silencio prolongado: ni datos ni latidos. Se cierra con error para
        // que la UI recargue la sesión — NUNCA para reenviar el turno.
        if (!salida.isClosed) {
          salida.add(
            const ErrorEvent(
              mensaje: 'Se perdió la conexión con el servidor.',
              subtipo: 'silencio',
            ),
          );
          salida.close();
        }
        cancel.cancel('silencio');
        suscripcion?.cancel();
      });
    }

    Future<void> arrancar() async {
      try {
        final Response<ResponseBody> respuesta = await _dio.post<ResponseBody>(
          ruta,
          data: cuerpo,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            headers: <String, dynamic>{'Accept': 'text/event-stream'},
            // El turno puede tardar minutos: sin timeout de recepción.
            receiveTimeout: null,
          ),
        );

        reiniciarVigia();

        suscripcion = respuesta.data!.stream.listen(
          (List<int> bytes) {
            reiniciarVigia();
            // `allowMalformed` evita romper si un carácter multibyte queda
            // partido entre dos paquetes TCP.
            final String trozo = utf8.decode(bytes, allowMalformed: true);
            for (final SseEvent e in parser.agregar(trozo)) {
              if (salida.isClosed) return;
              salida.add(e);
              if (e is Done) {
                vigia?.cancel();
                salida.close();
                suscripcion?.cancel();
                return;
              }
            }
          },
          onError: (Object error, StackTrace _) {
            vigia?.cancel();
            if (salida.isClosed) return;
            salida.add(
              ErrorEvent(
                mensaje: error is DioException
                    ? ApiException.desdeDio(error).mensaje
                    : 'Se interrumpió la respuesta.',
                subtipo: 'stream',
              ),
            );
            salida.close();
          },
          onDone: () {
            vigia?.cancel();
            // El servidor cerró sin `done`: el turno quedó a medias. La UI debe
            // recargar la sesión, no reintentar el envío.
            if (!salida.isClosed) salida.close();
          },
          cancelOnError: true,
        );
      } on DioException catch (e) {
        vigia?.cancel();
        if (!salida.isClosed) {
          if (!CancelToken.isCancel(e)) {
            salida.add(
              ErrorEvent(
                mensaje: ApiException.desdeDio(e).mensaje,
                subtipo: 'conexion',
              ),
            );
          }
          salida.close();
        }
      }
    }

    salida.onListen = arrancar;
    salida.onCancel = () async {
      vigia?.cancel();
      await suscripcion?.cancel();
      if (!cancel.isCancelled) cancel.cancel('cerrado por la UI');
      parser.reiniciar();
    };

    return salida.stream;
  }

  /// Cancela el stream en curso, si lo hay.
  ///
  /// Ojo: cancelar **no** detiene el turno en el servidor. El backend sigue y
  /// persiste el resultado; al volver, la UI lo recupera con
  /// `GET /api/sessions/{id}`.
  void cancelar() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('cancelado');
    }
    _cancelToken = null;
  }
}
