@Tags(<String>['integracion'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/core/config/app_config.dart';
import 'package:jurovia/core/network/sse_client.dart';
import 'package:jurovia/core/network/sse_event.dart';

/// Prueba de integración del [SseClient] contra el backend **real**.
///
/// Valida el camino completo: POST con cuerpo → `text/event-stream` → parser →
/// eventos tipados. Es la comprobación de que la pieza de mayor riesgo del
/// proyecto funciona contra producción, no solo contra streams grabados.
///
/// Usa `/api/guest/chat/{id}`, que no requiere autenticación. **Consume un turno
/// de la cuota de invitado** y deja rastro en la analítica del backend, por eso
/// está etiquetada y no corre en el CI normal:
///
/// ```
/// flutter test test/integration --tags integracion
/// ```
void main() {
  test(
    'el SseClient recibe y parsea un turno real del backend de producción',
    () async {
      final Dio dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.backendUrl,
          headers: <String, dynamic>{'Content-Type': 'application/json'},
        ),
      );
      final SseClient cliente = SseClient(dio: dio);

      final String sessionId =
          'test-${DateTime.now().millisecondsSinceEpoch}-integracion';

      final List<SseEvent> recibidos = <SseEvent>[];
      await for (final SseEvent e in cliente.stream(
        ruta: '/api/guest/chat/$sessionId',
        cuerpo: <String, dynamic>{
          'message':
              '¿Qué es la prescripción extintiva? Responde en una frase.',
          'guest_id': 'jv-flutter-integracion-$sessionId',
        },
      )) {
        recibidos.add(e);
        // Cortafuegos: si algo va mal, no colgarse indefinidamente.
        if (recibidos.length > 4000) break;
      }

      // 1. Llegó algo.
      expect(
        recibidos,
        isNotEmpty,
        reason: 'el backend no emitió ningún evento',
      );

      // 2. Todos los eventos se parsearon a tipos conocidos (o Unknown, que es
      //    válido), pero ninguno quedó como bloque corrupto.
      final Iterable<SseUnknown> malformados = recibidos
          .whereType<SseUnknown>()
          .where((SseUnknown u) => u.nombre == '_malformed');
      expect(
        malformados,
        isEmpty,
        reason:
            'hubo bloques que el parser no supo leer: '
            '${malformados.map((SseUnknown u) => u.datos).toList()}',
      );

      // 3. El turno cerró bien: o respondió, o quedó bloqueado por cuota.
      //    Ambos son finales legítimos.
      final bool tuvoTexto = recibidos.whereType<TextDelta>().isNotEmpty;
      final bool bloqueado = recibidos.whereType<Blocked>().isNotEmpty;
      final bool termino = recibidos.whereType<Done>().isNotEmpty;

      expect(
        tuvoTexto || bloqueado,
        isTrue,
        reason:
            'ni respuesta ni bloqueo: el contrato SSE cambió. '
            'Eventos: ${recibidos.map((SseEvent e) => e.runtimeType).toList()}',
      );
      expect(termino, isTrue, reason: 'el stream no terminó con `done`');

      // 4. Si respondió, el texto concatenado tiene contenido real.
      if (tuvoTexto) {
        final String texto = recibidos
            .whereType<TextDelta>()
            .map((TextDelta t) => t.texto)
            .join();
        expect(texto.trim().length, greaterThan(10));
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
