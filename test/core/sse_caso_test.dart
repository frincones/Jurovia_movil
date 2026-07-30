import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/core/network/sse_event.dart';
import 'package:jurovia/core/network/sse_parser.dart';

/// E4 · Los dos eventos con los que el agente convierte un chat en expediente.
///
/// Payloads copiados de `app/agent/runner.py` (`_autocreate_case` y el `yield`
/// de `CASE_SUGGESTION`), no inventados.
void main() {
  group('case_suggestion', () {
    test('se tipa con todos los datos que trae el agente', () {
      final SseEvent e = SseEvent.desde('case_suggestion', <String, dynamic>{
        'es_caso': true,
        'modo': 'propose',
        'score': 4,
        'nombre': 'Restrepo vs. Seguros Bolívar',
        'cliente': 'Ana Restrepo',
        'contraparte': 'Seguros Bolívar S.A.',
        'materia': 'civil',
        'radicado': null,
        'session_id': 's1',
      });

      expect(e, isA<CaseSuggestion>());
      final CaseSuggestion s = e as CaseSuggestion;
      expect(s.nombre, 'Restrepo vs. Seguros Bolívar');
      expect(s.cliente, 'Ana Restrepo');
      expect(s.contraparte, 'Seguros Bolívar S.A.');
      expect(s.materia, 'civil');
      expect(s.radicado, isNull);
      expect(s.sessionId, 's1');
    });

    test('sin nombre no revienta: la UI ofrece el texto genérico', () {
      final CaseSuggestion s =
          SseEvent.desde('case_suggestion', <String, dynamic>{'es_caso': true})
              as CaseSuggestion;
      expect(s.nombre, isNull);
    });
  });

  group('case_created', () {
    test('trae el id y el código con el que el abogado lo va a buscar', () {
      final SseEvent e = SseEvent.desde('case_created', <String, dynamic>{
        'matter_id': 'm1',
        'code': 'JUR-2607-A31X',
        'nombre': 'Restrepo vs. Seguros',
        'radicado': '05001400301020240078900',
        'session_id': 's1',
      });

      expect(e, isA<CaseCreated>());
      final CaseCreated c = e as CaseCreated;
      expect(c.matterId, 'm1');
      expect(c.codigo, 'JUR-2607-A31X');
      expect(c.nombre, 'Restrepo vs. Seguros');
    });
  });

  test('llegan bien por el cable, entre otros eventos', () {
    final SseParser p = SseParser();
    final List<SseEvent> vistos = <SseEvent>[];

    // Un trozo cortado a mitad de línea, como llega de verdad.
    for (final String trozo in <String>[
      'event: text_delta\ndata: {"text":"Listo"}\n\n'
          'event: case_crea',
      'ted\ndata: {"matter_id":"m1","code":"JUR-2607-A31X",'
          '"nombre":"Restrepo"}\n\n:hb\n\n'
          'event: done\ndata: {"session_id":"s1"}\n\n',
    ]) {
      vistos.addAll(p.agregar(trozo));
    }

    expect(vistos.whereType<CaseCreated>(), hasLength(1));
    expect(vistos.whereType<CaseCreated>().single.codigo, 'JUR-2607-A31X');
    expect(vistos.whereType<Done>(), hasLength(1));
  });

  test('una app vieja frente a un evento nuevo no se cae', () {
    final SseEvent e = SseEvent.desde('case_algo_futuro', <String, dynamic>{});
    expect(e, isA<SseUnknown>());
  });
}
