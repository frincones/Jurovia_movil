import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/models/caso.dart';
import '../../shared/widgets/aurora_button.dart';
import '../../shared/widgets/estado_vista.dart';
import '../../shared/widgets/fila_termino.dart';

/// S09 · Detalle de caso: término, etapa, actuaciones y documentos.
class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.matterId});

  final String matterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Caso> caso = ref.watch(casoProvider(matterId));

    return Scaffold(
      appBar: AppBar(
        title: caso.when(
          loading: () => const Text('Caso'),
          error: (_, _) => const Text('Caso'),
          data: (Caso c) => Column(
            children: <Widget>[
              Text(
                c.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JvText.cuerpoFuerte,
              ),
              if (c.codigo != null || c.radicado != null)
                Text(
                  <String>[?c.codigo, ?c.radicado].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JvText.radicado.copyWith(fontSize: 10.5),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: caso.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => EstadoError(
            onReintentar: () => ref.invalidate(casoProvider(matterId)),
          ),
          data: (Caso c) => _Contenido(caso: c, matterId: matterId),
        ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.caso, required this.matterId});

  final Caso caso;
  final String matterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Actuacion>> timeline = ref.watch(
      timelineCasoProvider(matterId),
    );
    final AsyncValue<List<Map<String, dynamic>>> docs = ref.watch(
      documentosCasoProvider(matterId),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(casoProvider(matterId))
          ..invalidate(timelineCasoProvider(matterId))
          ..invalidate(documentosCasoProvider(matterId));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _Metrica(
                  etiqueta: 'Término',
                  valor: caso.proximoTermino?.etiqueta ?? '—',
                  detalle: caso.proximoTermino?.titulo ?? 'Sin término activo',
                  acento: (caso.proximoTermino?.critico ?? false)
                      ? JvColors.termino
                      : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Metrica(
                  etiqueta: 'Progreso',
                  valor: '${caso.progreso}%',
                  detalle: caso.materia ?? '',
                ),
              ),
            ],
          ),

          if (caso.proximaAccion != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: JvColors.terminoFondo,
                borderRadius: JvShapes.rTarjeta,
                border: Border.all(
                  color: JvColors.termino.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.flag_outlined,
                    size: 17,
                    color: JvColors.termino,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('SIGUIENTE PASO', style: JvText.etiqueta),
                        const SizedBox(height: 4),
                        Text(caso.proximaAccion!, style: JvText.cuerpoMedio),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text('El proceso', style: JvText.cuerpoFuerte),
          const SizedBox(height: 10),
          _FichaProceso(caso: caso),

          ..._terminosDelCaso(ref, matterId),

          const SizedBox(height: 22),
          _Vigilancia(caso: caso, matterId: matterId),

          const SizedBox(height: 24),
          Text('Actuaciones', style: JvText.cuerpoFuerte),
          const SizedBox(height: 12),
          timeline.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              'No se pudieron cargar las actuaciones.',
              style: JvText.menor,
            ),
            data: (List<Actuacion> lista) => lista.isEmpty
                ? Text('Sin actuaciones registradas.', style: JvText.menor)
                : _Timeline(actuaciones: lista),
          ),

          const SizedBox(height: 24),
          Text('Documentos', style: JvText.cuerpoFuerte),
          const SizedBox(height: 10),
          docs.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (List<Map<String, dynamic>> lista) => lista.isEmpty
                ? Text('Sin documentos todavía.', style: JvText.menor)
                : Column(
                    children: lista.map((Map<String, dynamic> d) {
                      final String nombre =
                          d['name'] as String? ??
                          d['filename'] as String? ??
                          'Documento';
                      return _FilaDocumento(
                        nombre: nombre,
                        onTap: () =>
                            context.push('${Rutas.documento}/${d['id'] ?? ''}'),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),
          AuroraButton(
            texto: 'Trabajar este caso con Jurovia',
            onPressed: () => context.push('${Rutas.chat}?caso=$matterId'),
          ),
          if (caso.proximaAccion != null) ...<Widget>[
            const SizedBox(height: 10),
            // F3.07 · El workflow del pack corre paso a paso con el MISMO
            // contrato SSE que el chat, así que se abre en la pantalla de chat.
            SecondaryButton(
              texto: 'Ejecutar el flujo del caso',
              onPressed: () =>
                  context.push('${Rutas.chat}?caso=$matterId&workflow=1'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Términos de **este** caso, tomados de la agenda general.
///
/// Se filtra en el cliente a propósito: `/api/deadlines` ya devuelve la agenda
/// completa (que el Inicio necesita de todas formas) y trae `expId`, así que
/// pedirla otra vez por caso sería una llamada de más para el mismo dato.
List<Widget> _terminosDelCaso(WidgetRef ref, String matterId) {
  final List<Termino> mios = ref
      .watch(terminosProvider)
      .maybeWhen(data: (List<Termino> l) => l, orElse: () => const <Termino>[])
      .where((Termino t) => t.matterId == matterId)
      .toList();

  if (mios.isEmpty) return const <Widget>[];

  return <Widget>[
    const SizedBox(height: 24),
    Text('Términos', style: JvText.cuerpoFuerte),
    const SizedBox(height: 10),
    ...mios.map((Termino t) => FilaTermino(termino: t, navegable: false)),
  ];
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.etiqueta,
    required this.valor,
    required this.detalle,
    this.acento,
  });

  final String etiqueta;
  final String valor;
  final String detalle;
  final Color? acento;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: acento?.withValues(alpha: 0.08) ?? cs.surface,
        borderRadius: JvShapes.rTarjeta,
        border: Border.all(
          color: acento?.withValues(alpha: 0.22) ?? cs.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            etiqueta.toUpperCase(),
            style: JvText.etiqueta.copyWith(color: acento),
          ),
          const SizedBox(height: 6),
          Text(valor, style: JvText.cifra),
          if (detalle.isNotEmpty)
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JvText.menor,
            ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.actuaciones});

  final List<Actuacion> actuaciones;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: actuaciones.map((Actuacion a) {
        final Color punto = a.corriendoTermino
            ? JvColors.termino
            : JvColors.purpura;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: punto,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2.5,
                      ),
                    ),
                  ),
                  Expanded(child: Container(width: 2, color: cs.outline)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(a.fechaLegible, style: JvText.menor),
                      const SizedBox(height: 2),
                      Text(a.titulo, style: JvText.cuerpoMedio),
                      if (a.detalle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(a.detalle!, style: JvText.secundario),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({required this.nombre, required this.onTap});

  final String nombre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        child: InkWell(
          onTap: onTap,
          borderRadius: JvShapes.rLista,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.description_outlined,
                  size: 17,
                  color: JvColors.txtSecundario,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JvText.cuerpoMedio.copyWith(fontSize: 13.5),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 17,
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

/// Datos del expediente: radicado, juzgado, partes y materia.
class _FichaProceso extends StatelessWidget {
  const _FichaProceso({required this.caso});

  final Caso caso;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<(String, String?, bool)> filas = <(String, String?, bool)>[
      // El código es el nombre corto del expediente: va primero y se puede
      // seleccionar para copiarlo a un correo o dictarlo por teléfono.
      ('Código', caso.codigo, true),
      ('Radicado', caso.radicado, true),
      ('Juzgado', caso.juzgado, false),
      ('Demandante', caso.demandante, false),
      ('Demandado', caso.demandado, false),
      ('Materia', caso.materia, false),
    ];
    final List<(String, String?, bool)> visibles = filas
        .where(((String, String?, bool) f) => f.$2 != null)
        .toList();

    if (visibles.isEmpty) {
      return Text(
        'Este caso todavía no tiene datos del expediente. Puedes pedírselos a '
        'Jurovia o completarlos desde la web.',
        style: JvText.menor.copyWith(height: 1.5),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: visibles.map(((String, String?, bool) f) {
          final bool ultima = f == visibles.last;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              border: ultima
                  ? null
                  : Border(bottom: BorderSide(color: cs.surfaceContainerLow)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: 100, child: Text(f.$1, style: JvText.menor)),
                Expanded(
                  child: SelectableText(
                    f.$2!,
                    // Los identificadores van en monoespaciada: se copian y se
                    // comparan dígito a dígito.
                    style: !f.$3
                        ? JvText.cuerpoMedio
                        : f.$1 == 'Código'
                        ? JvText.codigo
                        : JvText.radicado,
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

/// Vigilancia judicial del proceso (autopilot).
///
/// Muestra si Jurovia está revisando el expediente a diario y cuándo lo hizo
/// por última vez. Encender o apagar la vigilancia se hace en la web: aquí solo
/// se informa, para no duplicar una configuración con consecuencias.
class _Vigilancia extends StatelessWidget {
  const _Vigilancia({required this.caso, required this.matterId});

  final Caso caso;
  final String matterId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // Tres estados, no dos. El intermedio —vigilancia encendida pero sin
    // radicado— es el que importa: no hay nada que consultar en la Rama
    // Judicial, así que decir «vigilancia activa» sería falso y el abogado
    // esperaría avisos que nunca van a llegar.
    final bool vigilando = caso.vigilanciaVerificable;
    final bool incompleta = caso.vigilanciaActiva && !vigilando;

    final (Color acento, Color fondo, IconData icono, String titulo) = vigilando
        ? (
            JvColors.vigilancia,
            JvColors.vigilanciaFondo,
            Icons.visibility,
            'Vigilancia judicial activa',
          )
        : incompleta
        ? (
            JvColors.termino,
            JvColors.terminoFondo,
            Icons.error_outline,
            'Falta el radicado',
          )
        : (
            JvColors.txtTerciario,
            cs.surface,
            Icons.visibility_off_outlined,
            'Sin vigilancia',
          );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: JvShapes.rTarjeta,
        border: Border.all(
          color: vigilando || incompleta
              ? acento.withValues(alpha: 0.25)
              : cs.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icono, size: 18, color: acento),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: JvText.cuerpoFuerte.copyWith(
                    fontSize: 14,
                    color: vigilando || incompleta ? acento : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vigilando
                ? 'Jurovia revisa este proceso a diario y te avisa de cada '
                      'actuación nueva y de los términos que empiecen a correr. '
                      'Última vez: ${caso.ultimaRevisionLegible}.'
                : incompleta
                ? 'La vigilancia está encendida, pero este caso no tiene número '
                      'de radicado. Sin él no hay expediente que consultar en la '
                      'Rama Judicial: registra el radicado desde Jurovia en el '
                      'navegador y la vigilancia empieza sola.'
                : 'Este proceso no se está vigilando. Actívalo desde Jurovia en '
                      'el navegador para recibir avisos de cada movimiento.',
            style: JvText.menor.copyWith(height: 1.5),
          ),
          if (caso.hechosClave != null) ...<Widget>[
            const SizedBox(height: 14),
            Text('HECHOS CLAVE', style: JvText.etiqueta),
            const SizedBox(height: 6),
            Text(caso.hechosClave!, style: JvText.secundario),
          ],
        ],
      ),
    );
  }
}
