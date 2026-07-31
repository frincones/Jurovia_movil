import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/refresh_policy.dart';
import '../../core/theme/typography.dart';

/// F3.26 · "actualizado hace X".
///
/// El usuario debe poder saber si lo que ve puede estar desactualizado y
/// forzar la recarga. Es la contrapartida honesta de la Opción A: sin
/// suscripciones en vivo, la app dice cuándo miró el servidor por última vez
/// en lugar de fingir que está siempre al día.
class IndicadorFrescura extends ConsumerWidget {
  const IndicadorFrescura({super.key, required this.clave, this.onRefrescar});

  final String clave;
  final VoidCallback? onRefrescar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(frescuraProvider);
    final String texto = ref.read(frescuraProvider.notifier).descripcion(clave);
    if (texto.isEmpty) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      label: texto,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(texto, style: JvText.de(context).menor.copyWith(fontSize: 11)),
          if (onRefrescar != null) ...<Widget>[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRefrescar,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh, size: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
