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
    color: color ?? JvColors.txtPrimario,
  );
}

/// Escala tipográfica tomada del prototipo (`ContextDesign/`).
abstract final class JvText {
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

  /// Metadatos, subtítulos de lista.
  static TextStyle get secundario => _estilo(
    familia: JvFonts.inter,
    tam: 13.5,
    peso: 400,
    color: JvColors.txtSecundario,
  );

  /// Texto de apoyo pequeño.
  static TextStyle get menor => _estilo(
    familia: JvFonts.inter,
    tam: 12.5,
    peso: 400,
    color: JvColors.txtTerciario,
  );

  /// Etiqueta de sección en mayúsculas: "PENDIENTES", "INTEGRACIONES".
  static TextStyle get etiqueta => _estilo(
    familia: JvFonts.inter,
    tam: 11,
    peso: 600,
    espaciado: 0.99,
    color: JvColors.txtTerciario,
  );

  /// Texto de botón principal.
  static TextStyle get boton =>
      _estilo(familia: JvFonts.inter, tam: 15, peso: 600, color: Colors.white);

  /// Texto de chip / píldora.
  static TextStyle get chip =>
      _estilo(familia: JvFonts.inter, tam: 12.5, peso: 500);

  /// Etiqueta de la barra inferior.
  static TextStyle get nav =>
      _estilo(familia: JvFonts.inter, tam: 10.5, peso: 500);

  // ─────────────────────── Source Serif 4 ──────────────────────────

  /// Cuerpo de un escrito jurídico.
  static TextStyle get documento =>
      _estilo(familia: JvFonts.serif, tam: 15.5, peso: 400, alto: 1.75);

  /// Título dentro de un documento.
  static TextStyle get documentoTitulo =>
      _estilo(familia: JvFonts.serif, tam: 20, peso: 600, alto: 1.35);

  // ─────────────────────── JetBrains Mono ──────────────────────────

  /// Número de radicado.
  static TextStyle get radicado => _estilo(
    familia: JvFonts.mono,
    tam: 11,
    peso: 400,
    color: JvColors.txtTerciario,
  );

  /// Código global del caso (`JUR-XXXX-XXXX`).
  ///
  /// Es el identificador con el que el abogado se refiere al caso por teléfono
  /// o por correo, así que pesa un punto más que el radicado: no es metadato
  /// de relleno, es el nombre corto del expediente.
  static TextStyle get codigo => _estilo(
    familia: JvFonts.mono,
    tam: 11,
    peso: 500,
    espaciado: 0.2,
    color: JvColors.txtSecundario,
  );

  /// Dígito del código OTP.
  static TextStyle get otp =>
      _estilo(familia: JvFonts.mono, tam: 24, peso: 600);
}
