import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/core/theme/app_theme.dart';
import 'package:jurovia/shared/models/caso.dart';
import 'package:jurovia/shared/widgets/fila_termino.dart';

/// E2 · Lo que la lista y el detalle de casos deben decir (y no decir).
void main() {
  Widget envolver(Widget hijo) => MaterialApp(
    theme: JvTheme.claro,
    home: Scaffold(body: SingleChildScrollView(child: hijo)),
  );

  group('Honestidad del tag de vigilancia', () {
    test('encendida CON radicado → verificable', () {
      final Caso c = Caso.fromJson(<String, dynamic>{
        'id': 'x',
        'display': 'Caso',
        'autopilot_on': true,
        'radicado': '05001400301020240078900',
      });
      expect(c.vigilanciaVerificable, isTrue);
    });

    test('encendida SIN radicado → NO verificable', () {
      final Caso c = Caso.fromJson(<String, dynamic>{
        'id': 'x',
        'display': 'Caso',
        'autopilot_on': true,
      });
      expect(c.vigilanciaActiva, isTrue);
      expect(
        c.vigilanciaVerificable,
        isFalse,
        reason: 'Sería prometer avisos que nunca van a llegar',
      );
    });

    test('apagada con radicado → NO verificable', () {
      final Caso c = Caso.fromJson(<String, dynamic>{
        'id': 'x',
        'display': 'Caso',
        'autopilot_on': false,
        'radicado': '0500140030102024007890',
      });
      expect(c.vigilanciaVerificable, isFalse);
    });
  });

  testWidgets('un término tentativo pide confirmar la fecha', (
    WidgetTester t,
  ) async {
    final Termino term = Termino.fromJson(<String, dynamic>{
      'id': 'd1',
      'title': 'Contestar demanda',
      'deadline_at': '2026-08-05T00:00:00Z',
      'daysLeft': 7,
      'caso': 'Restrepo vs. Seguros',
      'confidence': 'tentativo',
      'fundamento': 'Traslado de 20 días (CGP art. 118)',
    });

    await t.pumpWidget(envolver(FilaTermino(termino: term)));

    expect(find.text('Contestar demanda'), findsOneWidget);
    expect(find.textContaining('confírmala'), findsOneWidget);
  });

  testWidgets('un término confirmado NO lleva el aviso', (
    WidgetTester t,
  ) async {
    final Termino term = Termino.fromJson(<String, dynamic>{
      'id': 'd2',
      'title': 'Alegatos de conclusión',
      'deadline_at': '2026-08-05T00:00:00Z',
      'daysLeft': 7,
      'confidence': 'confirmado',
    });

    await t.pumpWidget(envolver(FilaTermino(termino: term)));

    expect(find.text('Alegatos de conclusión'), findsOneWidget);
    expect(find.textContaining('confírmala'), findsNothing);
  });
}
