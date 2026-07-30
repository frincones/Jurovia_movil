import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/aurora_button.dart';
import '../../shared/widgets/jurovia_logo.dart';
import 'ai_consent_gate.dart';

/// S04 · Consentimiento de tratamiento por IA de terceros.
///
/// **AuditCheck C8.1–C8.7 · Apple guideline 5.1.2(i):**
/// > *"You must clearly disclose where personal data will be shared with third
/// > parties, including with third-party AI, and obtain explicit permission
/// > before doing so."*
///
/// Requisitos que esta pantalla cumple, y que **no se pueden relajar**:
///  · Aparece **antes** del primer uso del agente (lo fuerza el router).
///  · **Nombra al proveedor**: "Anthropic (Claude)". No vale "terceros".
///  · **Enumera** los datos que salen. No vale "tus datos".
///  · Exige **acción afirmativa**: un botón. No vale "al continuar aceptas".
///  · **No está enterrada** en los términos: es una pantalla propia.
///  · Es **revocable** desde Ajustes → Privacidad y datos.
class AiConsentScreen extends ConsumerStatefulWidget {
  const AiConsentScreen({super.key});

  @override
  ConsumerState<AiConsentScreen> createState() => _AiConsentScreenState();
}

class _AiConsentScreenState extends ConsumerState<AiConsentScreen> {
  bool _guardando = false;

  Future<void> _aceptar() async {
    setState(() => _guardando = true);
    await ref.read(aiConsentProvider.notifier).aceptar();
    if (!mounted) return;
    setState(() => _guardando = false);
    context.go(Rutas.inicio);
  }

  void _rechazar() {
    // Rechazar no expulsa de la app: se puede usar todo lo que no invoque al
    // agente. Volver a intentar entrar al chat trae de vuelta aquí.
    context.go(Rutas.inicio);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                children: <Widget>[
                  const JuroviaMark(tamano: 52),
                  const SizedBox(height: 26),
                  Text('Antes de empezar', style: JvText.tituloPantalla),
                  const SizedBox(height: 12),
                  Text(
                    'Para responderte, Jurovia envía tu consulta a un proveedor '
                    'de inteligencia artificial externo. Necesitamos tu permiso '
                    'explícito antes de hacerlo.',
                    style: JvText.cuerpo.copyWith(
                      color: JvColors.txtSecundario,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // ── Proveedor, nombrado ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: JvShapes.rTarjeta,
                      border: Border.all(color: cs.outline),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: JvColors.sutil,
                            borderRadius: JvShapes.rCampo,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 20,
                            color: JvColors.purpura,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Proveedor de IA', style: JvText.etiqueta),
                              const SizedBox(height: 3),
                              Text(
                                AiConsentGate.provider,
                                style: JvText.cuerpoFuerte,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Datos que se comparten, enumerados ─────────────────
                  Text('QUÉ SE ENVÍA', style: JvText.etiqueta),
                  const SizedBox(height: 10),
                  ...AiConsentGate.datosCompartidos.map(
                    (String d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.check_circle_outline,
                              size: 17,
                              color: JvColors.purpura,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              d,
                              style: JvText.cuerpoMedio.copyWith(
                                color: JvColors.txtSecundario,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: JvColors.sutil,
                      borderRadius: JvShapes.rCampo,
                    ),
                    child: Text(
                      'No usamos tus casos para entrenar modelos. Puedes retirar '
                      'este permiso cuando quieras desde Perfil → Privacidad y '
                      'datos; sin él, el asistente no funciona.',
                      style: JvText.menor.copyWith(
                        color: JvColors.txtSecundario,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Acción afirmativa ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: <Widget>[
                  AuroraButton(
                    texto: 'Acepto y continúo',
                    cargando: _guardando,
                    onPressed: _aceptar,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _guardando ? null : _rechazar,
                    child: Text(
                      'Ahora no',
                      style: JvText.chip.copyWith(color: JvColors.txtTerciario),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
