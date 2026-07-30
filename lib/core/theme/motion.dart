import 'package:flutter/material.dart';

/// Curvas y duraciones del prototipo.
///
/// Todas las animaciones deben respetar `MediaQuery.disableAnimationsOf`
/// (equivale al `prefers-reduced-motion` que el prototipo ya honra).
abstract final class JvMotion {
  /// Curva de marca. Rebote suave, presente en todo el prototipo.
  static const Curve marca = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Variante menos elástica, para el drawer y la hoja modal.
  static const Curve suave = Cubic(0.34, 1.10, 0.64, 1.0);

  /// Entrada de un mensaje nuevo en el chat (`jvFade`).
  static const Duration fade = Duration(milliseconds: 300);

  /// Apertura del drawer lateral (`jvSlide`).
  static const Duration drawer = Duration(milliseconds: 260);

  /// Apertura de la hoja modal (`jvSheet`).
  static const Duration hoja = Duration(milliseconds: 300);

  /// Conmutador mensual/anual.
  static const Duration toggle = Duration(milliseconds: 320);

  /// Giro del indicador de carga (`jvSpin`).
  static const Duration spin = Duration(milliseconds: 800);

  /// Pulso de los 3 puntos del agente pensando (`jvPulse`).
  static const Duration pulse = Duration(milliseconds: 1000);

  /// Desfase entre los 3 puntos: 0, .15s, .3s.
  static const List<Duration> pulseDesfase = <Duration>[
    Duration.zero,
    Duration(milliseconds: 150),
    Duration(milliseconds: 300),
  ];

  /// Barras del ecualizador de audiencias (`jvBar`), desfase .12s.
  static const Duration bar = Duration(milliseconds: 1100);
  static const Duration barDesfase = Duration(milliseconds: 120);

  /// Duración efectiva: 0 si el sistema pide menos movimiento.
  static Duration efectiva(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
