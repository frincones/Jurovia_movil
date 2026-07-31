import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';
import 'shapes.dart';
import 'typography.dart';

/// Temas claro y oscuro.
///
/// El oscuro se declara **desde el inicio** (§6.5 de la arquitectura) aunque su
/// pulido sea de la Fase 4: así ninguna pantalla puede escribir colores
/// literales y no hay que reajustar 16 pantallas más tarde.
abstract final class JvTheme {
  static ThemeData get claro => _construir(Brightness.light);
  static ThemeData get oscuro => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final bool esOscuro = brillo == Brightness.dark;

    final Color fondo = esOscuro ? JvColors.fondoOsc : JvColors.fondo;
    final Color superficie = esOscuro
        ? JvColors.superficieOsc
        : JvColors.superficie;
    final Color txt = esOscuro ? JvColors.txtPrimarioOsc : JvColors.txtPrimario;
    final Color borde = esOscuro ? JvColors.bordeOsc : JvColors.borde;

    final ColorScheme esquema = ColorScheme(
      brightness: brillo,
      primary: JvColors.purpura,
      onPrimary: Colors.white,
      secondary: JvColors.azul,
      onSecondary: Colors.white,
      tertiary: JvColors.verificado,
      onTertiary: Colors.white,
      error: JvColors.peligro,
      onError: Colors.white,
      surface: superficie,
      onSurface: txt,
      onSurfaceVariant: esOscuro
          ? JvColors.txtSecundarioOsc
          : JvColors.txtSecundario,
      surfaceContainerLowest: fondo,
      surfaceContainerLow: esOscuro ? JvColors.sutilOsc : JvColors.sutil,
      outline: borde,
      outlineVariant: esOscuro ? JvColors.bordeFuerteOsc : JvColors.bordeFuerte,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,
      fontFamily: JvFonts.inter,
      splashFactory: InkSparkle.splashFactory,

      // Los estilos de JvText no traen color: lo heredan de aquí. Sin este
      // bloque, un `Text(style: JvText.cuerpoFuerte)` quedaría a merced del
      // valor por defecto de Material, que no conoce nuestra escala.
      textTheme: TextTheme(
        displayLarge: JvText.display.copyWith(color: txt),
        headlineLarge: JvText.tituloPantalla.copyWith(color: txt),
        headlineMedium: JvText.tituloSeccion.copyWith(color: txt),
        headlineSmall: JvText.tituloHoja.copyWith(color: txt),
        titleLarge: JvText.cifra.copyWith(color: txt),
        titleMedium: JvText.logo.copyWith(color: txt),
        titleSmall: JvText.cuerpoFuerte.copyWith(color: txt),
        bodyLarge: JvText.cuerpo.copyWith(color: txt),
        bodyMedium: JvText.cuerpoMedio.copyWith(color: txt),
        bodySmall: JvText.chip.copyWith(color: txt),
        labelLarge: JvText.cuerpoFuerte.copyWith(color: txt),
        labelMedium: JvText.chip.copyWith(color: txt),
        labelSmall: JvText.chip.copyWith(color: esquema.onSurfaceVariant),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: JvText.logo.copyWith(color: txt),
        systemOverlayStyle: esOscuro
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficie,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: JvShapes.rCampo,
          borderSide: BorderSide(color: esquema.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: JvShapes.rCampo,
          borderSide: BorderSide(color: esquema.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: JvShapes.rCampo,
          borderSide: const BorderSide(color: JvColors.purpura, width: 1.5),
        ),
        hintStyle: JvText.cuerpoMedio.copyWith(
          color: esOscuro ? JvColors.txtTerciarioOsc : JvColors.txtTerciario,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: JvColors.purpura,
          foregroundColor: Colors.white,
          textStyle: JvText.boton,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: JvShapes.rPill),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: JvColors.purpura,
          textStyle: JvText.chip,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txt,
          textStyle: JvText.cuerpoFuerte,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: BorderSide(color: esquema.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: JvShapes.rPill),
        ),
      ),

      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: JvShapes.rTarjeta,
          side: BorderSide(color: borde),
        ),
      ),

      dividerTheme: DividerThemeData(color: borde, thickness: 1, space: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: JvShapes.rHoja),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: esOscuro ? JvColors.sutilOsc : JvColors.txtPrimario,
        contentTextStyle: JvText.cuerpoMedio.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: JvShapes.rCampo),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: JvColors.purpura,
      ),
    );
  }
}
