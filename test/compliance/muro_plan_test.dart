import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/compliance/billing/billing_policy.dart';
import 'package:jurovia/compliance/billing/muro_plan.dart';
import 'package:jurovia/core/theme/app_theme.dart';
import 'package:jurovia/shared/models/me.dart';

/// El muro de plan explica **que** la facturación se gestiona fuera, y nunca
/// **dónde**. Esa es la línea entre lo que Apple permite (3.1.3(b),
/// *Multiplatform Services*) y lo que rechaza (3.1.3, *steering*).
///
/// Estas pruebas la vigilan: si alguien añade una URL, un precio o un
/// «suscríbete» al texto, falla aquí y no en la revisión tres semanas después.
void main() {
  /// Lo que no puede aparecer nunca en el muro.
  const List<String> prohibido = <String>[
    'http',
    'www.',
    '.com',
    'juroviapp',
    'suscríbete',
    'suscribete',
    'mejora tu plan',
    'mejorar plan',
    'actualiza tu plan',
    'comprar',
    'compra ahora',
    'precio',
    'usd',
    r'$',
    'tarjeta',
    'paddle',
    'app store',
    'google play',
  ];

  Widget envolver(Widget hijo) => MaterialApp(
    theme: JvTheme.claro,
    home: Scaffold(body: hijo),
  );

  group('El texto no hace steering', () {
    test('ninguna explicación nombra dónde pagar', () {
      for (final String t in <String>[
        TextosMuro.explicacionConSuscripcion,
        TextosMuro.explicacionSinSuscripcion,
      ]) {
        final String bajo = t.toLowerCase();
        for (final String mal in prohibido) {
          expect(
            bajo.contains(mal),
            isFalse,
            reason: 'El muro no puede contener «$mal»: sería steering. → $t',
          );
        }
      }
    });

    test('ningún título invita a comprar', () {
      for (final MotivoMuro m in MotivoMuro.values) {
        final String bajo = TextosMuro.titulo(m).toLowerCase();
        for (final String mal in prohibido) {
          expect(bajo.contains(mal), isFalse, reason: '$m dice «$mal»');
        }
      }
    });

    test('el texto de pago calca el patrón: dice qué, no dónde', () {
      final String t = TextosMuro.explicacionConSuscripcion.toLowerCase();
      expect(t, contains('no se puede cancelar ni modificar desde esta app'));
      expect(t, contains('otra plataforma'));
      expect(
        t,
        contains('inicia sesión en la cuenta'),
        reason: 'Remite a «tu cuenta», sin decir en qué sitio está',
      );
    });
  });

  group('De dónde sale la suscripción', () {
    test('sin usuario no hay suscripción', () {
      expect(BillingPolicy.fuente(null), FuenteSuscripcion.ninguna);
    });

    test('Free y prueba no tienen suscripción que gestionar', () {
      for (final String plan in <String>['free', 'trial']) {
        expect(
          BillingPolicy.fuente(Me.prueba(plan: plan)),
          FuenteSuscripcion.ninguna,
          reason: 'Decirle «tu suscripción» a un $plan sería falso',
        );
      }
    });

    test('un plan de pago se contrató fuera: solo hay un carril (Paddle)', () {
      expect(
        BillingPolicy.fuente(Me.prueba(plan: 'pro')),
        FuenteSuscripcion.otraPlataforma,
      );
    });

    test('el motivo por defecto cambia según quién pague', () {
      expect(
        BillingPolicy.motivoPara(Me.prueba(plan: 'pro')),
        MotivoMuro.gestionar,
      );
      expect(
        BillingPolicy.motivoPara(Me.prueba(plan: 'free')),
        MotivoMuro.cambiarPlan,
      );
    });
  });

  group('Entitlements: fail-open como el backend', () {
    test('una clave ausente NO bloquea', () {
      expect(
        MuroPlan.habilitado(Me.prueba(), 'vigilancia'),
        isTrue,
        reason:
            'plans.has_entitlement() la trata como permitida; exigir '
            '== true quitaría acceso que el servidor sí da',
      );
    });

    test('solo un false explícito niega', () {
      const Me m = Me(
        plan: 'free',
        entitlements: <String, dynamic>{'vigilancia': false, 'chat': true},
      );
      expect(MuroPlan.habilitado(m, 'vigilancia'), isFalse);
      expect(MuroPlan.habilitado(m, 'chat'), isTrue);
    });

    test('un límite numérico habilita (no es false)', () {
      const Me m = Me(entitlements: <String, dynamic>{'docs': 50});
      expect(MuroPlan.habilitado(m, 'docs'), isTrue);
    });
  });

  group('El diálogo', () {
    testWidgets('a quien paga le habla de su suscripción', (
      WidgetTester t,
    ) async {
      late BuildContext ctx;
      await t.pumpWidget(
        envolver(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      MuroPlan.mostrar(
        ctx,
        motivo: MotivoMuro.gestionar,
        me: Me.prueba(plan: 'pro'),
      );
      await t.pumpAndSettle();

      expect(find.text('Gestionar tu suscripción'), findsOneWidget);
      expect(find.textContaining('otra plataforma'), findsOneWidget);
      expect(find.text(TextosMuro.botonCerrar), findsOneWidget);
    });

    testWidgets('no hay ningún botón que lleve a comprar', (
      WidgetTester t,
    ) async {
      late BuildContext ctx;
      await t.pumpWidget(
        envolver(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      MuroPlan.mostrar(
        ctx,
        motivo: MotivoMuro.cambiarPlan,
        me: Me.prueba(plan: 'free'),
      );
      await t.pumpAndSettle();

      // Un solo botón, y cierra.
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text(TextosMuro.botonCerrar), findsOneWidget);
    });

    testWidgets('sin cuota, el mensaje del servidor va PRIMERO', (
      WidgetTester t,
    ) async {
      late BuildContext ctx;
      await t.pumpWidget(
        envolver(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      MuroPlan.mostrar(
        ctx,
        motivo: MotivoMuro.sinCuota,
        me: Me.prueba(plan: 'free'),
        detalle: 'Se te acabaron los turnos de hoy.',
      );
      await t.pumpAndSettle();

      final double yDetalle = t
          .getTopLeft(find.text('Se te acabaron los turnos de hoy.'))
          .dy;
      final double yExplicacion = t
          .getTopLeft(find.text(TextosMuro.explicacionSinSuscripcion))
          .dy;
      expect(
        yDetalle,
        lessThan(yExplicacion),
        reason: 'Lo urgente antes del modelo de negocio',
      );
    });

    testWidgets('la fila de Perfil cambia de nombre según el plan', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(
        envolver(FilaGestionarPlan(me: Me.prueba(plan: 'pro'))),
      );
      expect(find.text('Gestionar suscripción'), findsOneWidget);

      await t.pumpWidget(
        envolver(FilaGestionarPlan(me: Me.prueba(plan: 'free'))),
      );
      expect(find.text('Tu plan'), findsOneWidget);
    });

    testWidgets('tocar la fila abre la explicación', (WidgetTester t) async {
      await t.pumpWidget(
        envolver(FilaGestionarPlan(me: Me.prueba(plan: 'pro'))),
      );
      await t.tap(find.text('Gestionar suscripción'));
      await t.pumpAndSettle();
      expect(find.textContaining('no se puede cancelar'), findsOneWidget);
    });
  });
}
