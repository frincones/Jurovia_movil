import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/shared/models/briefing.dart';

/// Contrato de `GET /api/briefing`, copiado de `app/agent/briefing.py`.
///
/// Este endpoint es el que alimenta **también** el Parte Diario por correo. Si
/// la app lee un campo con otro nombre, el abogado ve en la pantalla algo
/// distinto de lo que le llegó al buzón — que es exactamente lo que el briefing
/// existe para evitar.
void main() {
  const String crudo = '''
  {
    "escudo": {"dias_sin_vencer": 43, "vigilados": 7, "perdidos": 0},
    "overnight": {"movimientos": [
      {"matter_id": "m1", "name": "Restrepo vs. Seguros", "code": "JUR-2607-A31X",
       "event_type": "actuacion", "summary": "Auto admite la demanda"}
    ]},
    "atencion": {
      "terminos": [
        {"id": "d1", "title": "Contestar demanda", "deadline_at": "2026-07-31T00:00:00Z",
         "daysLeft": 2, "severity": "critico", "matter_id": "m1", "confidence": "tentativo"}
      ],
      "borradores": [{"id": "a1", "title": "Contestación lista", "matter_id": "m1"}],
      "pendientes": [{"id": "t1", "title": "Llamar al cliente", "due_date": "2026-07-30",
                      "priority": "alta", "matter_id": "m1"}]
    },
    "procesos": [
      {"id": "m1", "name": "Restrepo vs. Seguros", "code": "JUR-2607-A31X",
       "progress": 40, "radicado": "05001400301020240078900", "autopilot_on": true,
       "deadline_at": "2026-07-31T00:00:00Z", "daysLeft": 2, "score": 120}
    ],
    "legal_intel": {"area": "civil", "items": [
      {"tipo": "consulta", "titulo": "Prescripción de la acción cambiaria",
       "resumen": "Vuelve a discutirse el conteo del término",
       "ask_query": "¿Desde cuándo corre la prescripción de la acción cambiaria?"}
    ], "tip": {"titulo": "Revisa la caducidad antes de radicar",
               "resumen": "Un día tarde y no hay demanda que valga",
               "ask_query": "¿Cómo calculo la caducidad en un medio de control?"}},
    "area": "civil",
    "gate": "rich"
  }''';

  Briefing leer() =>
      Briefing.fromJson(jsonDecode(crudo) as Map<String, dynamic>);

  group('Escudo', () {
    test('lee dias_sin_vencer / vigilados / perdidos', () {
      final Escudo e = leer().escudo;
      expect(e.diasSinVencer, 43);
      expect(e.vigilados, 7);
      expect(e.perdidos, 0);
      expect(e.aspiracional, isFalse);
    });

    test('sin procesos vigilados el bloque cambia de tono', () {
      const Escudo e = Escudo();
      expect(
        e.aspiracional,
        isTrue,
        reason: 'Tres ceros en fila se leen como reproche, no como estado',
      );
    });
  });

  test('overnight cuelga de `overnight.movimientos`', () {
    final List<Movimiento> ms = leer().movimientos;
    expect(ms, hasLength(1));
    expect(ms.single.nombre, 'Restrepo vs. Seguros');
    expect(ms.single.resumen, contains('admite'));
    expect(ms.single.matterId, 'm1');
  });

  group('atencion', () {
    test('los términos usan `matter_id` (aquí NO es expId)', () {
      final TerminoBriefing t = leer().atencion.terminos.single;
      expect(t.matterId, 'm1');
      expect(t.diasRestantes, 2);
      expect(t.critico, isTrue);
      expect(t.etiqueta, 'T−2');
    });

    test('un término deducido se marca tentativo', () {
      expect(leer().atencion.terminos.single.tentativo, isTrue);
    });

    test('borradores y pendientes se separan', () {
      final Atencion a = leer().atencion;
      expect(a.borradores.single.titulo, 'Contestación lista');
      expect(a.pendientes.single.prioridad, 'alta');
      expect(a.total, 3);
      expect(a.vacia, isFalse);
    });
  });

  group('procesos', () {
    test('`name` ya viene resuelto por el servidor', () {
      expect(leer().procesos.single.nombre, 'Restrepo vs. Seguros');
    });

    test('vigilar sigue exigiendo radicado, igual que en la lista', () {
      expect(leer().procesos.single.vigilanciaVerificable, isTrue);

      final ProcesoPrioritario sinRad = ProcesoPrioritario.fromJson(
        <String, dynamic>{'id': 'x', 'name': 'X', 'autopilot_on': true},
      );
      expect(sinRad.vigilanciaVerificable, isFalse);
    });

    test('la etiqueta de término distingue hoy, vencido y futuro', () {
      ProcesoPrioritario con(int d) => ProcesoPrioritario.fromJson(
        <String, dynamic>{'id': 'x', 'name': 'X', 'daysLeft': d},
      );
      expect(con(0).etiquetaTermino, 'Hoy');
      expect(con(-1).etiquetaTermino, 'Vencido');
      expect(con(5).etiquetaTermino, 'T−5');
    });
  });

  group('legal_intel', () {
    test('cada tema trae su consulta lista para el chat', () {
      final InteligenciaDelDia intel = leer().inteligencia!;
      expect(intel.area, 'civil');
      expect(intel.temas.single.askQuery, startsWith('¿Desde cuándo'));
      expect(intel.tip, isNotNull);
    });

    test('un tema sin ask_query se descarta: no sería accionable', () {
      final InteligenciaDelDia? intel = InteligenciaDelDia.desde(
        <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{'titulo': 'Algo', 'ask_query': ''},
          ],
        },
      );
      expect(intel, isNull);
    });

    test('legal_intel null (flag apagado) no rompe nada', () {
      final Briefing b = Briefing.fromJson(<String, dynamic>{
        'gate': 'quiet',
        'legal_intel': null,
      });
      expect(b.inteligencia, isNull);
      expect(b.compuerta, Compuerta.tranquila);
    });
  });

  group('gate', () {
    test('mapea los tres valores del servidor', () {
      expect(Compuerta.desde('rich'), Compuerta.rica);
      expect(Compuerta.desde('quiet'), Compuerta.tranquila);
      expect(Compuerta.desde('activation'), Compuerta.activacion);
    });

    test('un valor desconocido cae en activación, nunca revienta', () {
      expect(Compuerta.desde('otra_cosa'), Compuerta.activacion);
      expect(Compuerta.desde(null), Compuerta.activacion);
    });
  });

  test('una respuesta vacía del servidor no rompe el Inicio', () {
    final Briefing b = Briefing.fromJson(<String, dynamic>{});
    expect(b.procesos, isEmpty);
    expect(b.atencion.vacia, isTrue);
    expect(b.escudo.aspiracional, isTrue);
    expect(b.compuerta, Compuerta.activacion);
  });
}
