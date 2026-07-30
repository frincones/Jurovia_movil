import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compliance/billing/billing_policy.dart';
import '../../../compliance/billing/muro_plan.dart';
import '../../../compliance/legal/disclaimer.dart';
import '../../../core/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/widgets/jurovia_logo.dart';
import '../../../shared/widgets/verified_chip.dart';

/// Burbuja del usuario: gradiente púrpura→azul, esquina inferior derecha viva.
class BurbujaUsuario extends StatelessWidget {
  const BurbujaUsuario({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: const BoxDecoration(
            gradient: JvColors.purpuraAzul,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: SelectableText(
            texto,
            style: JvText.cuerpoMedio.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Respuesta del agente, con todas sus piezas.
class BurbujaAgente extends StatelessWidget {
  const BurbujaAgente({
    super.key,
    required this.mensaje,
    required this.onReportar,
    required this.onAbrirDocumento,
    required this.onHook,
    this.onReintentar,
  });

  final Mensaje mensaje;
  final VoidCallback onReportar;
  final void Function(Artefacto) onAbrirDocumento;
  final void Function(HookAccion) onHook;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final EstadoMensaje estado = mensaje.clasificar();

    if (estado == EstadoMensaje.huerfano) {
      return _Huerfano(onReintentar: onReintentar);
    }

    final bool generando =
        estado == EstadoMensaje.generando && !mensaje.tieneContenido;
    final bool terminado = mensaje.status == 'complete';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Cabecera(mensaje: mensaje, generando: generando),

        if (mensaje.pasos.isNotEmpty && !terminado) ...<Widget>[
          const SizedBox(height: 10),
          _Actividad(pasos: mensaje.pasos),
        ],

        if (mensaje.tieneContenido) ...<Widget>[
          const SizedBox(height: 11),
          SelectableText(mensaje.texto, style: JvText.cuerpo),
        ],

        if (mensaje.fuentes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _Fuentes(fuentes: mensaje.fuentes),
        ],

        for (final Artefacto a in mensaje.artefactos) ...<Widget>[
          const SizedBox(height: 12),
          TarjetaDocumento(artefacto: a, onAbrir: () => onAbrirDocumento(a)),
        ],

        if (mensaje.error != null) ...<Widget>[
          const SizedBox(height: 11),
          _Aviso(texto: mensaje.error!, bloqueo: mensaje.bloqueado),
        ],

        if (terminado && mensaje.tieneContenido) ...<Widget>[
          const SizedBox(height: 10),
          _Acciones(texto: mensaje.texto, onReportar: onReportar),
          const SizedBox(height: 8),
          // AuditCheck C8.8 + C8.17 — no se quita.
          const AiLabel(),
        ],

        if (mensaje.hooks.isNotEmpty && terminado) ...<Widget>[
          const SizedBox(height: 12),
          _Hooks(hooks: mensaje.hooks, onHook: onHook),
        ],
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.mensaje, required this.generando});

  final Mensaje mensaje;
  final bool generando;

  @override
  Widget build(BuildContext context) {
    final String etiqueta = generando
        ? 'Consultando fuentes oficiales'
        : mensaje.segundosPensando != null
        ? 'Pensó durante ${mensaje.segundosPensando} s'
        : 'Jurovia';

    return Row(
      children: <Widget>[
        const AgentAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            etiqueta,
            overflow: TextOverflow.ellipsis,
            style: JvText.menor.copyWith(
              color: generando ? JvColors.purpura : JvColors.txtTerciario,
            ),
          ),
        ),
        if (generando) ...<Widget>[
          const SizedBox(width: 8),
          const PuntosPensando(),
        ],
      ],
    );
  }
}

/// Los 3 puntos del prototipo (`jvPulse`), desfase 0 / .15 / .3 s.
class PuntosPensando extends StatefulWidget {
  const PuntosPensando({super.key});

  @override
  State<PuntosPensando> createState() => _PuntosPensandoState();
}

class _PuntosPensandoState extends State<PuntosPensando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: JvMotion.pulse,
  )..repeat();

  static const List<Color> _colores = <Color>[
    JvColors.rosa,
    JvColors.magenta,
    JvColors.azul,
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _punto(Color c, double opacidad) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.only(right: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: opacidad),
      shape: BoxShape.circle,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Accesibilidad: si el sistema pide menos movimiento, se muestran fijos.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: _colores.map((Color c) => _punto(c, 1)).toList(),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(3, (int i) {
          final double t = (_c.value + i * 0.15) % 1.0;
          final double o =
              0.35 + 0.65 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
          return _punto(_colores[i], o);
        }),
      ),
    );
  }
}

/// Timeline de actividad del agente mientras trabaja.
class _Actividad extends StatelessWidget {
  const _Actividad({required this.pasos});

  final List<PasoActividad> pasos;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: JvShapes.rCampo,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pasos.take(5).map((PasoActividad p) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Icon(
                  p.terminado
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 13,
                  color: p.terminado ? JvColors.exito : JvColors.txtTerciario,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: JvText.menor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Fuentes extends StatelessWidget {
  const _Fuentes({required this.fuentes});

  final List<Fuente> fuentes;

  @override
  Widget build(BuildContext context) {
    final List<Fuente> verificadas = fuentes
        .where((Fuente f) => f.verificada)
        .toList();
    final List<Fuente> consultadas = fuentes
        .where((Fuente f) => !f.verificada)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (verificadas.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.verified_outlined,
                size: 13,
                color: JvColors.verificado,
              ),
              const SizedBox(width: 6),
              Text(
                'FUENTES VERIFICADAS',
                style: JvText.etiqueta.copyWith(color: JvColors.verificadoTxt),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...verificadas.map(
            (Fuente f) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: SourceCard(titulo: f.titulo, detalle: f.detalle),
            ),
          ),
        ],
        if (consultadas.isNotEmpty) ...<Widget>[
          if (verificadas.isNotEmpty) const SizedBox(height: 6),
          Text('FUENTES CONSULTADAS', style: JvText.etiqueta),
          const SizedBox(height: 8),
          // Sin dorado: no están contrastadas contra fuente oficial.
          ...consultadas.map(
            (Fuente f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _FuenteSimple(fuente: f),
            ),
          ),
        ],
      ],
    );
  }
}

class _FuenteSimple extends StatelessWidget {
  const _FuenteSimple({required this.fuente});

  final Fuente fuente;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: JvShapes.rCampo,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.link, size: 15, color: JvColors.txtTerciario),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              fuente.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JvText.menor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del documento generado por el agente.
class TarjetaDocumento extends StatelessWidget {
  const TarjetaDocumento({
    super.key,
    required this.artefacto,
    required this.onAbrir,
  });

  final Artefacto artefacto;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: JvShapes.rTarjeta,
        border: Border.all(color: cs.outline),
        boxShadow: JvShapes.sombraTarjeta,
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: cs.outline),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: JvColors.txtSecundario,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        artefacto.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JvText.documentoTitulo.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(artefacto.subtitulo, style: JvText.menor),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: onAbrir,
                    style: FilledButton.styleFrom(
                      backgroundColor: JvColors.purpura,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: Text(
                      'Abrir y editar',
                      style: JvText.boton.copyWith(fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hooks extends StatelessWidget {
  const _Hooks({required this.hooks, required this.onHook});

  final List<HookAccion> hooks;
  final void Function(HookAccion) onHook;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: hooks.map((HookAccion h) {
        return Material(
          color: cs.surface,
          borderRadius: JvShapes.rPill,
          child: InkWell(
            onTap: () => onHook(h),
            borderRadius: JvShapes.rPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: JvShapes.rPill,
                border: Border.all(color: cs.outline),
              ),
              child: Text(h.etiqueta, style: JvText.chip),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Copiar · Reportar. El reporte es requisito de tienda (C8.11 / A3.1).
class _Acciones extends StatelessWidget {
  const _Acciones({required this.texto, required this.onReportar});

  final String texto;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _BotonIcono(
          icono: Icons.copy_rounded,
          etiqueta: 'Copiar respuesta',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: texto));
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Respuesta copiada')));
          },
        ),
        const SizedBox(width: 6),
        _BotonIcono(
          icono: Icons.flag_outlined,
          etiqueta: 'Reportar esta respuesta',
          onTap: onReportar,
        ),
      ],
    );
  }
}

class _BotonIcono extends StatelessWidget {
  const _BotonIcono({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: etiqueta,
      child: Semantics(
        button: true,
        label: etiqueta,
        child: Material(
          color: cs.surface,
          shape: CircleBorder(side: BorderSide(color: cs.outline)),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icono, size: 15, color: JvColors.txtSecundario),
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends ConsumerWidget {
  const _Aviso({required this.texto, required this.bloqueo});

  final String texto;
  final bool bloqueo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Al bloquear por cuota se INFORMA, no se vende: sin botón ni enlace de
    // compra (Apple 3.1.1 / 3.1.3).
    final Color color = bloqueo ? JvColors.termino : JvColors.peligro;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: JvShapes.rCampo,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                bloqueo ? Icons.hourglass_empty : Icons.error_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  texto,
                  style: JvText.menor.copyWith(color: color, height: 1.5),
                ),
              ),
            ],
          ),
          // «Se te acabó la cuota» deja al abogado con la pregunta obvia sin
          // responder. Esto la responde: explica dónde se gestiona el plan.
          // No es un botón de compra — abre una explicación y se cierra.
          if (bloqueo)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: color,
                ),
                onPressed: () => MuroPlan.mostrar(
                  context,
                  motivo: MotivoMuro.sinCuota,
                  me: ref.read(meProvider).valueOrNull,
                  detalle: texto,
                ),
                child: const Text('¿Por qué?'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Turno que quedó a medias y nadie va a terminar (§11.4).
class _Huerfano extends StatelessWidget {
  const _Huerfano({this.onReintentar});

  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: JvShapes.rTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: JvColors.txtTerciario,
              ),
              const SizedBox(width: 8),
              Text('Esta respuesta no se completó.', style: JvText.menor),
            ],
          ),
          if (onReintentar != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
