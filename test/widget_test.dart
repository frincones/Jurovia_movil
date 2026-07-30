import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/core/config/app_config.dart';
import 'package:jurovia/core/theme/app_theme.dart';
import 'package:jurovia/core/theme/colors.dart';
import 'package:jurovia/shared/models/me.dart';
import 'package:jurovia/shared/widgets/aurora_button.dart';
import 'package:jurovia/shared/widgets/jurovia_logo.dart';
import 'package:jurovia/shared/widgets/verified_chip.dart';

Widget _envuelve(Widget hijo) => MaterialApp(
  theme: JvTheme.claro,
  home: Scaffold(body: Center(child: hijo)),
);

void main() {
  group('componentes de marca', () {
    testWidgets('el logotipo muestra la palabra completa', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(_envuelve(const JuroviaLogo()));
      // El logo es un RichText con "Jurov" + un WidgetSpan con "·ia"
      // degradado, así que `find.text` no lo alcanza de una pieza.
      final RichText rico = t.widget<RichText>(find.byType(RichText).first);
      expect(rico.text.toPlainText(), contains('Jurov'));
      expect(find.text('·ia'), findsOneWidget);
    });

    testWidgets('la marca se dibuja con el gradiente aurora', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(_envuelve(const JuroviaMark()));
      final Container c = t.widget<Container>(find.byType(Container).first);
      final BoxDecoration d = c.decoration! as BoxDecoration;
      expect(d.gradient, JvColors.aurora);
    });

    testWidgets('la marca no se estira dentro de un ListView', (
      WidgetTester t,
    ) async {
      // Regresión: dentro de un ListView los hijos reciben restricciones de
      // ancho ajustadas, así que un Container con `width` se estiraba a todo el
      // ancho y el logotipo salía deformado. Debe medir 52×52 siempre.
      await t.pumpWidget(
        MaterialApp(
          theme: JvTheme.claro,
          home: Scaffold(
            body: ListView(children: const <Widget>[JuroviaMark(tamano: 52)]),
          ),
        ),
      );
      final Size medida = t.getSize(
        find.descendant(
          of: find.byType(JuroviaMark),
          matching: find.byType(Container),
        ),
      );
      expect(medida.width, 52);
      expect(medida.height, 52);
    });

    testWidgets('el CTA principal dispara su acción', (WidgetTester t) async {
      int pulsaciones = 0;
      await t.pumpWidget(
        _envuelve(
          AuroraButton(texto: 'Continuar', onPressed: () => pulsaciones++),
        ),
      );
      await t.tap(find.text('Continuar'));
      expect(pulsaciones, 1);
    });

    testWidgets('el CTA deshabilitado no dispara', (WidgetTester t) async {
      await t.pumpWidget(
        _envuelve(const AuroraButton(texto: 'Continuar', onPressed: null)),
      );
      await t.tap(find.text('Continuar'));
      // No hay callback: basta con que no reviente.
      expect(find.text('Continuar'), findsOneWidget);
    });

    testWidgets('el chip de verificado usa el dorado', (WidgetTester t) async {
      await t.pumpWidget(_envuelve(const VerifiedChip()));
      expect(find.text('Fuente verificada'), findsOneWidget);
      final Text texto = t.widget<Text>(find.text('Fuente verificada'));
      expect(texto.style!.color, JvColors.verificadoTxt);
    });
  });

  group('modelo Me', () {
    test('deserializa el contrato real de /api/me', () {
      final Me m = Me.fromJson(<String, dynamic>{
        'user_id': 'u1',
        'email': 'camila@restrepolegal.co',
        'org_id': 'o1',
        'plan': 'pro',
        'onboarded': true,
        'entitlements': <String, dynamic>{'chat': true},
        'access': <String, dynamic>{'model': 'credits', 'balance': 180},
      });
      expect(m.userId, 'u1');
      expect(m.plan, 'pro');
      expect(m.esPago, isTrue);
      expect(m.access.balance, 180);
    });

    test('un JSON incompleto no revienta', () {
      final Me m = Me.fromJson(<String, dynamic>{});
      expect(m.plan, 'free');
      expect(m.esPago, isFalse);
      expect(m.access.model, 'credits');
    });

    test('la cuota se pinta según access.model, no asumiendo créditos', () {
      const Access creditos = Access(model: 'credits', balance: 180);
      expect(creditos.resumen, contains('crédito'));

      const Access diario = Access(
        model: 'trial_daily',
        turnsLeft: 2,
        turnsPerDay: 3,
      );
      expect(diario.esTrialDiario, isTrue);
      expect(diario.resumen, '2 de 3 turnos hoy');
    });

    test('el nombre corto sale del correo mientras no haya perfil', () {
      final Me m = Me.prueba(email: 'camila.restrepo@estudio.co');
      expect(m.nombreCorto, 'Camila');
    });
  });

  group('AppConfig', () {
    test('apunta al backend de Railway y a Supabase', () {
      expect(AppConfig.backendUrl, contains('railway.app'));
      expect(AppConfig.supabaseUrl, contains('supabase.co'));
    });

    test('el deep link coincide con el registrado en las plataformas', () {
      // Debe cuadrar con CFBundleURLSchemes (Info.plist), el intent-filter del
      // AndroidManifest y la uri_allow_list de Supabase.
      expect(AppConfig.authRedirectUrl, startsWith('jurovia://'));
    });

    test('detecta la configuración faltante', () {
      // Sin --dart-define la anon key va vacía y la app lo dice en pantalla.
      if (AppConfig.supabaseAnonKey.isEmpty) {
        expect(AppConfig.faltantes(), contains('SUPABASE_ANON_KEY'));
        expect(AppConfig.configurado, isFalse);
      } else {
        expect(AppConfig.configurado, isTrue);
      }
    });
  });
}
