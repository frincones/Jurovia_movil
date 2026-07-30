import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema del usuario.
///
/// Por defecto sigue al sistema: en móvil es lo que la gente espera, y evita
/// que la app aparezca en claro cuando el teléfono está en oscuro (una de las
/// cosas que más se notan como "esto no es nativo", regla 4.0 de Apple).
///
/// No va en el almacén cifrado: es una preferencia, no un secreto.
class TemaNotifier extends AsyncNotifier<ThemeMode> {
  static const String _clave = 'jv_tema';

  @override
  Future<ThemeMode> build() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return switch (p.getString(_clave)) {
        'claro' => ThemeMode.light,
        'oscuro' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } on Object {
      return ThemeMode.system;
    }
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = AsyncData<ThemeMode>(modo);
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(_clave, switch (modo) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'oscuro',
        ThemeMode.system => 'sistema',
      });
    } on Object {
      // Si no se puede persistir, la sesión actual funciona igual.
    }
  }
}

final AsyncNotifierProvider<TemaNotifier, ThemeMode> temaProvider =
    AsyncNotifierProvider<TemaNotifier, ThemeMode>(TemaNotifier.new);

extension EtiquetaTema on ThemeMode {
  String get etiqueta => switch (this) {
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
    ThemeMode.system => 'Automático',
  };

  IconData get icono => switch (this) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };
}
