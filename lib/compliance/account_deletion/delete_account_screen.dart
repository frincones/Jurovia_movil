import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/aurora_button.dart';

/// S14 · Eliminar cuenta.
///
/// **AuditCheck A3.29 (Apple 5.1.1(v)) y G7.27 (Google User Data policy).**
///
/// Ambas tiendas exigen que una app con registro permita **borrar la cuenta
/// desde dentro de la app**. Desactivar o "congelar" no cuenta. Google exige
/// además una URL pública equivalente — esa vive en el frontend web
/// (`juroviapp.com/eliminar-cuenta`) y **todavía no existe**.
///
/// El backend ya hace el trabajo real: `POST /api/me/delete` cancela la
/// suscripción en Paddle, borra el org en cascada y limpia las tablas por
/// correo. Aquí solo se confirma y se purga el dispositivo.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _confirmacion = TextEditingController();
  bool _borrando = false;
  String? _error;

  /// El backend exige exactamente esta palabra.
  static const String _palabraClave = 'ELIMINAR';

  @override
  void initState() {
    super.initState();
    _confirmacion.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _puedeBorrar =>
      _confirmacion.text.trim().toUpperCase() == _palabraClave && !_borrando;

  Future<void> _eliminar() async {
    setState(() {
      _borrando = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/me/delete',
            cuerpo: <String, dynamic>{'confirm': _palabraClave},
          );
      // Purga local: la caché contiene expedientes con datos de clientes.
      await ref.read(secureStoreProvider).purgar();
      await ref.read(authServiceProvider).cerrar();
      if (!mounted) return;
      context.go(Rutas.login);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _borrando = false;
        _error = 'No pudimos eliminar la cuenta. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar cuenta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JvColors.peligro.withValues(alpha: 0.07),
                borderRadius: JvShapes.rTarjeta,
                border: Border.all(
                  color: JvColors.peligro.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: JvColors.peligro,
                    size: 20,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Esta acción es irreversible. No se puede deshacer ni '
                      'recuperar la información después.',
                      style: JvText.cuerpoMedio.copyWith(
                        color: JvColors.peligro,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('QUÉ SE ELIMINA', style: JvText.etiqueta),
            const SizedBox(height: 10),
            ...<String>[
              'Tus conversaciones con el asistente',
              'Tus casos, documentos y actuaciones',
              'Tus audiencias y actas',
              'Tu perfil y los datos de tu despacho',
              'Tu suscripción, que se cancela automáticamente',
            ].map(
              (String t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.remove_circle_outline,
                        size: 15,
                        color: JvColors.txtTerciario,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: JvText.secundario)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            Text('QUÉ SE CONSERVA', style: JvText.etiqueta),
            const SizedBox(height: 10),
            // Google exige informar claramente de lo que se retiene y por qué.
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: JvShapes.rCampo,
              ),
              child: Text(
                'Los registros de facturación se conservan de forma anónima '
                'durante el tiempo que exige la normativa contable y tributaria '
                'colombiana. No quedan ligados a tu identidad.',
                style: JvText.menor.copyWith(height: 1.5),
              ),
            ),

            const SizedBox(height: 26),
            Text(
              'Escribe $_palabraClave para confirmar',
              style: JvText.cuerpoFuerte,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmacion,
              enabled: !_borrando,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: _palabraClave),
            ),

            if (_error != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: JvText.menor.copyWith(color: JvColors.peligro),
              ),
            ],

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _puedeBorrar ? _eliminar : null,
                style: FilledButton.styleFrom(
                  backgroundColor: JvColors.peligro,
                  disabledBackgroundColor: JvColors.peligro.withValues(
                    alpha: 0.3,
                  ),
                ),
                child: _borrando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Eliminar mi cuenta', style: JvText.boton),
              ),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              texto: 'Cancelar',
              onPressed: _borrando ? null : () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
