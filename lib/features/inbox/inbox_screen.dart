import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/models/caso.dart';
import '../../core/sync/refresh_policy.dart';
import '../../shared/widgets/estado_vista.dart';
import '../../shared/widgets/indicador_frescura.dart';
import 'approvals.dart';

/// S11 · Bandeja de avisos, agrupada por fecha.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  /// Icono y color por tipo de aviso, como el prototipo.
  static (IconData, Color, Color) _estilo(String tipo) => switch (tipo) {
    'movimiento' ||
    'actuacion' => (Icons.gavel, JvColors.purpura, const Color(0x1A7B3DF5)),
    'deadline' || 'termino' => (
      Icons.hourglass_bottom,
      JvColors.termino,
      JvColors.terminoFondo,
    ),
    'acta' || 'audiencia' => (
      Icons.check_circle_outline,
      JvColors.verificadoTxt,
      JvColors.verificadoFondo,
    ),
    'vigilancia' => (
      Icons.visibility_outlined,
      JvColors.vigilancia,
      JvColors.vigilanciaFondo,
    ),
    'documento' || 'draft_ready' => (
      Icons.description_outlined,
      JvColors.txtSecundario,
      Color(0x14566076),
    ),
    'parte_diario' => (
      Icons.wb_sunny_outlined,
      JvColors.purpura,
      Color(0x1A7B3DF5),
    ),
    'missing_doc' => (
      Icons.help_outline,
      JvColors.termino,
      JvColors.terminoFondo,
    ),
    _ => (Icons.notifications_none, JvColors.txtSecundario, Color(0x14566076)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Notificacion>> avisos = ref.watch(
      notificacionesProvider,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 18, 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.menu, size: 20),
                    tooltip: 'Historial de conversaciones',
                    onPressed: abrirHistorial,
                  ),
                  Text('Bandeja', style: JvText.tituloSeccion),
                  const SizedBox(width: 10),
                  const IndicadorFrescura(clave: 'bandeja'),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(apiClientProvider)
                          .post('/api/notifications/read-all');
                      ref
                        ..invalidate(notificacionesProvider)
                        ..invalidate(noLeidasProvider);
                      ref.read(frescuraProvider.notifier).marcar('bandeja');
                    },
                    child: const Text('Marcar leídas'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: avisos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => EstadoError(
                  onReintentar: () => ref.invalidate(notificacionesProvider),
                ),
                data: (List<Notificacion> lista) {
                  final bool hayAprobaciones =
                      (ref.watch(aprobacionesProvider).valueOrNull ??
                              <Aprobacion>[])
                          .isNotEmpty;
                  if (lista.isEmpty && !hayAprobaciones) {
                    return const EstadoVacio(
                      icono: Icons.notifications_none,
                      titulo: 'Todo al día',
                      detalle:
                          'Aquí llegarán los movimientos de tus procesos y '
                          'los avisos de términos.',
                    );
                  }

                  final Map<String, List<Notificacion>> grupos =
                      <String, List<Notificacion>>{};
                  for (final Notificacion n in lista) {
                    grupos.putIfAbsent(n.grupo, () => <Notificacion>[]).add(n);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref
                        ..invalidate(notificacionesProvider)
                        ..invalidate(noLeidasProvider);
                    },
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        0,
                        18,
                        BarraFlotante.espacioContenido(context),
                      ),
                      children: <Widget>[
                        // F3.11 · Lo que requiere decisión va primero.
                        const BloqueAprobaciones(),
                        ...grupos.entries.expand((
                          MapEntry<String, List<Notificacion>> g,
                        ) {
                          return <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                bottom: 9,
                              ),
                              child: Text(
                                g.key.toUpperCase(),
                                style: JvText.etiqueta,
                              ),
                            ),
                            ...g.value.map(
                              (Notificacion n) =>
                                  _TarjetaAviso(aviso: n, ref: ref),
                            ),
                          ];
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso, required this.ref});

  final Notificacion aviso;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final (IconData icono, Color fg, Color bg) = InboxScreen._estilo(
      aviso.tipo,
    );
    final bool urgente = aviso.tipo == 'deadline';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: urgente ? JvColors.terminoFondo : cs.surface,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          borderRadius: JvShapes.rLista,
          onTap: () async {
            if (!aviso.leida) {
              await ref
                  .read(apiClientProvider)
                  .post('/api/notifications/${aviso.id}/read');
              ref
                ..invalidate(notificacionesProvider)
                ..invalidate(noLeidasProvider);
            }
            if (!context.mounted) return;
            if (aviso.esParteDiario) {
              // El Parte del día lleva al Inicio, que ES el briefing.
              context.go(Rutas.inicio);
            } else if (aviso.matterId != null) {
              context.push('${Rutas.casos}/${aviso.matterId}');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(
                color: urgente
                    ? JvColors.termino.withValues(alpha: 0.25)
                    : cs.outline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icono, size: 17, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              aviso.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(aviso.cuando, style: JvText.menor),
                        ],
                      ),
                      if (aviso.cuerpo.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(aviso.cuerpo, style: JvText.secundario),
                      ],
                    ],
                  ),
                ),
                if (!aviso.leida)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5, left: 6),
                    decoration: const BoxDecoration(
                      color: JvColors.purpura,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
