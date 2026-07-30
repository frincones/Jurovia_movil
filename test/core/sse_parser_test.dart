import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/core/network/sse_event.dart';
import 'package:jurovia/core/network/sse_parser.dart';

/// Pruebas del parser SSE.
///
/// Es la pieza de mayor riesgo del proyecto: todo el chat depende de ella y el
/// stream llega partido de forma impredecible por la red móvil. Por eso se
/// prueban sobre todo los casos feos, no los felices.
void main() {
  late SseParser parser;
  setUp(() => parser = SseParser());

  String evt(String nombre, String json) => 'event: $nombre\ndata: $json\n\n';

  group('casos básicos', () {
    test('un evento simple', () {
      final List<SseEvent> e = parser.agregar(
        evt('text_delta', '{"text":"hola"}'),
      );
      expect(e, hasLength(1));
      expect((e.single as TextDelta).texto, 'hola');
    });

    test('varios eventos en un mismo trozo', () {
      final List<SseEvent> e = parser.agregar(
        evt('text_delta', '{"text":"a"}') +
            evt('text_delta', '{"text":"b"}') +
            evt('done', '{"session_id":"s1","result":"ok"}'),
      );
      expect(e, hasLength(3));
      expect((e[0] as TextDelta).texto, 'a');
      expect((e[1] as TextDelta).texto, 'b');
      expect((e[2] as Done).sessionId, 's1');
    });

    test('sin separador todavía no emite nada', () {
      expect(parser.agregar('event: text_delta\ndata: {"text":"a"}'), isEmpty);
      expect(parser.tieneParcial, isTrue);
    });
  });

  group('fragmentación de la red', () {
    test('un evento partido en dos trozos', () {
      expect(parser.agregar('event: text_delta\nda'), isEmpty);
      final List<SseEvent> e = parser.agregar('ta: {"text":"partido"}\n\n');
      expect((e.single as TextDelta).texto, 'partido');
    });

    test('partido justo a la mitad del JSON', () {
      expect(parser.agregar('event: text_delta\ndata: {"text":"me'), isEmpty);
      final List<SseEvent> e = parser.agregar('dio"}\n\n');
      expect((e.single as TextDelta).texto, 'medio');
    });

    test('partido en el propio separador \\n\\n', () {
      expect(parser.agregar('event: done\ndata: {}\n'), isEmpty);
      final List<SseEvent> e = parser.agregar('\n');
      expect(e.single, isA<Done>());
    });

    test('llegada byte a byte reconstruye el evento', () {
      const String crudo = 'event: text_delta\ndata: {"text":"lento"}\n\n';
      final List<SseEvent> acumulados = <SseEvent>[];
      for (int i = 0; i < crudo.length; i++) {
        acumulados.addAll(parser.agregar(crudo[i]));
      }
      expect(acumulados, hasLength(1));
      expect((acumulados.single as TextDelta).texto, 'lento');
    });
  });

  group('latidos', () {
    test('el latido :hb se reconoce', () {
      final List<SseEvent> e = parser.agregar(':hb\n\n');
      expect(e.single, isA<Heartbeat>());
    });

    test('latidos intercalados no rompen los eventos', () {
      final List<SseEvent> e = parser.agregar(
        ':hb\n\n${evt('text_delta', '{"text":"x"}')}:hb\n\n',
      );
      expect(e, hasLength(3));
      expect(e[0], isA<Heartbeat>());
      expect(e[1], isA<TextDelta>());
      expect(e[2], isA<Heartbeat>());
    });
  });

  group('robustez', () {
    test('JSON corrupto no tumba el stream', () {
      final List<SseEvent> e = parser.agregar(
        'event: text_delta\ndata: {roto\n\n',
      );
      final SseUnknown u = e.single as SseUnknown;
      expect(u.nombre, SseParser.malformado);
      expect(u.datos['event'], 'text_delta');
    });

    test('tras un bloque corrupto se siguen procesando los siguientes', () {
      final List<SseEvent> e = parser.agregar(
        'event: text_delta\ndata: {roto\n\n${evt('done', '{"result":"ok"}')}',
      );
      expect(e, hasLength(2));
      expect(e[1], isA<Done>());
    });

    test(
      'un evento desconocido no es error (compatibilidad hacia adelante)',
      () {
        final List<SseEvent> e = parser.agregar(
          evt('evento_del_futuro', '{"a":1}'),
        );
        final SseUnknown u = e.single as SseUnknown;
        expect(u.nombre, 'evento_del_futuro');
        expect(u.datos['a'], 1);
      },
    );

    test('CRLF se normaliza', () {
      final List<SseEvent> e = parser.agregar(
        'event: done\r\ndata: {"result":"ok"}\r\n\r\n',
      );
      expect(e.single, isA<Done>());
    });

    test('data sin espacio tras los dos puntos', () {
      final List<SseEvent> e = parser.agregar(
        'event: text_delta\ndata:{"text":"z"}\n\n',
      );
      expect((e.single as TextDelta).texto, 'z');
    });

    test('data en varias líneas se concatena', () {
      final List<SseEvent> e = parser.agregar(
        'event: text_delta\ndata: {"text":\ndata: "multi"}\n\n',
      );
      expect((e.single as TextDelta).texto, 'multi');
    });

    test('evento sin data no revienta', () {
      final List<SseEvent> e = parser.agregar('event: done\n\n');
      expect(e.single, isA<Done>());
    });

    test('líneas id: y retry: se ignoran sin romper', () {
      final List<SseEvent> e = parser.agregar(
        'id: 42\nretry: 3000\nevent: done\ndata: {}\n\n',
      );
      expect(e.single, isA<Done>());
    });
  });

  group('secuencias reales feas', () {
    test('error después de haber emitido texto', () {
      final List<SseEvent> e = parser.agregar(
        evt('text_delta', '{"text":"parcial"}') +
            evt('error', '{"message":"se cayó","subtype":"anthropic"}'),
      );
      expect(e[0], isA<TextDelta>());
      final ErrorEvent err = e[1] as ErrorEvent;
      expect(err.mensaje, 'se cayó');
      expect(err.subtipo, 'anthropic');
    });

    test('blocked sin done: la UI debe cerrar igual', () {
      final List<SseEvent> e = parser.agregar(
        evt('blocked', '{"reason":"no_credits","message":"Sin créditos"}'),
      );
      final Blocked b = e.single as Blocked;
      expect(b.razon, 'no_credits');
      expect(e.whereType<Done>(), isEmpty);
    });

    test('turno completo con razonamiento, herramientas, fuentes y hooks', () {
      final List<SseEvent> e = parser.agregar(
        <String>[
          evt('thinking', '{"text":"analizando","message_id":"m1"}'),
          ':hb\n\n',
          evt('phase', '{"name":"buscar","status":"running"}'),
          evt(
            'tool_call',
            '{"id":"t1","name":"buscar_norma","input":{"q":"2536"}}',
          ),
          evt('verify_progress', '{"status":"checking"}'),
          evt('tool_result', '{"id":"t1","ok":true}'),
          evt('text_delta', '{"text":"La acción prescribe"}'),
          evt('artifact', '{"id":"a1","name":"Contestacion.docx"}'),
          evt(
            'hooks',
            '{"hooks":[{"label":"Redactar","tipo":"accion","prompt":"Redacta"}]}',
          ),
          evt('credits', '{"balance":180,"cap":500,"low":false}'),
          evt('usage', '{"input_tokens":100}'),
          evt('done', '{"session_id":"s9","result":"ok"}'),
        ].join(),
      );

      expect(e.whereType<Thinking>(), hasLength(1));
      expect(e.whereType<Heartbeat>(), hasLength(1));
      expect(e.whereType<Phase>(), hasLength(1));
      expect(e.whereType<ToolCall>(), hasLength(1));
      expect(e.whereType<VerifyProgress>(), hasLength(1));
      expect(e.whereType<Artifact>(), hasLength(1));
      expect(e.whereType<Done>(), hasLength(1));

      expect((e.whereType<ToolCall>().single).nombre, 'buscar_norma');
      expect((e.whereType<Artifact>().single).nombre, 'Contestacion.docx');
      expect((e.whereType<Hooks>().single).hooks.single.etiqueta, 'Redactar');
      expect((e.whereType<Credits>().single).saldo, 180);
    });

    test('acentos partidos entre trozos se reconstruyen', () {
      expect(
        parser.agregar('event: text_delta\ndata: {"text":"prescripci'),
        isEmpty,
      );
      final List<SseEvent> e = parser.agregar('ón"}\n\n');
      expect((e.single as TextDelta).texto, 'prescripción');
    });
  });

  group('ciclo de vida', () {
    test('reiniciar descarta lo parcial', () {
      parser.agregar('event: text_delta\ndata: {"text":"a"');
      expect(parser.tieneParcial, isTrue);
      parser.reiniciar();
      expect(parser.tieneParcial, isFalse);
    });
  });
}
