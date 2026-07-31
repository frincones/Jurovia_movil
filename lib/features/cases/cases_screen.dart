import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/models/caso.dart';
import '../../core/sync/refresh_policy.dart';
import '../../shared/widgets/estado_vista.dart';
import '../../shared/widgets/indicador_frescura.dart';

/// S08 · Lista de casos, con buscador y los 4 filtros del prototipo.
class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

/// Los filtros se traducen a parámetros del backend cuando existen allí.
///
/// `conTermino` no tiene equivalente en la API (el término se calcula al
/// serializar cada misión), así que ese sí se filtra sobre lo recibido.
enum _Filtro {
  todos('Todos'),
  conTermino('Con término'),
  vigilados('Vigilados'),
  archivados('Archivados');

  const _Filtro(this.etiqueta);
  final String etiqueta;

  String? get estado => this == _Filtro.archivados ? 'closed' : null;
  bool? get vigilancia => this == _Filtro.vigilados ? true : null;
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  _Filtro _filtro = _Filtro.todos;

  /// Lo que hay escrito ahora mismo en el campo.
  String _texto = '';

  /// Lo que ya se le pidió al servidor. Va por detrás de [_texto] el tiempo
  /// del *debounce*: sin esto se dispararía una consulta por cada tecla.
  String _consultado = '';

  Timer? _rebote;

  static const Duration _esperaTecleo = Duration(milliseconds: 350);

  @override
  void dispose() {
    _rebote?.cancel();
    super.dispose();
  }

  void _alEscribir(String v) {
    setState(() => _texto = v);
    _rebote?.cancel();
    _rebote = Timer(_esperaTecleo, () {
      if (!mounted) return;
      setState(() => _consultado = v);
    });
  }

  ConsultaCasos get _consulta => (
    texto: _consultado,
    estado: _filtro.estado,
    vigilancia: _filtro.vigilancia,
  );

  /// Único filtro que queda en el cliente: el resto lo resuelve el servidor.
  List<Caso> _filtrar(List<Caso> casos) => _filtro == _Filtro.conTermino
      ? casos.where((Caso c) => c.proximoTermino != null).toList()
      : casos;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Caso>> casos = ref.watch(
      casosFiltradosProvider(_consulta),
    );
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool buscando = _texto.trim() != _consultado.trim();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.menu, size: 20),
                        tooltip: 'Historial de conversaciones',
                        onPressed: abrirHistorial,
                      ),
                      Text('Casos', style: JvText.tituloSeccion),
                      const SizedBox(width: 10),
                      const IndicadorFrescura(clave: 'casos'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: _alEscribir,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (String v) {
                      _rebote?.cancel();
                      setState(() => _consultado = v);
                    },
                    style: JvText.cuerpoMedio,
                    decoration: InputDecoration(
                      hintText:
                          'Código, radicado, parte o texto del expediente…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      suffixIcon: buscando
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _Filtro.values.map((_Filtro f) {
                        final bool activo = f == _filtro;
                        return Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: GestureDetector(
                            onTap: () => setState(() => _filtro = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: activo
                                    ? JvColors.de(context).primario
                                    : cs.surfaceContainerLow,
                                borderRadius: JvShapes.rPill,
                                border: Border.all(
                                  color: activo
                                      ? JvColors.de(context).primario
                                      : cs.outline,
                                ),
                              ),
                              child: Text(
                                f.etiqueta,
                                style: JvText.chip.copyWith(
                                  color: activo
                                      ? Colors.white
                                      : JvColors.de(context).secundario,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: casos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => EstadoError(
                  onReintentar: () =>
                      ref.invalidate(casosFiltradosProvider(_consulta)),
                ),
                data: (List<Caso> lista) {
                  final List<Caso> visibles = _filtrar(lista);
                  if (visibles.isEmpty) {
                    final bool filtrando =
                        _consultado.trim().isNotEmpty ||
                        _filtro != _Filtro.todos;
                    return EstadoVacio(
                      icono: Icons.folder_open,
                      titulo: filtrando
                          ? 'Sin resultados'
                          : 'Todavía no tienes casos',
                      detalle: filtrando
                          ? 'Se buscó por nombre, código, radicado, partes y '
                                'dentro de los documentos. Prueba con otro '
                                'término o quita el filtro.'
                          : 'Los casos que trabajes con Jurovia aparecerán aquí.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref
                        ..invalidate(casosFiltradosProvider(_consulta))
                        ..invalidate(casosProvider);
                      ref.read(frescuraProvider.notifier).marcar('casos');
                    },
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        0,
                        18,
                        BarraFlotante.espacioContenido(context),
                      ),
                      itemCount: visibles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, int i) =>
                          _TarjetaCaso(caso: visibles[i]),
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

/// Píldora de estado con icono. Se comparte para que «Vigilando» y su
/// contrario («Falta el radicado») pesen lo mismo visualmente.
class _Pildora extends StatelessWidget {
  const _Pildora({
    required this.icono,
    required this.texto,
    required this.color,
    required this.fondo,
  });

  final IconData icono;
  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: fondo, borderRadius: JvShapes.rPill),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icono, size: 11, color: color),
        const SizedBox(width: 5),
        Text(
          texto,
          style: JvText.de(
            context,
          ).menor.copyWith(fontSize: 11.5, color: color),
        ),
      ],
    ),
  );
}

class _TarjetaCaso extends StatelessWidget {
  const _TarjetaCaso({required this.caso});

  final Caso caso;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final (Color fg, Color bg, String texto) = caso.archivado
        ? (JvColors.de(context).secundario, cs.surfaceContainerLow, 'Archivado')
        : caso.fallado
        ? (JvColors.de(context).secundario, cs.surfaceContainerLow, 'Fallado')
        : (JvColors.exito, JvColors.exitoFondo, 'Activo');

    return Material(
      color: cs.surface,
      borderRadius: JvShapes.rTarjeta,
      child: InkWell(
        borderRadius: JvShapes.rTarjeta,
        onTap: () => context.push('${Rutas.casos}/${caso.id}'),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: JvShapes.rTarjeta,
            border: Border.all(color: cs.outline),
            boxShadow: JvShapes.sombraTarjeta,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          caso.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JvText.cuerpoFuerte,
                        ),
                        if (caso.codigo != null ||
                            caso.radicado != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              if (caso.codigo != null) ...<Widget>[
                                Text(
                                  caso.codigo!,
                                  style: JvText.de(context).codigo,
                                ),
                                if (caso.radicado != null)
                                  Text(
                                    '  ·  ',
                                    style: JvText.de(context).radicado,
                                  ),
                              ],
                              if (caso.radicado != null)
                                Expanded(
                                  child: Text(
                                    caso.radicado!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: JvText.de(context).radicado,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (caso.partes.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            caso.partes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: JvText.de(context).menor,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
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
                      texto,
                      style: JvText.de(
                        context,
                      ).menor.copyWith(fontSize: 11, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  // El tag solo se pinta si la vigilancia es **verificable**:
                  // encendida Y con radicado. Encendida sin radicado no
                  // consulta nada, así que se dice lo que falta en vez de
                  // prometer una vigilancia que no ocurre.
                  if (caso.vigilanciaVerificable) ...<Widget>[
                    _Pildora(
                      icono: Icons.visibility_outlined,
                      texto: 'Vigilando',
                      color: JvColors.vigilancia,
                      fondo: JvColors.vigilanciaFondo,
                    ),
                    const SizedBox(width: 8),
                  ] else if (caso.vigilanciaActiva) ...<Widget>[
                    _Pildora(
                      icono: Icons.error_outline,
                      texto: 'Falta el radicado',
                      color: JvColors.termino,
                      fondo: JvColors.terminoFondo,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (caso.proximoTermino != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: caso.proximoTermino!.critico
                            ? JvColors.terminoFondo
                            : cs.surfaceContainerLow,
                        borderRadius: JvShapes.rPill,
                      ),
                      child: Text(
                        caso.proximoTermino!.etiqueta,
                        style: JvText.de(context).menor.copyWith(
                          fontSize: 11,
                          color: caso.proximoTermino!.critico
                              ? JvColors.termino
                              : JvColors.de(context).secundario,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      caso.juzgado ?? caso.materia ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JvText.de(context).menor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
