/// Bloques del **briefing del día** en el Inicio.
///
/// Cada bloque se borra solo cuando no tiene nada que decir: un Inicio lleno de
/// secciones vacías con «(0)» le enseña al abogado a no mirarlo. Lo que decide
/// el estado global —y el caso de arranque en frío— es `gate`, no el cliente.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/models/briefing.dart';

/// Título de sección con acción opcional a la derecha.
class TituloBloque extends StatelessWidget {
  const TituloBloque(this.texto, {super.key, this.accion, this.onAccion});

  final String texto;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Text(texto, style: JvText.cuerpoFuerte),
      const Spacer(),
      if (accion != null && onAccion != null)
        TextButton(onPressed: onAccion, child: Text(accion!)),
    ],
  );
}

/// Tarjeta contenedora estándar de los bloques.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, this.color, this.borde, this.padding});

  final Widget child;
  final Color? color;
  final Color? borde;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        borderRadius: JvShapes.rTarjeta,
        border: Border.all(color: borde ?? cs.outline),
      ),
      child: child,
    );
  }
}

// ───────────────────────────── 🛡️ Tu escudo ─────────────────────────────

/// Lo que Jurovia está cuidando ahora mismo.
///
/// Con cero procesos vigilados **no se muestran ceros**: tres «0» en fila se
/// leen como un reproche al abogado por no haber cargado nada. En su lugar se
/// dice qué hay que hacer para que el escudo exista.
class BloqueEscudo extends StatelessWidget {
  const BloqueEscudo({super.key, required this.escudo});

  final Escudo escudo;

  @override
  Widget build(BuildContext context) {
    if (escudo.aspiracional) {
      return _Tarjeta(
        color: JvColors.vigilanciaFondo,
        borde: JvColors.vigilancia.withValues(alpha: 0.22),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.shield_outlined,
              size: 20,
              color: JvColors.vigilancia,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tu escudo todavía no está armado',
                    style: JvText.cuerpoFuerte.copyWith(
                      fontSize: 14,
                      color: JvColors.vigilancia,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Registra el radicado de un proceso y Jurovia lo revisa a '
                    'diario: te avisa de cada actuación y de los términos que '
                    'empiecen a correr.',
                    style: JvText.de(context).menor.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _Tarjeta(
      child: Row(
        children: <Widget>[
          _Cifra(
            valor: '${escudo.vigilados}',
            etiqueta: 'vigilados',
            color: JvColors.vigilancia,
          ),
          if (escudo.diasSinVencer != null)
            _Cifra(
              valor: '${escudo.diasSinVencer}',
              etiqueta: 'días sin vencer',
              color: JvColors.exito,
            ),
          if (escudo.perdidos > 0)
            _Cifra(
              valor: '${escudo.perdidos}',
              etiqueta: escudo.perdidos == 1 ? 'perdido' : 'perdidos',
              color: JvColors.peligro,
            ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(valor, style: JvText.cifra.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(
          etiqueta,
          style: JvText.de(context).menor.copyWith(fontSize: 11.5),
        ),
      ],
    ),
  );
}

// ──────────────────────── 🔴 Esto es lo importante ────────────────────────

/// Términos por vencer y borradores esperando aprobación.
///
/// Es el bloque que justifica abrir la app: si algo se va a perder hoy, está
/// aquí arriba y no hay que buscarlo.
class BloqueImportante extends StatelessWidget {
  const BloqueImportante({super.key, required this.atencion});

  final Atencion atencion;

  @override
  Widget build(BuildContext context) {
    final List<TerminoBriefing> terms = atencion.terminos;
    final List<ItemAtencion> borradores = atencion.borradores;
    if (terms.isEmpty && borradores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TituloBloque('Esto es lo importante'),
        const SizedBox(height: 10),
        ...terms.take(4).map((TerminoBriefing t) => _FilaTerminoBriefing(t)),
        ...borradores
            .take(3)
            .map(
              (ItemAtencion b) => _FilaSimple(
                titulo: b.titulo,
                subtitulo: 'Borrador listo · requiere tu aprobación',
                icono: Icons.drafts_outlined,
                color: JvColors.purpura,
                matterId: b.matterId,
              ),
            ),
      ],
    );
  }
}

class _FilaTerminoBriefing extends StatelessWidget {
  const _FilaTerminoBriefing(this.t);

  final TerminoBriefing t;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = t.critico
        ? JvColors.termino
        : JvColors.de(context).secundario;
    final Color bg = t.critico ? JvColors.terminoFondo : cs.surfaceContainerLow;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          borderRadius: JvShapes.rLista,
          onTap: t.matterId == null
              ? null
              : () => context.push('${Rutas.casos}/${t.matterId}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.timer_outlined, size: 17, color: fg),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        t.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
                      ),
                      // Lo dedujo el agente: decirlo aquí evita que el abogado
                      // planee su semana sobre una fecha sin confirmar.
                      if (t.tentativo) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          'Fecha tentativa · confírmala en el expediente',
                          style: JvText.de(context).menor.copyWith(
                            fontSize: 11,
                            color: JvColors.termino,
                          ),
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
                    t.etiqueta,
                    style: JvText.de(
                      context,
                    ).menor.copyWith(fontSize: 11, color: fg),
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

class _FilaSimple extends StatelessWidget {
  const _FilaSimple({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    this.matterId,
    this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final String? matterId;

  /// Si se da, manda sobre [matterId].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final VoidCallback? accion =
        onTap ??
        (matterId == null
            ? null
            : () => context.push('${Rutas.casos}/$matterId'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          borderRadius: JvShapes.rLista,
          onTap: accion,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: <Widget>[
                Icon(icono, size: 17, color: color),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JvText.de(context).menor,
                      ),
                    ],
                  ),
                ),
                if (accion != null)
                  Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: JvColors.de(context).terciario,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── ✅ Tus pendientes ───────────────────────────

/// Tareas abiertas del despacho (`tasks`), no términos procesales.
class BloquePendientes extends StatelessWidget {
  const BloquePendientes({super.key, required this.pendientes});

  final List<ItemAtencion> pendientes;

  @override
  Widget build(BuildContext context) {
    if (pendientes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TituloBloque('Tus pendientes'),
        const SizedBox(height: 10),
        ...pendientes
            .take(5)
            .map(
              (ItemAtencion p) => _FilaSimple(
                titulo: p.titulo,
                subtitulo: p.prioridad == 'alta'
                    ? 'Prioridad alta'
                    : 'Tarea abierta',
                icono: Icons.check_circle_outline,
                color: p.prioridad == 'alta'
                    ? JvColors.termino
                    : JvColors.de(context).secundario,
                matterId: p.matterId,
              ),
            ),
      ],
    );
  }
}

// ───────────────────── 🌙 Mientras no estabas ─────────────────────

/// Lo que el agente avanzó en las últimas 24 horas.
///
/// Es la prueba de que Jurovia trabaja cuando el abogado no está mirando: sin
/// este bloque, la vigilancia es una promesa invisible.
class BloqueOvernight extends StatelessWidget {
  const BloqueOvernight({super.key, required this.movimientos});

  final List<Movimiento> movimientos;

  @override
  Widget build(BuildContext context) {
    if (movimientos.isEmpty) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TituloBloque('Mientras no estabas'),
        const SizedBox(height: 10),
        _Tarjeta(
          padding: EdgeInsets.zero,
          child: Column(
            children: movimientos.take(5).map((Movimiento m) {
              final bool ultimo = m == movimientos.take(5).last;
              return InkWell(
                onTap: m.matterId.isEmpty
                    ? null
                    : () => context.push('${Rutas.casos}/${m.matterId}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: ultimo
                        ? null
                        : Border(
                            bottom: BorderSide(color: cs.surfaceContainerLow),
                          ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.bolt_outlined,
                        size: 16,
                        color: JvColors.purpura,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              m.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JvText.cuerpoMedio.copyWith(fontSize: 14),
                            ),
                            if (m.resumen.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                m.resumen,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: JvText.de(
                                  context,
                                ).menor.copyWith(height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ──────────────────── 📁 Procesos por prioridad ────────────────────

/// Los procesos ordenados por el `score` del servidor.
class BloqueProcesos extends StatelessWidget {
  const BloqueProcesos({super.key, required this.procesos});

  final List<ProcesoPrioritario> procesos;

  @override
  Widget build(BuildContext context) {
    if (procesos.isEmpty) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TituloBloque(
          'Tus procesos',
          accion: 'Ver todos',
          onAccion: () => context.go(Rutas.casos),
        ),
        const SizedBox(height: 10),
        ...procesos.take(5).map((ProcesoPrioritario p) {
          final String? term = p.etiquetaTermino;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: cs.surface,
              borderRadius: JvShapes.rLista,
              child: InkWell(
                borderRadius: JvShapes.rLista,
                onTap: () => context.push('${Rutas.casos}/${p.id}'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: JvShapes.rLista,
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: <Widget>[
                                if (p.codigo != null) ...<Widget>[
                                  Text(
                                    p.codigo!,
                                    style: JvText.de(context).codigo,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Mismo criterio que la lista de casos: solo
                                // se dice «vigilando» si de verdad se vigila.
                                if (p.vigilanciaVerificable)
                                  const Icon(
                                    Icons.visibility_outlined,
                                    size: 12,
                                    color: JvColors.vigilancia,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (term != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: p.urgente
                                ? JvColors.terminoFondo
                                : cs.surfaceContainerLow,
                            borderRadius: JvShapes.rPill,
                          ),
                          child: Text(
                            term,
                            style: JvText.de(context).menor.copyWith(
                              fontSize: 11,
                              color: p.urgente
                                  ? JvColors.termino
                                  : JvColors.de(context).secundario,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────── 📰 Novedades de tu área ───────────────────────

/// Capa 1 del briefing: sirve aunque el abogado no tenga ni un caso cargado.
///
/// El servidor genera **temas**, nunca fuentes: no hay números de sentencia ni
/// fechas de vigencia inventadas. Al tocar un tema se abre el chat con la
/// consulta ya escrita y es el agente quien busca y verifica las fuentes
/// reales. Por eso el pie del bloque lo dice explícitamente.
class BloqueNovedades extends StatelessWidget {
  const BloqueNovedades({super.key, required this.inteligencia});

  final InteligenciaDelDia? inteligencia;

  static void _preguntar(BuildContext context, String consulta) {
    context.push('${Rutas.chat}?prompt=${Uri.encodeComponent(consulta)}');
  }

  @override
  Widget build(BuildContext context) {
    final InteligenciaDelDia? intel = inteligencia;
    if (intel == null || intel.vacia) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TituloBloque('Novedades de tu área'),
        const SizedBox(height: 10),
        _Tarjeta(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              ...intel.temas.map(
                (TemaDelDia t) => _FilaTema(
                  tema: t,
                  ultima: t == intel.temas.last && intel.tip == null,
                  onTap: () => _preguntar(context, t.askQuery),
                ),
              ),
              if (intel.tip != null)
                _FilaTema(
                  tema: intel.tip!,
                  ultima: true,
                  esTip: true,
                  onTap: () => _preguntar(context, intel.tip!.askQuery),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Son temas para consultar, no fuentes citables: al tocar uno, '
            'Jurovia busca y verifica la norma o la sentencia real.',
            style: JvText.de(context).menor.copyWith(
              fontSize: 11,
              height: 1.45,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaTema extends StatelessWidget {
  const _FilaTema({
    required this.tema,
    required this.ultima,
    required this.onTap,
    this.esTip = false,
  });

  final TemaDelDia tema;
  final bool ultima;
  final VoidCallback onTap;
  final bool esTip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final IconData icono = esTip
        ? Icons.lightbulb_outline
        : switch (tema.tipo) {
            'norma' => Icons.gavel_outlined,
            'consulta' => Icons.help_outline,
            _ => Icons.article_outlined,
          };

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: esTip ? cs.surfaceContainerLow : null,
          border: ultima
              ? null
              : Border(bottom: BorderSide(color: cs.surfaceContainerLow)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icono,
              size: 16,
              color: esTip ? JvColors.verificado : JvColors.purpura,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tema.titulo,
                    style: JvText.cuerpoMedio.copyWith(fontSize: 14),
                  ),
                  if (tema.resumen.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      tema.resumen,
                      style: JvText.de(context).menor.copyWith(height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.north_east,
              size: 14,
              color: JvColors.de(context).terciario,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── 🌱 Arranque en frío ──────────────────────────

/// Qué mostrar cuando `gate == activation`: todavía no hay nada que vigilar.
///
/// El Inicio **nunca** puede quedar en blanco. Un abogado que abre la app el
/// primer día y ve una pantalla vacía concluye que no sirve, y no vuelve. Aquí
/// se le dice exactamente qué hacer para que empiece a servir.
class BloqueActivacion extends StatelessWidget {
  const BloqueActivacion({super.key});

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, String, String)> pasos =
        <(IconData, String, String, String)>[
          (
            Icons.gavel_outlined,
            'Registra un proceso',
            'Pega el radicado y Jurovia lo vigila a diario por ti.',
            'Quiero vigilar un proceso. Mi radicado es: ',
          ),
          (
            Icons.upload_file_outlined,
            'Sube un documento',
            'Un contrato, una demanda o una sentencia: te la analizo.',
            'Voy a subir un documento para que lo analices.',
          ),
          (
            Icons.help_outline,
            'Hazme una consulta',
            'Pregunta lo que estés trabajando ahora mismo.',
            '',
          ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TituloBloque('Empieza por aquí'),
        const SizedBox(height: 10),
        ...pasos.map(
          ((IconData, String, String, String) p) => _FilaSimple(
            titulo: p.$2,
            subtitulo: p.$3,
            icono: p.$1,
            color: JvColors.purpura,
            onTap: () => context.push(
              p.$4.isEmpty
                  ? Rutas.chat
                  : '${Rutas.chat}?prompt=${Uri.encodeComponent(p.$4)}',
            ),
          ),
        ),
      ],
    );
  }
}
