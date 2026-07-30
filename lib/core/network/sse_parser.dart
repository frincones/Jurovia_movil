import 'dart:convert';

import 'sse_event.dart';

/// Parser incremental del protocolo SSE del backend.
///
/// Deliberadamente **puro**: no sabe nada de HTTP. Se le entregan trozos de
/// texto tal como llegan del socket —que pueden partir un evento por la
/// mitad— y devuelve los eventos completos que haya podido formar.
///
/// Formato del cable (`app/bridge.py`):
/// ```
/// event: text_delta\n
/// data: {"text":"hola"}\n
/// \n
/// ```
/// y el latido, que es un comentario SSE: `:hb\n\n`
class SseParser {
  final StringBuffer _buffer = StringBuffer();

  /// Nombre que se usa cuando un bloque llega con JSON inválido.
  static const String malformado = '_malformed';

  /// Alimenta el parser con un trozo y devuelve los eventos ya completos.
  ///
  /// Un trozo puede contener 0, 1 o muchos eventos, y puede cortar el último
  /// por la mitad: lo incompleto queda retenido hasta el siguiente trozo.
  List<SseEvent> agregar(String trozo) {
    _buffer.write(trozo);
    String contenido = _buffer.toString();

    // Normaliza CRLF: algunos proxies reescriben los saltos de línea.
    contenido = contenido.replaceAll('\r\n', '\n');

    final List<SseEvent> eventos = <SseEvent>[];
    int corte;
    while ((corte = contenido.indexOf('\n\n')) != -1) {
      final String bloque = contenido.substring(0, corte);
      contenido = contenido.substring(corte + 2);

      final SseEvent? evento = _parseBloque(bloque);
      if (evento != null) eventos.add(evento);
    }

    _buffer
      ..clear()
      ..write(contenido);
    return eventos;
  }

  /// Descarta lo que quedara a medias. Se llama al cerrar el stream.
  void reiniciar() => _buffer.clear();

  /// ¿Hay un evento a medio formar? Útil en pruebas y diagnóstico.
  bool get tieneParcial => _buffer.isNotEmpty;

  SseEvent? _parseBloque(String bloque) {
    if (bloque.trim().isEmpty) return null;

    String? nombre;
    final StringBuffer datos = StringBuffer();
    bool esComentario = false;

    for (final String linea in bloque.split('\n')) {
      if (linea.isEmpty) continue;

      if (linea.startsWith(':')) {
        // Comentario SSE. El backend lo usa como latido (`:hb`).
        esComentario = true;
        continue;
      }
      if (linea.startsWith('event:')) {
        nombre = linea.substring(6).trim();
        continue;
      }
      if (linea.startsWith('data:')) {
        // El espacio tras los dos puntos es opcional en la especificación.
        final String parte = linea.substring(5);
        if (datos.isNotEmpty) datos.write('\n');
        datos.write(parte.startsWith(' ') ? parte.substring(1) : parte);
        continue;
      }
      // `id:` y `retry:` no los usa este backend; se ignoran sin romper.
    }

    if (nombre == null) {
      // Bloque sin `event:`. Si traía comentario, es un latido.
      return esComentario ? const Heartbeat() : null;
    }

    final String crudo = datos.toString();
    if (crudo.isEmpty) return SseEvent.desde(nombre, <String, dynamic>{});

    try {
      final Object? decodificado = jsonDecode(crudo);
      if (decodificado is Map<String, dynamic>) {
        return SseEvent.desde(nombre, decodificado);
      }
      // El contrato siempre manda objetos; cualquier otra cosa se envuelve.
      return SseUnknown(
        nombre: nombre,
        datos: <String, dynamic>{'value': decodificado},
      );
    } on FormatException {
      // Nunca hacer caer el stream por un bloque corrupto: un turno de varios
      // minutos no puede perderse por un byte mal copiado.
      return SseUnknown(
        nombre: malformado,
        datos: <String, dynamic>{'event': nombre, 'raw': crudo},
      );
    }
  }
}
