import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../models/caso.dart';

/// Fila de un término procesal. La comparten el Inicio y el detalle del caso
/// para que un mismo término no se lea distinto según dónde aparezca.
class FilaTermino extends StatelessWidget {
  const FilaTermino({super.key, required this.termino, this.navegable = true});

  final Termino termino;

  /// En el detalle del caso ya se está *dentro* del caso: navegar no lleva a
  /// ninguna parte nueva.
  final bool navegable;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = termino.urgente
        ? JvColors.termino
        : JvColors.de(context).secundario;
    final Color bg = termino.urgente
        ? JvColors.terminoFondo
        : cs.surfaceContainerLow;
    final String? sub = termino.caso ?? termino.fundamento;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          borderRadius: JvShapes.rLista,
          onTap: (!navegable || termino.matterId == null)
              ? null
              : () => context.push('${Rutas.casos}/${termino.matterId}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            termino.dia,
                            style: JvText.cuerpoFuerte.copyWith(
                              fontSize: 15,
                              color: fg,
                            ),
                          ),
                          Text(
                            termino.mes.toUpperCase(),
                            style: JvText.de(
                              context,
                            ).menor.copyWith(fontSize: 9, color: fg),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            termino.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
                          ),
                          if (sub != null && sub.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JvText.de(context).menor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: JvShapes.rPill,
                      ),
                      child: Text(
                        termino.etiqueta,
                        style: JvText.de(
                          context,
                        ).menor.copyWith(fontSize: 11, color: fg),
                      ),
                    ),
                  ],
                ),
                // Un término que el Autopilot dedujo de una actuación NO está
                // confirmado. Si el abogado lo toma por cierto y la fecha real
                // era otra, pierde el término: hay que decir explícitamente
                // que falta confirmarlo, no insinuarlo.
                if (termino.tentativo) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: JvColors.terminoFondo,
                      borderRadius: JvShapes.rPill,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.help_outline,
                          size: 12,
                          color: JvColors.termino,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Fecha tentativa · confírmala en el expediente',
                            style: JvText.de(context).menor.copyWith(
                              fontSize: 11,
                              color: JvColors.termino,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (termino.fundamento != null &&
                      termino.caso != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      termino.fundamento!,
                      style: JvText.de(
                        context,
                      ).menor.copyWith(fontSize: 11, height: 1.4),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
