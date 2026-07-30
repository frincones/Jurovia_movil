import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/aurora_button.dart';
import '../../shared/widgets/jurovia_logo.dart';

/// S03 · Login con código OTP por correo.
///
/// **Sin login social a propósito.** Al no usar Google/Facebook, la guideline
/// 4.8 de Apple (que obligaría a ofrecer también Sign in with Apple) no aplica.
/// Ver `StorePolicy.hasThirdPartyLogin`.
///
/// El prototipo dibujaba "Continuar con Google", pero ese proveedor está
/// deshabilitado en Supabase (`external_google_enabled = false`).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Paso { correo, codigo }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _codigo = TextEditingController();
  _Paso _paso = _Paso.correo;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  bool get _correoValido {
    final String v = _correo.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  Future<void> _enviar() async {
    if (!_correoValido) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).enviarCodigo(_correo.text);
      if (!mounted) return;
      setState(() => _paso = _Paso.codigo);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = _mensaje(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificar() async {
    if (_codigo.text.trim().length != 6) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .verificarCodigo(correo: _correo.text, codigo: _codigo.text);
      // El router redirige solo al detectar la sesión.
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mensaje(e);
        _codigo.clear();
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensaje(Object e) {
    final String s = e.toString().toLowerCase();
    if (s.contains('expired') || s.contains('invalid')) {
      return 'El código no es válido o ya expiró. Pide uno nuevo.';
    }
    if (s.contains('rate') || s.contains('too many')) {
      return 'Demasiados intentos. Espera un minuto.';
    }
    if (s.contains('network') || s.contains('socket')) {
      return 'Sin conexión. Comprueba tu internet.';
    }
    return 'No pudimos completar la operación. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final bool esCorreo = _paso == _Paso.correo;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          children: <Widget>[
            const JuroviaMark(tamano: 52),
            const SizedBox(height: 26),
            Text(
              esCorreo ? 'Entra a Jurovia' : 'Revisa tu correo',
              style: JvText.tituloPantalla.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 10),
            Text(
              esCorreo
                  ? 'Sin contraseñas. Te enviamos un código de 6 dígitos.'
                  : 'Enviamos un código de 6 dígitos a ${_correo.text.trim()}.',
              style: JvText.cuerpoMedio.copyWith(color: JvColors.txtSecundario),
            ),
            const SizedBox(height: 30),

            if (esCorreo) ...<Widget>[
              Text(
                'Correo profesional',
                style: JvText.menor.copyWith(color: JvColors.txtSecundario),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !_cargando,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(
                  hintText: 'nombre@estudio.co',
                ),
              ),
              const SizedBox(height: 16),
              AuroraButton(
                texto: 'Enviar código',
                cargando: _cargando,
                onPressed: _enviar,
              ),
            ] else ...<Widget>[
              TextField(
                controller: _codigo,
                keyboardType: TextInputType.number,
                autofocus: true,
                enabled: !_cargando,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: JvText.otp.copyWith(letterSpacing: 12),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '······',
                ),
                onChanged: (String v) {
                  if (v.length == 6) _verificar();
                },
              ),
              const SizedBox(height: 16),
              AuroraButton(
                texto: 'Verificar',
                cargando: _cargando,
                onPressed: _codigo.text.length == 6 ? _verificar : null,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _cargando
                    ? null
                    : () => setState(() {
                        _paso = _Paso.correo;
                        _codigo.clear();
                        _error = null;
                      }),
                child: const Text('Usar otro correo'),
              ),
            ],

            if (_error != null) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JvColors.peligro.withValues(alpha: 0.08),
                  borderRadius: JvShapes.rCampo,
                  border: Border.all(
                    color: JvColors.peligro.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  _error!,
                  style: JvText.menor.copyWith(color: JvColors.peligro),
                ),
              ),
            ],

            const SizedBox(height: 18),
            Text(
              'Al continuar aceptas los términos y la política de datos de Jurovia.',
              style: JvText.menor.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
