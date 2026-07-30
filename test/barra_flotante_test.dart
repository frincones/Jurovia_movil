import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jurovia/core/data_providers.dart';
import 'package:jurovia/core/router/app_router.dart';
import 'package:jurovia/core/theme/app_theme.dart';
import 'package:jurovia/core/theme/colors.dart';
import 'package:jurovia/shared/widgets/app_shell.dart';

/// Barra de navegación flotante (estilo Instagram, variante A).
///
/// Lo que vigilan estas pruebas es lo que se rompe en silencio: que el
/// contenido siga pasando **por debajo** del cristal, que el último elemento de
/// una lista quede por encima de la pastilla, y que sin etiquetas visibles cada
/// destino conserve su nombre para el lector de pantalla.
void main() {
  /// Monta el shell con un router de verdad: `context.go` necesita uno, y sin
  /// él la barra no se puede tocar.
  Widget montar({
    String ruta = Rutas.inicio,
    int noLeidas = 0,
    Widget? cuerpo,
    ThemeData? tema,
    double insetInferior = 0,
  }) {
    final GoRouter router = GoRouter(
      initialLocation: ruta,
      routes: <RouteBase>[
        ShellRoute(
          builder: (_, GoRouterState estado, Widget hijo) =>
              AppShell(rutaActual: estado.matchedLocation, child: hijo),
          routes: <RouteBase>[
            for (final String r in <String>[
              Rutas.inicio,
              Rutas.casos,
              Rutas.bandeja,
              Rutas.perfil,
            ])
              GoRoute(
                path: r,
                builder: (_, _) =>
                    cuerpo ?? Scaffold(body: Center(child: Text('ruta $r'))),
              ),
          ],
        ),
        GoRoute(path: Rutas.chat, builder: (_, _) => const Text('CHAT')),
      ],
    );

    return ProviderScope(
      overrides: <Override>[
        noLeidasProvider.overrideWith((Ref ref) async => noLeidas),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(bottom: insetInferior),
          viewPadding: EdgeInsets.only(bottom: insetInferior),
        ),
        child: MaterialApp.router(
          theme: tema ?? JvTheme.claro,
          routerConfig: router,
        ),
      ),
    );
  }

  group('Estructura: por qué no es un bottomNavigationBar', () {
    testWidgets('el cuerpo NO se recorta a la altura de la barra', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();

      // Con `bottomNavigationBar` el Scaffold recortaría el cuerpo y el
      // desenfoque no tendría nada que desenfocar. Con el Stack, el cuerpo
      // ocupa toda la pantalla y la lista sigue por debajo del cristal.
      final Scaffold shell = t.widget<Scaffold>(
        find
            .descendant(
              of: find.byType(AppShell),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      expect(shell.bottomNavigationBar, isNull);
      expect(shell.floatingActionButton, isNull);
    });

    testWidgets('la pastilla desenfoca lo que tiene detrás', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();

      final BackdropFilter filtro = t.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(
        filtro.filter,
        isA<ImageFilter>(),
        reason: 'Sin desenfoque la translucidez no aporta nada',
      );
    });

    testWidgets('mide 58 px y respeta los márgenes laterales', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();

      final Size medida = t.getSize(find.byType(BackdropFilter));
      expect(medida.height, BarraFlotante.alto);

      final double ancho = t.view.physicalSize.width / t.view.devicePixelRatio;
      expect(
        medida.width,
        moreOrLessEquals(ancho - BarraFlotante.margenLateral * 2, epsilon: 1),
        reason: 'Flota: no ocupa el ancho completo',
      );
    });
  });

  group('El espacio que debe dejar el contenido', () {
    test('sale de las medidas reales, no de un 100 a mano', () {
      // Antes cada pantalla escribía `100` y nadie sabía de dónde salía.
      const double esperado = BarraFlotante.alto + BarraFlotante.margenInferior;
      expect(esperado, 72);
    });

    testWidgets('crece con la barra de gestos de Android', (
      WidgetTester t,
    ) async {
      late double sinInset;
      late double conInset;

      Widget sonda(void Function(double) capturar) => MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (BuildContext c) {
            capturar(BarraFlotante.espacioContenido(c));
            return const SizedBox.shrink();
          },
        ),
      );

      await t.pumpWidget(sonda((double v) => sinInset = v));
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 34)),
          child: Builder(
            builder: (BuildContext c) {
              conInset = BarraFlotante.espacioContenido(c);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        conInset - sinInset,
        34,
        reason:
            'Con navegación por gestos la pastilla se sube, y el contenido '
            'tiene que reservar ese espacio o el último elemento queda debajo',
      );
    });

    testWidgets('el último elemento de una lista queda por encima', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(
        montar(
          insetInferior: 34,
          cuerpo: Scaffold(
            body: Builder(
              builder: (BuildContext c) => ListView(
                padding: EdgeInsets.only(
                  bottom: BarraFlotante.espacioContenido(c),
                ),
                children: <Widget>[
                  for (int i = 0; i < 24; i++)
                    SizedBox(height: 60, child: Text('fila $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      // Al final de la lista, la última fila tiene que verse por encima del
      // cristal: visible pero tapada es peor que no estar.
      await t.drag(find.byType(ListView), const Offset(0, -2000));
      await t.pumpAndSettle();

      final double abajoUltima = t.getBottomLeft(find.text('fila 23')).dy;
      final double arribaBarra = t.getTopLeft(find.byType(BackdropFilter)).dy;
      expect(
        abajoUltima,
        lessThanOrEqualTo(arribaBarra),
        reason: 'La última fila se queda debajo de la pastilla',
      );
    });
  });

  group('Destinos', () {
    testWidgets('cuatro destinos y el chat, sin etiquetas visibles', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();

      // Las etiquetas desaparecieron de la barra.
      for (final String etiqueta in <String>[
        'Inicio',
        'Casos',
        'Bandeja',
        'Perfil',
      ]) {
        expect(
          find.text(etiqueta),
          findsNothing,
          reason: '«$etiqueta» ya no se pinta: la barra es solo iconos',
        );
      }

      // …pero siguen existiendo para el lector de pantalla.
      final SemanticsHandle s = t.ensureSemantics();
      for (final String etiqueta in <String>[
        'Inicio',
        'Casos',
        'Bandeja',
        'Perfil',
      ]) {
        expect(
          find.bySemanticsLabel(etiqueta),
          findsOneWidget,
          reason: 'Sin texto visible, el Semantics es lo único que lo nombra',
        );
      }
      expect(
        find.bySemanticsLabel('Nueva conversación con Jurovia'),
        findsOneWidget,
      );
      s.dispose();
    });

    testWidgets('el chat sigue viviendo en el centro, con su gradiente', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();

      // El avatar de Perfil también es un círculo aurora, así que se busca por
      // el icono que solo tiene el botón del chat.
      final Finder chat = find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byWidgetPredicate((Widget w) {
          if (w is! Container) return false;
          final Decoration? d = w.decoration;
          return d is BoxDecoration &&
              d.gradient == JvColors.aurora &&
              d.shape == BoxShape.circle;
        }),
      );
      expect(chat, findsOneWidget);
      expect(t.getSize(chat).width, BarraFlotante.chat);
    });

    testWidgets('tocar el chat abre la conversación', (WidgetTester t) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();

      await t.tap(find.byIcon(Icons.add));
      await t.pumpAndSettle();
      expect(find.text('CHAT'), findsOneWidget);
    });

    testWidgets('navega entre destinos', (WidgetTester t) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();
      expect(find.text('ruta ${Rutas.inicio}'), findsOneWidget);

      await t.tap(find.byIcon(Icons.folder_outlined));
      await t.pumpAndSettle();
      expect(find.text('ruta ${Rutas.casos}'), findsOneWidget);
    });
  });

  group('Estado activo', () {
    testWidgets('el icono se rellena, no solo cambia de color', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();

      // Inicio activo → relleno. El resto en contorno. Dos señales, para que
      // el estado no dependa solo del color.
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('la pastilla se pinta detrás del destino activo', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(montar(ruta: Rutas.bandeja));
      await t.pumpAndSettle();

      final Iterable<AnimatedContainer> pastillas = t
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final int conFondo = pastillas.where((AnimatedContainer c) {
        final Decoration? d = c.decoration;
        return d is BoxDecoration && d.color != Colors.transparent;
      }).length;
      expect(
        conFondo,
        1,
        reason: 'Exactamente un destino marcado: el de la ruta actual',
      );
    });

    testWidgets('un caso concreto también marca Casos', (WidgetTester t) async {
      await t.pumpWidget(montar(ruta: Rutas.casos));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
    });
  });

  group('Contador de la bandeja', () {
    testWidgets('se conserva el número (no un punto)', (WidgetTester t) async {
      await t.pumpWidget(montar(noLeidas: 6));
      await t.pumpAndSettle();
      expect(
        find.text('6'),
        findsOneWidget,
        reason:
            'Seis pendientes y uno no son la misma mañana: el punto de '
            'Instagram perdería esa información',
      );
    });

    testWidgets('se corta en 9+', (WidgetTester t) async {
      await t.pumpWidget(montar(noLeidas: 23));
      await t.pumpAndSettle();
      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('sin pendientes no hay distintivo', (WidgetTester t) async {
      await t.pumpWidget(montar());
      await t.pumpAndSettle();
      expect(find.text('0'), findsNothing);
    });

    testWidgets('no tapa la campana', (WidgetTester t) async {
      // Regresión vista en el emulador: con un desplazamiento pequeño el «9+»
      // se pintaba ENCIMA del icono y Bandeja dejaba de reconocerse. En una
      // barra sin etiquetas, el icono es lo único que identifica el destino.
      await t.pumpWidget(montar(noLeidas: 23));
      await t.pumpAndSettle();

      final Rect campana = t.getRect(find.byIcon(Icons.notifications_none));
      final Rect cuenta = t.getRect(find.text('9+'));

      // Un distintivo muerde la esquina: eso es normal y es lo que hace iOS.
      // Lo que no puede es comerse el icono. Se exige que deje libre la mitad
      // izquierda y los dos tercios de abajo, que es donde vive la silueta
      // reconocible de la campana.
      expect(
        cuenta.left,
        greaterThanOrEqualTo(campana.left + campana.width / 2),
        reason: 'El contador se come más de media campana',
      );
      expect(
        cuenta.bottom,
        lessThanOrEqualTo(campana.top + campana.height * 0.4),
        reason: 'El contador baja demasiado sobre la campana',
      );
    });
  });

  group('Tema oscuro', () {
    testWidgets('el cristal es más opaco que en claro', (WidgetTester t) async {
      double opacidadDe(WidgetTester t) {
        final DecoratedBox caja = t.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(BackdropFilter),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return ((caja.decoration as BoxDecoration).color!).a;
      }

      await t.pumpWidget(montar(tema: JvTheme.claro));
      await t.pumpAndSettle();
      final double claro = opacidadDe(t);

      await t.pumpWidget(montar(tema: JvTheme.oscuro));
      await t.pumpAndSettle();
      final double oscuro = opacidadDe(t);

      expect(
        oscuro,
        greaterThan(claro),
        reason:
            'Al 72 % sobre #0F0D18 el cristal se ve sucio: la superficie '
            'oscura tiene poco contraste con lo que hay detrás',
      );
    });
  });
}
