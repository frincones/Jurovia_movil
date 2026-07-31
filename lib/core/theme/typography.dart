import 'package:flutter/material.dart';

import 'colors.dart';

/// Familias tipográficas de Jurovia. Se empaquetan **locales** en
/// `assets/fonts/`: la app debe abrir sin red y sin parpadeo de fuentes.
abstract final class JvFonts {
  /// Interfaz.
  static const String inter = 'Inter';

  /// Títulos, cifras y logotipo.
  static const String grotesk = 'SpaceGrotesk';

  /// Cuerpo de documentos jurídicos.
  static const String serif = 'SourceSerif4';

  /// Radicados y datos técnicos.
  static const String mono = 'JetBrainsMono';
}

/// Son fuentes **variables**: un solo archivo cubre todos los pesos, pero el
/// peso hay que pedirlo por eje (`wght`) además de por [FontWeight]. Sin la
/// variación, todos los textos se renderizan en el peso por defecto.
List<FontVariation> _wght(double peso) => <FontVariation>[
  FontVariation('wght', peso),
];

/// ⚠️ **Sin color.** Un estilo que trae el color cocido se pinta igual en tema
/// claro que en oscuro, y en oscuro eso es texto casi negro sobre fondo casi
/// negro: invisible. Con `color: null` el texto hereda del tema, que es quien
/// sabe sobre qué fondo se está pintando.
TextStyle _estilo({
  required String familia,
  required double tam,
  required double peso,
  double? alto,
  double? espaciado,
  Color? color,
}) {
  return TextStyle(
    fontFamily: familia,
    fontSize: tam,
    fontWeight: FontWeight.values[(peso ~/ 100) - 1],
    fontVariations: _wght(peso),
    height: alto,
    letterSpacing: espaciado,
    color: color,
  );
}

/// Escala tipográfica del prototipo (`ContextDesign/`).
///
/// **Los estilos de esta clase no llevan color**: heredan el del tema. Eso es
/// lo que hace que la misma pantalla funcione en claro y en oscuro sin
/// duplicar nada.
///
/// Los estilos **atenuados** —los que valen precisamente por ser más tenues
/// que el texto normal— no están aquí: viven en [JvTextos] y solo se obtienen
/// con `JvText.de(context)`. No es un capricho de API: «más tenue» significa
/// un color distinto en cada fondo, así que sin contexto no se puede resolver.
/// Que no existan como estático es a propósito — el compilador impide volver a
/// cocer un gris claro sobre un fondo oscuro.
abstract final class JvText {
  /// Estilos atenuados, resueltos contra el tema vigente.
  static JvTextos de(BuildContext context) =>
      JvTextos._(Theme.of(context).brightness == Brightness.dark);

  // ───────────────────────── Space Grotesk ─────────────────────────

  /// Splash: "Jurov·ia" a 36 px.
  static TextStyle get display =>
      _estilo(familia: JvFonts.grotesk, tam: 36, peso: 600, espaciado: -1.44);

  /// Título de pantalla: "¿Qué trabajamos hoy, Camila?".
  static TextStyle get tituloPantalla => _estilo(
    familia: JvFonts.grotesk,
    tam: 29,
    peso: 600,
    alto: 1.15,
    espaciado: -0.58,
  );

  /// Encabezado de sección: "Casos", "Bandeja", "Perfil".
  static TextStyle get tituloSeccion =>
      _estilo(familia: JvFonts.grotesk, tam: 26, peso: 600, espaciado: -0.52);

  /// Título de hoja modal: "Trabaja sin límites".
  static TextStyle get tituloHoja =>
      _estilo(familia: JvFonts.grotesk, tam: 23, peso: 600, espaciado: -0.46);

  /// Cifra destacada: "T−2", "Traslado", precio del plan.
  static TextStyle get cifra =>
      _estilo(familia: JvFonts.grotesk, tam: 22, peso: 600);

  /// Logotipo en cabeceras.
  static TextStyle get logo =>
      _estilo(familia: JvFonts.grotesk, tam: 17, peso: 600, espaciado: -0.51);

  // ──────────────────────────── Inter ──────────────────────────────

  /// Cuerpo de la respuesta del agente.
  static TextStyle get cuerpo =>
      _estilo(familia: JvFonts.inter, tam: 15, peso: 400, alto: 1.65);

  /// Título de tarjeta, nombre de caso.
  static TextStyle get cuerpoFuerte =>
      _estilo(familia: JvFonts.inter, tam: 15, peso: 600);

  /// Texto de burbuja de chat y campos.
  static TextStyle get cuerpoMedio =>
      _estilo(familia: JvFonts.inter, tam: 14.5, peso: 400, alto: 1.55);

  /// Texto de botón principal. Va sobre el gradiente aurora, así que su color
  /// **sí** es fijo: el fondo no cambia con el tema.
  static TextStyle get boton =>
      _estilo(familia: JvFonts.inter, tam: 15, peso: 600, color: Colors.white);

  /// Texto de chip / píldora.
  static TextStyle get chip =>
      _estilo(familia: JvFonts.inter, tam: 12.5, peso: 500);

  // ─────────────────────── Source Serif 4 ──────────────────────────

  /// Cuerpo de un escrito jurídico.
  static TextStyle get documento =>
      _estilo(familia: JvFonts.serif, tam: 15.5, peso: 400, alto: 1.75);

  /// Título dentro de un documento.
  static TextStyle get documentoTitulo =>
      _estilo(familia: JvFonts.serif, tam: 20, peso: 600, alto: 1.35);

  // ─────────────────────── JetBrains Mono ──────────────────────────

  /// Dígito del código OTP.
  static TextStyle get otp =>
      _estilo(familia: JvFonts.mono, tam: 24, peso: 600);
}

/// Estilos cuyo color depende del fondo sobre el que se pintan.
///
/// Se obtienen con `JvText.de(context)`.
class JvTextos {
  const JvTextos._(this._oscuro);

  final bool _oscuro;

  Color get _secundario =>
      _oscuro ? JvColors.txtSecundarioOsc : JvColors.txtSecundario;

  Color get _terciario =>
      _oscuro ? JvColors.txtTerciarioOsc : JvColors.txtTerciario;

  /// Metadatos, subtítulos de lista.
  TextStyle get secundario =>
      _estilo(familia: JvFonts.inter, tam: 13.5, peso: 400, color: _secundario);

  /// Texto de apoyo pequeño.
  TextStyle get menor =>
      _estilo(familia: JvFonts.inter, tam: 12.5, peso: 400, color: _terciario);

  /// Etiqueta de sección en mayúsculas: "PENDIENTES", "INTEGRACIONES".
  TextStyle get etiqueta => _estilo(
    familia: JvFonts.inter,
    tam: 11,
    peso: 600,
    espaciado: 0.99,
    color: _terciario,
  );

  /// Número de radicado.
  TextStyle get radicado =>
      _estilo(familia: JvFonts.mono, tam: 11, peso: 400, color: _terciario);

  /// Código global del caso (`JUR-XXXX-XXXX`).
  ///
  /// Pesa un punto más que el radicado: no es metadato de relleno, es el
  /// nombre corto del expediente.
  TextStyle get codigo => _estilo(
    familia: JvFonts.mono,
    tam: 11,
    peso: 500,
    espaciado: 0.2,
    color: _secundario,
  );
}
