import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';

/// Solicitud de aprobación pendiente.
///
/// El agente pide confirmación antes de acciones con consecuencias (radicar,
/// enviar un correo, cerrar un caso). Nada se ejecuta sin que el abogado
/// decida: es la traducción operativa de «Tú revisas y decides».
class Aprobacion {
  const Aprobacion({
    required this.id,
    required this.titulo,
    this.detalle = '',
    this.tipo = '',
    this.creadaEn,
  });

  final String id;
  final String titulo;
  final String detalle;
  final String tipo;
  final DateTime? creadaEn;

  factory Aprobacion.fromJson(Map<String, dynamic> j) => Aprobacion(
    id: j['id'] as String? ?? '',
    titulo:
        j['title'] as String? ??
        j['action'] as String? ??
        'Acción pendiente de aprobación',
    detalle: j['description'] as String? ?? j['detail'] as String? ?? '',
    tipo: j['kind'] as String? ?? j['type'] as String? ?? '',
    creadaEn: DateTime.tryParse(j['created_at'] as String? ?? ''),
  );
}

final AutoDisposeFutureProvider<List<Aprobacion>> aprobacionesProvider =
    FutureProvider.autoDispose<List<Aprobacion>>((Ref ref) async {
      try {
        final List<dynamic> crudas = await ref
            .watch(apiClientProvider)
            .getLista('/api/approvals');
        return crudas
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> a) =>
                  Aprobacion.fromJson(Map<String, dynamic>.from(a)),
            )
            .toList();
      } on Object {
        // La bandeja no puede caerse porque falle este bloque.
        return <Aprobacion>[];
      }
    });

/// Bloque de aprobaciones pendientes, al principio de la bandeja.
class BloqueAprobaciones extends ConsumerWidget {
  const BloqueAprobaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Aprobacion> lista =
        ref.watch(aprobacionesProvider).valueOrNull ?? <Aprobacion>[];
    if (lista.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 9),
          child: Text('REQUIEREN TU DECISIÓN', style: JvText.etiqueta),
        ),
        ...lista.map((Aprobacion a) => _Tarjeta(aprobacion: a)),
      ],
    );
  }
}

class _Tarjeta extends ConsumerStatefulWidget {
  const _Tarjeta({required this.aprobacion});

  final Aprobacion aprobacion;

  @override
  ConsumerState<_Tarjeta> createState() => _TarjetaState();
}

class _TarjetaState extends ConsumerState<_Tarjeta> {
  bool _enviando = false;

  Future<void> _decidir(String decision) async {
    setState(() => _enviando = true);
    try {
      await ref
          .read(apiClientProvider)
          .post('/api/approvals/${widget.aprobacion.id}/$decision');
      ref.invalidate(aprobacionesProvider);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos registrar tu decisión.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Aprobacion a = widget.aprobacion;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        border: Border.all(color: JvColors.purpura.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: JvColors.purpura.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.rule,
                  size: 17,
                  color: JvColors.purpura,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.titulo,
                  style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          if (a.detalle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(a.detalle, style: JvText.secundario),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _enviando ? null : () => _decidir('reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JvColors.peligro,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  onPressed: _enviando ? null : () => _decidir('approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: JvColors.purpura,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Aprobar',
                          style: JvText.boton.copyWith(fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
