import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compliance/ai_consent/ai_consent_gate.dart';
import '../../compliance/billing/billing_policy.dart';
import '../../compliance/billing/muro_plan.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';

import '../../core/sync/refresh_policy.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/models/briefing.dart';
import '../../shared/models/chat.dart';
import '../../shared/models/me.dart';
import '../../shared/widgets/aurora_button.dart';
import '../../shared/widgets/indicador_frescura.dart';
import '../../shared/widgets/jurovia_logo.dart';
import '../chat/chat_controller.dart';
import 'briefing_blocks.dart';

/// S05 · Inicio.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Me? me = ref.watch(meProvider).valueOrNull;
    final bool consentido = AiConsentGate.canUseAgent(
      ref.watch(aiConsentProvider).valueOrNull,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          // §11.3 — refresco al tirar. Sin polling por temporizador.
          onRefresh: () async {
            await ref.read(meProvider.notifier).refrescar();
            ref
              ..invalidate(briefingProvider)
              ..invalidate(sesionesProvider)
              ..invalidate(noLeidasProvider);
            ref.read(frescuraProvider.notifier).marcar('inicio');
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              BarraFlotante.espacioContenido(context),
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.menu, size: 20),
                    tooltip: 'Historial de conversaciones',
                    onPressed: abrirHistorial,
                  ),
                  const Spacer(),
                  const JuroviaLogo(),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Text('Hoy · Colombia', style: JvText.secundario),
                  const Spacer(),
                  const IndicadorFrescura(clave: 'inicio'),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '¿Qué trabajamos\nhoy, ${me?.nombreCorto ?? 'Abogado'}?',
                style: JvText.tituloPantalla,
              ),
              const SizedBox(height: 16),
              _ResumenCuenta(me: me),
              const SizedBox(height: 16),

              _EntradaChat(onTap: () => context.push(Rutas.chat)),

              if (!consentido) ...<Widget>[
                const SizedBox(height: 14),
                _AvisoConsentimiento(
                  onRevisar: () => context.push(Rutas.consentimientoIa),
                ),
              ],

              const SizedBox(height: 14),
              const _Atajos(),

              const SizedBox(height: 22),
              const _Briefing(),

              const SizedBox(height: 26),
              const _Recientes(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntradaChat extends StatelessWidget {
  const _EntradaChat({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: JvShapes.rComposer,
      child: InkWell(
        borderRadius: JvShapes.rComposer,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            borderRadius: JvShapes.rComposer,
            border: Border.all(color: cs.outlineVariant),
            boxShadow: JvShapes.sombraTarjeta,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Pregunta, redacta o pega un radicado…',
                  style: JvText.cuerpoMedio.copyWith(
                    color: JvColors.txtTerciario,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: JvColors.aurora,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoConsentimiento extends StatelessWidget {
  const _AvisoConsentimiento({required this.onRevisar});

  final VoidCallback onRevisar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: JvShapes.rCampo,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'El asistente necesita tu permiso para procesar tus consultas con '
            'inteligencia artificial.',
            style: JvText.menor.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          AuroraButton(
            texto: 'Revisar permiso',
            ancho: 180,
            onPressed: onRevisar,
          ),
        ],
      ),
    );
  }
}

class _Atajos extends StatelessWidget {
  const _Atajos();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<(IconData, String, Color, String)> atajos =
        <(IconData, String, Color, String)>[
          (Icons.edit_outlined, 'Redactar', JvColors.purpura, 'Redacta un '),
          (
            Icons.verified_outlined,
            'Verificar',
            JvColors.verificado,
            'Verifica esta norma: ',
          ),
          (Icons.mic_none, 'Audiencia', JvColors.azul, ''),
        ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: atajos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext c, int i) {
          final (IconData icono, String texto, Color color, String prompt) =
              atajos[i];
          return Material(
            color: cs.surfaceContainerLow,
            borderRadius: JvShapes.rPill,
            child: InkWell(
              borderRadius: JvShapes.rPill,
              onTap: () => texto == 'Audiencia'
                  ? c.push(Rutas.audiencia)
                  : c.push(
                      '${Rutas.chat}?prompt=${Uri.encodeComponent(prompt)}',
                    ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: JvShapes.rPill,
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icono, size: 14, color: color),
                    const SizedBox(width: 7),
                    Text(texto, style: JvText.chip),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// El briefing del día: una sola llamada, seis bloques.
///
/// El orden no es estético, es de triaje: primero lo que puede perderse hoy,
/// luego lo que el agente hizo de noche, luego el trabajo pendiente, y al final
/// lo informativo. Lo que un abogado necesita ver en los primeros dos segundos
/// va arriba.
///
/// `gate` decide el modo:
///   · `activation` → todavía no hay nada que vigilar; se muestra qué hacer.
///   · `quiet`      → hay casos pero hoy no pasó nada. Eso se dice, no se
///                    disfraza con secciones vacías.
///   · `rich`       → el día normal.
class _Briefing extends ConsumerWidget {
  const _Briefing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Briefing> b = ref.watch(briefingProvider);

    return b.when(
      loading: () => const _BriefingCargando(),
      // El proveedor ya degrada a vacío; este error es teórico y no debe
      // dejar el Inicio en rojo.
      error: (_, _) => const SizedBox.shrink(),
      data: (Briefing br) {
        if (br.compuerta == Compuerta.activacion) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const BloqueActivacion(),
              const SizedBox(height: 26),
              BloqueNovedades(inteligencia: br.inteligencia),
            ],
          );
        }

        final List<Widget> bloques = <Widget>[
          if (!br.atencion.vacia) BloqueImportante(atencion: br.atencion),
          if (br.movimientos.isNotEmpty)
            BloqueOvernight(movimientos: br.movimientos),
          if (br.atencion.pendientes.isNotEmpty)
            BloquePendientes(pendientes: br.atencion.pendientes),
          if (br.procesos.isNotEmpty) BloqueProcesos(procesos: br.procesos),
          BloqueEscudo(escudo: br.escudo),
          BloqueNovedades(inteligencia: br.inteligencia),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Un día tranquilo es una buena noticia, no un vacío. Decirlo
            // evita que el abogado crea que la app dejó de funcionar.
            if (br.compuerta == Compuerta.tranquila) ...<Widget>[
              const _DiaTranquilo(),
              const SizedBox(height: 22),
            ],
            for (int i = 0; i < bloques.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 26),
              bloques[i],
            ],
          ],
        );
      },
    );
  }
}

class _DiaTranquilo extends StatelessWidget {
  const _DiaTranquilo();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: JvColors.exitoFondo,
      borderRadius: JvShapes.rTarjeta,
      border: Border.all(color: JvColors.exito.withValues(alpha: 0.22)),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.check_circle_outline, size: 18, color: JvColors.exito),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            'Sin términos por vencer ni borradores esperándote. '
            'Todo revisado.',
            style: JvText.menor.copyWith(height: 1.5),
          ),
        ),
      ],
    ),
  );
}

/// Esqueleto mientras carga: mantiene la altura para que el Inicio no salte.
class _BriefingCargando extends StatelessWidget {
  const _BriefingCargando();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: List<Widget>.generate(
        3,
        (int i) => Container(
          height: 62,
          margin: const EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: JvShapes.rLista,
          ),
        ),
      ),
    );
  }
}

class _Recientes extends ConsumerWidget {
  const _Recientes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SesionChat>> sesiones = ref.watch(sesionesProvider);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return sesiones.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (List<SesionChat> lista) {
        if (lista.isEmpty) return const SizedBox.shrink();
        final List<SesionChat> recientes = lista.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Recientes', style: JvText.cuerpoFuerte),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: JvShapes.rLista,
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: recientes.map((SesionChat s) {
                  final bool ultima = s == recientes.last;
                  return InkWell(
                    onTap: () => context.push('${Rutas.chat}?sesion=${s.id}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: ultima
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: cs.surfaceContainerLow,
                                ),
                              ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: JvColors.txtTerciario,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              s.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JvText.cuerpoMedio.copyWith(fontSize: 14),
                            ),
                          ),
                          Text(s.cuando, style: JvText.menor),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Plan y cuota disponibles de un vistazo.
///
/// ⚠️ Informativo: sin botón de compra ni enlace a la web (Apple 3.1.1/3.1.3).
/// La cuota se pinta según `access.model`, que puede ser créditos o turnos
/// diarios: no se asume ninguno de los dos.
///
/// **Sí es tocable**: es el sitio donde cualquiera busca su facturación. Antes
/// no reaccionaba, y una píldora que habla del plan pero ignora el toque se lee
/// como un botón roto. Al tocarla se explica dónde se gestiona; no se vende.
class _ResumenCuenta extends StatelessWidget {
  const _ResumenCuenta({required this.me});

  final Me? me;

  @override
  Widget build(BuildContext context) {
    final Me? m = me;
    if (m == null) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: JvShapes.rPill,
      child: InkWell(
        borderRadius: JvShapes.rPill,
        onTap: () => MuroPlan.mostrar(
          context,
          motivo: BillingPolicy.motivoPara(m),
          me: m,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: m.esPago ? JvColors.exito : JvColors.termino,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Plan ${m.plan.toUpperCase()}',
                style: JvText.chip.copyWith(fontSize: 12.5),
              ),
              const Spacer(),
              Text(m.access.resumen, style: JvText.menor),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 15,
                color: JvColors.txtTerciario,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
