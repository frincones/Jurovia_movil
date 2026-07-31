import 'package:flutter/material.dart';

/// Paleta de Jurovia, extraída del prototipo (`ContextDesign/`).
///
/// Ningún color literal debe aparecer fuera de este archivo. Si hace falta un
/// color nuevo, se añade aquí con nombre semántico.
abstract final class JvColors {
  // ─────────────────────────── Marca ───────────────────────────
  static const Color rosa = Color(0xFFFF3D7F);
  static const Color magenta = Color(0xFFD23BE0);
  static const Color purpura = Color(0xFF7B3DF5);
  static const Color azul = Color(0xFF2F6BFF);
  static const Color purpuraHover = Color(0xFF5C1FD6);

  /// Gradiente Aurora: la identidad de Jurovia.
  ///
  /// Uso: logotipo, CTA principal, FAB del chat, avatar del agente, burbuja del
  /// usuario. **Nunca** en superficies grandes ni como fondo de pantalla.
  static const LinearGradient aurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[rosa, magenta, purpura, azul],
    stops: <double>[0.0, 0.34, 0.68, 1.0],
  );

  /// Variante de 3 paradas para elementos pequeños, donde las 4 no se distinguen.
  static const LinearGradient auroraCorta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[rosa, purpura, azul],
    stops: <double>[0.0, 0.6, 1.0],
  );

  /// Gradiente del botón de enviar y de la burbuja del usuario.
  static const LinearGradient purpuraAzul = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[purpura, azul],
  );

  // ───────────────────────── Superficies ───────────────────────
  static const Color fondo = Color(0xFFF7F8FB);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color sutil = Color(0xFFF1F3F8);

  // ─────────────────────────── Texto ───────────────────────────
  static const Color txtPrimario = Color(0xFF191427);
  static const Color txtSecundario = Color(0xFF566076);
  /// Lo más tenue que se puede pintar y seguir leyéndose.
  ///
  /// Era `#8A93A6`, que da **2,91:1** sobre el fondo claro — por debajo del
  /// mínimo de WCAG AA (4,5:1) para texto pequeño, y `menor` se usa a 12,5 px
  /// en 78 sitios. No se detectó antes porque el problema solo salta al
  /// medirlo: a simple vista «se lee», hasta que lo miras con sol o con la
  /// vista cansada. Este valor da 4,89:1 y sigue por debajo de [txtSecundario]
  /// (5,94:1), así que la jerarquía se mantiene.
  static const Color txtTerciario = Color(0xFF646D80);

  // ─────────────────────────── Bordes ──────────────────────────
  static const Color borde = Color(0xFFE7EAF1);
  static const Color bordeFuerte = Color(0xFFD7DCE8);

  // ───────────────────────── Semánticos ────────────────────────

  /// DORADO = FUENTE VERIFICADA CONTRA FUENTE OFICIAL.
  ///
  /// Uso exclusivo de [VerifiedChip], [SourceCard] y el icono de acta
  /// contrastada. Usarlo de adorno rompe la promesa del producto y contradice
  /// la regla 2.3 de metadata veraz de Apple.
  static const Color verificado = Color(0xFFC98A14);
  static const Color verificadoTxt = Color(0xFF8A5D08);
  static const Color verificadoFondo = Color(0x12C98A14);
  static const Color verificadoBorde = Color(0x47C98A14);
  static const LinearGradient verificadoIcono = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF2B338), Color(0xFFE8902A)],
  );

  /// Vigilancia judicial activa sobre un proceso.
  static const Color vigilancia = Color(0xFF2563EB);
  static const Color vigilanciaFondo = Color(0x172563EB);

  /// Término procesal corriendo (T−7, T−2, T−0).
  static const Color termino = Color(0xFFD97706);
  static const Color terminoFondo = Color(0x1AD97706);

  /// Proceso activo, integración conectada.
  static const Color exito = Color(0xFF16A34A);
  static const Color exitoFondo = Color(0x1A16A34A);

  /// Acción destructiva, notificación sin leer.
  static const Color peligro = Color(0xFFDC2626);

  // ────────────────────── Modo oscuro (§6.5) ───────────────────
  // Declarados desde el inicio para que ninguna pantalla use literales.
  // La implementación completa es de la Fase 4.
  static const Color fondoOsc = Color(0xFF0F0D18);
  static const Color superficieOsc = Color(0xFF1A1626);
  static const Color sutilOsc = Color(0xFF241F33);
  static const Color txtPrimarioOsc = Color(0xFFF2F1F7);
  static const Color txtSecundarioOsc = Color(0xFFA9B0C0);
  static const Color txtTerciarioOsc = Color(0xFF7E869A);
  static const Color bordeOsc = Color(0xFF2E2840);
  static const Color bordeFuerteOsc = Color(0xFF3D3653);

  /// El dorado sube de luminosidad en oscuro para mantener el contraste.
  static const Color verificadoOsc = Color(0xFFE8A72E);

  /// Tintas de texto e iconos resueltas contra el tema vigente.
  ///
  /// Los `txt*` de arriba son **tokens crudos del tema claro**: usarlos
  /// directamente en un widget pinta gris oscuro sobre fondo oscuro, que es
  /// invisible. Fuera de `core/theme/` siempre `JvColors.de(context).xxx`.
  static JvTintas de(BuildContext context) =>
      JvTintas._(Theme.of(context).brightness == Brightness.dark);
}

/// Colores de texto e icono que dependen del fondo sobre el que se pintan.
class JvTintas {
  const JvTintas._(this._oscuro);

  final bool _oscuro;

  /// Texto principal y iconos con protagonismo.
  Color get primario =>
      _oscuro ? JvColors.txtPrimarioOsc : JvColors.txtPrimario;

  /// Metadatos y iconos de apoyo.
  Color get secundario =>
      _oscuro ? JvColors.txtSecundarioOsc : JvColors.txtSecundario;

  /// Lo más tenue que se puede pintar y seguir siendo legible.
  Color get terciario =>
      _oscuro ? JvColors.txtTerciarioOsc : JvColors.txtTerciario;

  /// El dorado de «fuente verificada» sube de luminosidad en oscuro.
  Color get verificado =>
      _oscuro ? JvColors.verificadoOsc : JvColors.verificado;
}
