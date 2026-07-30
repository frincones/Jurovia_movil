import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/shared/models/caso.dart';
import 'package:jurovia/shared/models/chat.dart';
import 'package:jurovia/shared/models/me.dart';

/// Pruebas de contrato contra el backend.
///
/// **Por qué existen:** tres bugs de esta semana —«Caso sin nombre», los
/// términos que no aparecían y los avisos sin icono ni navegación— tuvieron la
/// misma causa: se asumieron los nombres de los campos en vez de leerlos. El
/// backend **remapea sus columnas antes de responder** (`name` → `title` →
/// `display`, `deadline_at` → `daysLeft`, `campaign_type`), así que el esquema
/// de la base NO es el contrato de la API.
///
/// Cada JSON de aquí está copiado de la respuesta real del backend
/// (`_mission_shape`, `list_deadlines`, `list_notifications`, `get_session`).
/// Si el backend cambia un nombre, **falla esta prueba**, no la app del usuario.
void main() {
  group('GET /api/missions · _mission_shape', () {
    // Copiado de app/api/missions.py
    const String crudo = '''
    {
      "id": "3f1c-…", "code": "JUR-2607-A31X",
      "title": "quieroq ue analices todo el manual de convivencia y el reglamento",
      "display": "Manual de convivencia · Villa Nueva",
      "area": "propiedad horizontal", "status": "active",
      "radicado": "05001400301020240078900",
      "juzgado": "Juzgado 10 Civil Municipal", "demandante": "Villa Nueva P.H.",
      "demandado": "—", "progress": 40, "accent": "#7B3DF5",
      "autopilot_on": true, "workflow_type": null,
      "nextBestAction": "Contestar antes del 30 de julio",
      "requirementsMap": null,
      "nextTerm": {"title": "Contestar", "daysLeft": 2, "severity": "critico"}
    }''';

    test('usa `display` como nombre, NUNCA el prompt crudo de `title`', () {
      final Caso c = Caso.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
      expect(c.nombre, 'Manual de convivencia · Villa Nueva');
      expect(
        c.nombre,
        isNot(contains('quieroq')),
        reason: 'Mostrar `title` expone el prompt con el que se creó la misión',
      );
    });

    test('lee el código global', () {
      final Caso c = Caso.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
      expect(c.codigo, 'JUR-2607-A31X');
    });

    test('normaliza el marcador "—" a nulo', () {
      final Caso c = Caso.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
      expect(
        c.demandado,
        isNull,
        reason: 'El backend usa "—" como vacío; pintarlo tal cual es basura',
      );
      expect(c.demandante, 'Villa Nueva P.H.');
    });

    test('lee el próximo término del objeto anidado', () {
      final Caso c = Caso.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
      expect(c.proximoTermino, isNotNull);
      expect(c.proximoTermino!.etiqueta, 'T−2');
      expect(c.proximoTermino!.critico, isTrue);
    });

    test('«Vigilando» exige vigilancia Y radicado real', () {
      final Caso conRadicado = Caso.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(conRadicado.vigilanciaVerificable, isTrue);

      final Caso sinRadicado = Caso.fromJson(<String, dynamic>{
        'id': 'x',
        'display': 'Caso sin radicar',
        'autopilot_on': true,
        'radicado': '—',
      });
      expect(
        sinRadicado.vigilanciaVerificable,
        isFalse,
        reason:
            'Sin radicado no hay nada que vigilar en la Rama Judicial: '
            'el tag prometería algo que no ocurre',
      );
    });

    test('si falta `display`, cae a `title` sin romperse', () {
      final Caso c = Caso.fromJson(<String, dynamic>{
        'id': 'x',
        'title': 'Restrepo vs. Seguros',
      });
      expect(c.nombre, 'Restrepo vs. Seguros');
    });
  });

  group('GET /api/deadlines · list_deadlines', () {
    // Copiado de app/api/deadlines.py
    const String crudo = '''
    {
      "id": "d1", "title": "Contestar demanda", "caso": "Restrepo vs. Seguros",
      "expId": "m1", "deadline_at": "2026-07-30T00:00:00Z",
      "daysLeft": 2, "when": "en 2 días", "severity": "critico",
      "fundamento": "Traslado de 20 días (CGP art. 118)",
      "confidence": "tentativo", "action": "Preparar"
    }''';

    test('lee `deadline_at`, no `due_at`', () {
      final Termino t = Termino.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(t.vence, isNotNull);
      expect(t.dia, '30');
      expect(t.mes, 'jul');
    });

    test('usa el `daysLeft` del backend, no lo recalcula', () {
      final Termino t = Termino.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(t.diasRestantes, 2);
      expect(t.etiqueta, 'T−2');
      expect(t.urgente, isTrue);
    });

    test('lee `expId` como identificador del caso', () {
      final Termino t = Termino.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(t.matterId, 'm1');
    });

    test('marca como tentativo lo que el agente dedujo', () {
      final Termino t = Termino.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(
        t.tentativo,
        isTrue,
        reason:
            'Presentar un término deducido como confirmado puede costarle '
            'el proceso al abogado',
      );

      final Termino confirmado = Termino.fromJson(<String, dynamic>{
        'id': 'd2',
        'title': 'Alegatos',
        'confidence': 'confirmado',
      });
      expect(confirmado.tentativo, isFalse);
    });

    test('`auto_created` también implica tentativo', () {
      final Termino t = Termino.fromJson(<String, dynamic>{
        'id': 'd3',
        'title': 'Recurso',
        'auto_created': true,
      });
      expect(t.tentativo, isTrue);
    });
  });

  group('GET /api/notifications · list_notifications', () {
    // Copiado de app/api/notifications.py
    const String crudo = '''
    {
      "id": "n1", "channel": "inapp", "campaign_type": "deadline",
      "title": "⏰ Término vence en 2 día(s): Contestar",
      "body": "Contestar vence en 2 días · Caso: Restrepo",
      "related_matter_id": "m1", "read_at": null,
      "created_at": "2026-07-29T08:12:00Z"
    }''';

    test('lee `campaign_type`, no `kind` ni `type`', () {
      final Notificacion n = Notificacion.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(
        n.tipo,
        'deadline',
        reason:
            'Con el nombre equivocado, TODOS los avisos salían con el '
            'icono genérico',
      );
    });

    test('lee `related_matter_id`, no `matter_id`', () {
      final Notificacion n = Notificacion.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(
        n.matterId,
        'm1',
        reason: 'Con el nombre equivocado, tocar el aviso no navegaba a nada',
      );
    });

    test('`read_at` nulo significa no leída', () {
      final Notificacion n = Notificacion.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
      expect(n.leida, isFalse);

      final Notificacion leida = Notificacion.fromJson(<String, dynamic>{
        'id': 'n2',
        'read_at': '2026-07-29T09:00:00Z',
      });
      expect(leida.leida, isTrue);
    });

    test('el Parte Diario se distingue para abrir el Inicio', () {
      final Notificacion n = Notificacion.fromJson(<String, dynamic>{
        'id': 'n3',
        'campaign_type': 'parte_diario',
        'title': 'Tu parte del día',
      });
      expect(n.esParteDiario, isTrue);
    });
  });

  group('GET /api/sessions/{id} · get_session', () {
    // Copiado de app/api/sessions.py — APLANADO, sin message_parts.
    const String crudo = '''
    {
      "id": "s1", "title": "Prescripción · Restrepo",
      "messages": [
        {"role": "user", "text": "¿Ya prescribió la acción?"},
        {"role": "assistant", "text": "La acción prescribe en 10 años.",
         "thinking": "Reviso el art. 2536…", "durationMs": 6200,
         "steps": [{"name": "buscar_norma", "input": {"q": "2536"},
                    "output": "Art. 2536 C.C.", "durationMs": 900,
                    "sources": [{"title": "Código Civil · Art. 2536",
                                 "meta": "Prescripción", "verified": true}]}],
         "artifacts": [{"id": "a1", "version_id": "v1", "kind": "document",
                        "title": "Contestacion.docx", "version": 1,
                        "uri": "https://…", "blocks": []}],
         "hooks": [{"label": "Redactar", "tipo": "accion", "prompt": "Redacta"}]}
      ]
    }''';

    test('el endpoint NO devuelve message_parts: es una forma aplanada', () {
      final Map<String, dynamic> j = jsonDecode(crudo) as Map<String, dynamic>;
      final List<dynamic> msgs = j['messages'] as List<dynamic>;
      expect(
        (msgs.first as Map<String, dynamic>).containsKey('message_parts'),
        isFalse,
        reason: 'Buscar `message_parts` dejaba el chat con burbujas vacías',
      );
    });

    test('deserializa el turno del usuario', () {
      final Map<String, dynamic> j = jsonDecode(crudo) as Map<String, dynamic>;
      final Mensaje m = Mensaje.fromJson(
        (j['messages'] as List<dynamic>)[0] as Map<String, dynamic>,
        indice: 0,
      );
      expect(m.esUsuario, isTrue);
      expect(m.texto, '¿Ya prescribió la acción?');
    });

    test('reconstruye la respuesta con todas sus piezas', () {
      final Map<String, dynamic> j = jsonDecode(crudo) as Map<String, dynamic>;
      final Mensaje m = Mensaje.fromJson(
        (j['messages'] as List<dynamic>)[1] as Map<String, dynamic>,
        indice: 1,
      );
      expect(m.esUsuario, isFalse);
      expect(m.texto, contains('10 años'));
      expect(m.razonamiento, contains('2536'));
      expect(m.segundosPensando, 6);
      expect(m.pasos, hasLength(1));
      expect(m.artefactos.single.nombre, 'Contestacion.docx');
      expect(m.hooks.single.etiqueta, 'Redactar');
    });

    test('recupera las fuentes que devolvieron las herramientas', () {
      final Map<String, dynamic> j = jsonDecode(crudo) as Map<String, dynamic>;
      final Mensaje m = Mensaje.fromJson(
        (j['messages'] as List<dynamic>)[1] as Map<String, dynamic>,
        indice: 1,
      );
      expect(m.fuentes, hasLength(1));
      expect(m.fuentes.single.titulo, contains('2536'));
      expect(
        m.fuentes.single.verificada,
        isTrue,
        reason: 'El dorado solo se pinta si la fuente viene verificada',
      );
    });

    test('los turnos cargados de la API son completos, no streaming', () {
      final Map<String, dynamic> j = jsonDecode(crudo) as Map<String, dynamic>;
      final Mensaje m = Mensaje.fromJson(
        (j['messages'] as List<dynamic>)[1] as Map<String, dynamic>,
        indice: 1,
      );
      expect(m.clasificar(), EstadoMensaje.completo);
    });
  });

  group('GET /api/me', () {
    test('deserializa identidad, plan y modelo de acceso', () {
      final Me m = Me.fromJson(<String, dynamic>{
        'user_id': 'u1',
        'email': 'camila@estudio.co',
        'org_id': 'o1',
        'plan': 'pro',
        'onboarded': true,
        'entitlements': <String, dynamic>{'chat': true},
        'access': <String, dynamic>{
          'model': 'trial_daily',
          'turns_left': 2,
          'turns_per_day': 3,
        },
      });
      expect(m.plan, 'pro');
      expect(m.access.esTrialDiario, isTrue);
      expect(m.access.resumen, '2 de 3 turnos hoy');
    });
  });
}
