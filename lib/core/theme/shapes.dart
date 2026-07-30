import 'package:flutter/material.dart';

import 'colors.dart';

/// Radios y sombras del prototipo. Ningún valor literal en las pantallas.
abstract final class JvShapes {
  // ─────────────────────────── Radios ──────────────────────────
  /// Botones, chips, píldoras, avatares circulares.
  static const double pill = 999;

  /// Composer del chat.
  static const double composer = 22;

  /// Tarjetas.
  static const double tarjeta = 18;

  /// Filas de lista agrupadas.
  static const double lista = 17;

  /// Campos de texto y celdas pequeñas.
  static const double campo = 14;

  /// Esquinas superiores de la hoja modal.
  static const double hoja = 26;

  /// Icono del agente / logotipo pequeño.
  static const double icono = 11.4;

  static BorderRadius get rPill => BorderRadius.circular(pill);
  static BorderRadius get rComposer => BorderRadius.circular(composer);
  static BorderRadius get rTarjeta => BorderRadius.circular(tarjeta);
  static BorderRadius get rLista => BorderRadius.circular(lista);
  static BorderRadius get rCampo => BorderRadius.circular(campo);
  static BorderRadius get rIcono => BorderRadius.circular(icono);
  static BorderRadius get rHoja =>
      const BorderRadius.vertical(top: Radius.circular(hoja));

  // ─────────────────────────── Sombras ─────────────────────────
  /// Elevación suave de tarjeta.
  static const List<BoxShadow> sombraTarjeta = <BoxShadow>[
    BoxShadow(
      color: Color(0x12131320),
      blurRadius: 20,
      offset: Offset(0, 6),
      spreadRadius: -6,
    ),
  ];

  /// Sombra teñida del CTA principal (aurora).
  static const List<BoxShadow> sombraAurora = <BoxShadow>[
    BoxShadow(
      color: Color(0xB37B3DF5),
      blurRadius: 26,
      offset: Offset(0, 12),
      spreadRadius: -10,
    ),
  ];

  /// Sombra del FAB del chat.
  static const List<BoxShadow> sombraFab = <BoxShadow>[
    BoxShadow(
      color: Color(0xCC7B3DF5),
      blurRadius: 30,
      offset: Offset(0, 14),
      spreadRadius: -10,
    ),
  ];

  // ────────────────────────── Espaciado ────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;

  /// Borde estándar de superficie.
  static Border get bordeSuave => Border.all(color: JvColors.borde);
  static Border get bordeMarcado => Border.all(color: JvColors.bordeFuerte);
}
