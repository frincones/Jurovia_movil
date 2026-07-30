import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_providers.dart';
import '../providers.dart';
import '../../features/chat/chat_controller.dart';

/// Política de refresco — **Opción A** de la arquitectura (§11.3).
///
/// Web y móvil comparten la misma base, así que no hay nada que sincronizar:
/// solo hay que **volver a pedir** los datos en los momentos correctos.
///
/// Deliberadamente **sin *polling* por temporizador**: gastaría batería y datos
/// móviles para cubrir un caso que casi no ocurre (los dos clientes abiertos a
/// la vez). Los disparadores por evento cubren el uso real.
abstract final class RefreshPolicy {
  /// Antigüedad a partir de la cual se recarga al volver a primer plano.
  static const Duration alVolver = Duration(seconds: 30);

  /// Antigüedad máxima antes de considerar obsoleta la caché de una pantalla.
  static const Duration alEntrar = Duration(minutes: 2);

  /// Tras este tiempo en segundo plano se invalida **todo** lo visible.
  static const Duration ausenciaLarga = Duration(minutes: 5);
}

/// Marca de tiempo del último refresco de cada colección.
class RegistroFrescura extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => <String, DateTime>{};

  void marcar(String clave) {
    state = <String, DateTime>{...state, clave: DateTime.now()};
  }

  DateTime? ultimo(String clave) => state[clave];

  /// ¿Hace falta recargar esta colección?
  bool obsoleto(String clave, {Duration umbral = RefreshPolicy.alEntrar}) {
    final DateTime? t = state[clave];
    if (t == null) return true;
    return DateTime.now().difference(t) > umbral;
  }

  /// "actualizado hace 2 min" — para el indicador de frescura.
  String descripcion(String clave) {
    final DateTime? t = state[clave];
    if (t == null) return '';
    final int s = DateTime.now().difference(t).inSeconds;
    if (s < 45) return 'actualizado hace un momento';
    final int m = s ~/ 60;
    if (m < 60) return 'actualizado hace $m min';
    final int h = m ~/ 60;
    return 'actualizado hace $h h';
  }
}

final NotifierProvider<RegistroFrescura, Map<String, DateTime>>
frescuraProvider = NotifierProvider<RegistroFrescura, Map<String, DateTime>>(
  RegistroFrescura.new,
);

/// Observa el ciclo de vida de la app y recarga al volver a primer plano.
///
/// Se instala una sola vez, en la raíz del árbol de widgets.
class ObservadorCicloVida extends ConsumerStatefulWidget {
  const ObservadorCicloVida({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ObservadorCicloVida> createState() =>
      _ObservadorCicloVidaState();
}

class _ObservadorCicloVidaState extends ConsumerState<ObservadorCicloVida>
    with WidgetsBindingObserver {
  DateTime? _salidaAsegundoPlano;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _salidaAsegundoPlano = DateTime.now();

      case AppLifecycleState.resumed:
        _alVolver();

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _alVolver() {
    final DateTime? salida = _salidaAsegundoPlano;
    _salidaAsegundoPlano = null;
    if (salida == null) return;

    final Duration fuera = DateTime.now().difference(salida);
    if (fuera < RefreshPolicy.alVolver) return;

    // Identidad, plan y cuota: siempre.
    if (ref.read(autenticadoProvider)) {
      ref.read(meProvider.notifier).refrescar();
    }

    // Ausencia larga: se invalida todo lo visible (§11.3).
    if (fuera > RefreshPolicy.ausenciaLarga) {
      ref
        // El briefing va SOLO aquí, nunca en la rama corta: agrega media
        // docena de consultas en el servidor y su contenido cambia por hora,
        // no por minuto. Recargarlo cada vez que el abogado alterna con
        // WhatsApp sería castigar al backend para no mostrar nada nuevo.
        ..invalidate(briefingProvider)
        ..invalidate(casosProvider)
        // Sin argumento invalida **todas** las combinaciones de búsqueda y
        // filtro de la familia, que es justo lo que se quiere al volver.
        ..invalidate(casosFiltradosProvider)
        ..invalidate(notificacionesProvider)
        ..invalidate(noLeidasProvider)
        ..invalidate(terminosProvider)
        ..invalidate(sesionesProvider);
    } else {
      // Ausencia corta: solo lo que cambia por avisos del servidor.
      ref
        ..invalidate(noLeidasProvider)
        ..invalidate(notificacionesProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
