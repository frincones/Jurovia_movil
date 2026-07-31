import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurovia/core/theme/app_theme.dart';
import 'package:jurovia/core/theme/colors.dart';
import 'package:jurovia/core/theme/typography.dart';

/// Tema oscuro: que el texto **se vea**.
///
/// El bug que originó estas pruebas: `JvText` cocía `txtPrimario` (#191427) en
/// cada estilo al construirse. En claro se veía bien; en oscuro era casi negro
/// sobre casi negro (#0F0D18) y media app desaparecía. No lo detectó nadie
/// hasta que un usuario con el móvil en oscuro abrió la app.
///
/// Aquí se vigilan las dos causas: estilos con color cocido, y colores del tema
/// claro usados a mano en un widget.
void main() {
  /// Contraste WCAG entre dos colores opacos.
  double contraste(Color a, Color b) {
    double canal(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    double lum(Color c) =>
        0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
    final double la = lum(a);
    final double lb = lum(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  group('Ningún estilo trae el color cocido', () {
    final List<(String, TextStyle)> estaticos = <(String, TextStyle)>[
      ('display', JvText.display),
      ('tituloPantalla', JvText.tituloPantalla),
      ('tituloSeccion', JvText.tituloSeccion),
      ('tituloHoja', JvText.tituloHoja),
      ('cifra', JvText.cifra),
      ('logo', JvText.logo),
      ('cuerpo', JvText.cuerpo),
      ('cuerpoFuerte', JvText.cuerpoFuerte),
      ('cuerpoMedio', JvText.cuerpoMedio),
      ('chip', JvText.chip),
      ('documento', JvText.documento),
      ('documentoTitulo', JvText.documentoTitulo),
      ('otp', JvText.otp),
    ];

    for (final (String nombre, TextStyle estilo) in estaticos) {
      test('$nombre hereda el color del tema', () {
        expect(
          estilo.color,
          isNull,
          reason: 'Con el color cocido, «$nombre» se pinta igual sobre blanco '
              'que sobre #0F0D18 — y en el segundo caso no se ve',
        );
      });
    }

    test('`boton` sí lleva blanco: va sobre el gradiente aurora', () {
      // Única excepción legítima: su fondo no cambia con el tema.
      expect(JvText.boton.color, Colors.white);
    });
  });

  group('Los estilos atenuados se adaptan al fondo', () {
    // `MaterialApp.theme` pasa por `AnimatedTheme`: al cambiarlo, el primer
    // frame todavía trae el tema anterior interpolado. Con `Theme` directo el
    // cambio es inmediato y la prueba mide lo que cree que mide.
    Future<JvTextos> textosDe(WidgetTester t, ThemeData tema) async {
      late JvTextos textos;
      await t.pumpWidget(
        MaterialApp(
          home: Theme(
            data: tema,
            child: Builder(
              builder: (BuildContext c) {
                textos = JvText.de(c);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return textos;
    }

    testWidgets('en claro son oscuros; en oscuro, claros', (
      WidgetTester t,
    ) async {
      final JvTextos claro = await textosDe(t, JvTheme.claro);
      final JvTextos oscuro = await textosDe(t, JvTheme.oscuro);

      expect(claro.menor.color, JvColors.txtTerciario);
      expect(oscuro.menor.color, JvColors.txtTerciarioOsc);
      expect(claro.secundario.color, JvColors.txtSecundario);
      expect(oscuro.secundario.color, JvColors.txtSecundarioOsc);
    });

    testWidgets('todos superan el contraste mínimo sobre su fondo', (
      WidgetTester t,
    ) async {
      for (final (String etiqueta, ThemeData tema, Color fondo)
          in <(String, ThemeData, Color)>[
            ('claro', JvTheme.claro, JvColors.fondo),
            ('oscuro', JvTheme.oscuro, JvColors.fondoOsc),
          ]) {
        final JvTextos x = await textosDe(t, tema);
        for (final (String n, TextStyle s) in <(String, TextStyle)>[
          ('secundario', x.secundario),
          ('menor', x.menor),
          ('etiqueta', x.etiqueta),
          ('radicado', x.radicado),
          ('codigo', x.codigo),
        ]) {
          final double c = contraste(s.color!, fondo);
          expect(
            c,
            greaterThan(3.0),
            reason: 'En $etiqueta, «$n» queda a ${c.toStringAsFixed(2)}:1 '
                'sobre el fondo. Por debajo de 3:1 no se lee.',
          );
        }
      }
    });

    testWidgets('el texto principal del tema contrasta de sobra', (
      WidgetTester t,
    ) async {
      for (final (ThemeData tema, Color fondo) in <(ThemeData, Color)>[
        (JvTheme.claro, JvColors.fondo),
        (JvTheme.oscuro, JvColors.fondoOsc),
      ]) {
        expect(contraste(tema.colorScheme.onSurface, fondo), greaterThan(7.0));
      }
    });
  });

  group('El tema entrega el color a lo que hereda', () {
    test('textTheme define color en todas sus ranuras', () {
      for (final ThemeData tema in <ThemeData>[
        JvTheme.claro,
        JvTheme.oscuro,
      ]) {
        final TextTheme tt = tema.textTheme;
        for (final (String n, TextStyle? s) in <(String, TextStyle?)>[
          ('bodyMedium', tt.bodyMedium),
          ('bodyLarge', tt.bodyLarge),
          ('titleSmall', tt.titleSmall),
          ('headlineLarge', tt.headlineLarge),
        ]) {
          expect(
            s?.color,
            isNotNull,
            reason: '$n sin color: lo que herede de aquí sale del color por '
                'defecto de Material, no del nuestro',
          );
        }
      }
    });
  });

  group('Nadie usa los tokens del tema claro a mano', () {
    test('fuera de core/theme/ no se referencian los txt* crudos', () {
      // `txtPrimario` y compañía son tokens del tema CLARO. Usarlos en un
      // widget pinta gris oscuro sobre fondo oscuro. Fuera del tema siempre
      // `JvColors.de(context)`.
      final RegExp crudo = RegExp(
        r'JvColors\.txt(Primario|Secundario|Terciario)\b(?!Osc)',
      );
      final List<String> culpables = <String>[];

      void recorrer(Directory d) {
        for (final FileSystemEntity e in d.listSync()) {
          if (e is Directory) {
            if (e.path.replaceAll(r'\', '/').endsWith('core/theme')) continue;
            recorrer(e);
          } else if (e is File && e.path.endsWith('.dart')) {
            final String src = e.readAsStringSync().replaceAll(
              RegExp(r'//.*'),
              '',
            );
            if (crudo.hasMatch(src)) {
              culpables.add(e.path.split(RegExp(r'[\\/]lib[\\/]')).last);
            }
          }
        }
      }

      final Directory lib = Directory('lib');
      if (!lib.existsSync()) return; // el runner puede arrancar en otra raíz
      recorrer(lib);

      expect(
        culpables,
        isEmpty,
        reason: 'Estos archivos cocieron un color del tema claro:\n  '
            '${culpables.join("\n  ")}',
      );
    });
  });
}
