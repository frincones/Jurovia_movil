import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../ai_consent/ai_consent_gate.dart';
import 'disclaimer.dart';

/// S13 · Privacidad y datos.
///
/// **AuditCheck C8.6** (el consentimiento de IA debe poder revocarse) y
/// **A3.27** (la política de privacidad debe ser accesible dentro de la app).
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AiConsent? consent = ref.watch(aiConsentProvider).valueOrNull;
    final bool otorgado = AiConsentGate.canUseAgent(consent);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y datos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Text('TRATAMIENTO POR IA', style: JvText.etiqueta),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: JvShapes.rTarjeta,
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        otorgado ? Icons.check_circle : Icons.cancel_outlined,
                        size: 18,
                        color: otorgado
                            ? JvColors.exito
                            : JvColors.txtTerciario,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          otorgado ? 'Permiso concedido' : 'Permiso retirado',
                          style: JvText.cuerpoFuerte,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    otorgado
                        ? 'Tus consultas se envían a ${AiConsentGate.provider} '
                              'para generar las respuestas.'
                        : 'Sin este permiso el asistente no funciona. Puedes '
                              'volver a concederlo cuando quieras.',
                    style: JvText.secundario.copyWith(height: 1.5),
                  ),
                  if (consent?.fecha != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Concedido el ${consent!.fecha!.day}/'
                      '${consent.fecha!.month}/${consent.fecha!.year}',
                      style: JvText.menor.copyWith(fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (otorgado)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final bool? ok = await _confirmarRevocar(context);
                        if (ok ?? false) {
                          await ref.read(aiConsentProvider.notifier).revocar();
                        }
                      },
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Retirar permiso'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JvColors.peligro,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => context.push(Rutas.consentimientoIa),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Revisar permiso'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 26),
            Text('TUS DATOS', style: JvText.etiqueta),
            const SizedBox(height: 10),
            _Fila(
              icono: Icons.download_outlined,
              titulo: 'Descargar mis datos',
              detalle: 'Recibirás un archivo con toda tu información',
              onTap: () => _exportar(context, ref),
            ),
            _Fila(
              icono: Icons.delete_outline,
              titulo: 'Eliminar mi cuenta',
              detalle: 'Borra tu cuenta y todos tus datos',
              destructivo: true,
              onTap: () => context.push(Rutas.eliminarCuenta),
            ),

            const SizedBox(height: 26),
            Text('DOCUMENTOS', style: JvText.etiqueta),
            const SizedBox(height: 10),
            _Fila(
              icono: Icons.description_outlined,
              titulo: 'Política de privacidad',
              onTap: () => context.push(Rutas.legal),
            ),

            const SizedBox(height: 24),
            const DisclaimerBanner(),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmarRevocar(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: const Text('¿Retirar el permiso?'),
      content: const Text(
        'El asistente dejará de funcionar hasta que vuelvas a concederlo. '
        'El resto de la app sigue disponible.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          style: TextButton.styleFrom(foregroundColor: JvColors.peligro),
          child: const Text('Retirar'),
        ),
      ],
    ),
  );

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).get('/api/me/export');
      msg.showSnackBar(
        const SnackBar(
          content: Text('Preparamos tu archivo. Te llega por correo.'),
        ),
      );
    } on Object {
      msg.showSnackBar(
        const SnackBar(content: Text('No pudimos preparar la descarga.')),
      );
    }
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.detalle,
    this.destructivo = false,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;
  final String? detalle;
  final bool destructivo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = destructivo ? JvColors.peligro : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          onTap: onTap,
          borderRadius: JvShapes.rLista,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: <Widget>[
                Icon(icono, size: 18, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        titulo,
                        style: JvText.cuerpoMedio.copyWith(color: color),
                      ),
                      if (detalle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(detalle!, style: JvText.menor),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: JvColors.txtTerciario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
