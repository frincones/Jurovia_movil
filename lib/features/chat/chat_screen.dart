import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compliance/billing/billing_policy.dart';
import '../../compliance/billing/muro_plan.dart';
import '../../compliance/reporting/report_sheet.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/models/chat.dart';
import '../../shared/models/me.dart';
import '../../shared/widgets/jurovia_logo.dart';
import 'attachments.dart';
import 'chat_controller.dart';
import 'dictation.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';

/// S06 · Chat con el agente.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.sessionId,
    this.matterId,
    this.promptInicial,
    this.editArtifactId,
    this.seleccion,
    this.lanzarWorkflow = false,
  });

  final String? sessionId;
  final String? matterId;
  final String? promptInicial;

  /// Documento que se esta editando (llega desde el visor).
  final String? editArtifactId;

  /// Fragmento seleccionado en ese documento.
  final String? seleccion;

  /// Ejecutar el workflow del caso en lugar de enviar un turno (F3.07).
  final bool lanzarWorkflow;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  bool _promptEnviado = false;

  Adjunto? _adjunto;
  bool _subiendoAdjunto = false;

  Dictado? _dictado;
  bool _grabando = false;
  bool _transcribiendo = false;
  int _segundosGrabando = 0;
  Timer? _cronometro;

  @override
  void dispose() {
    _cronometro?.cancel();
    _dictado?.liberar();
    _scroll.dispose();
    super.dispose();
  }

  // ── Adjuntos (F3.22 / F3.23) ────────────────────────────────────────
  Future<void> _adjuntar() async {
    final Adjunto? a = await SelectorAdjuntos.mostrar(context);
    if (a == null || !mounted) return;
    setState(() {
      _adjunto = a;
      _subiendoAdjunto = true;
    });

    // Se sube al backend antes de mandar el turno: el agente recibe el id.
    final String? id = await _subirAdjunto(a);
    if (!mounted) return;
    setState(() => _subiendoAdjunto = false);
    if (id == null) {
      setState(() => _adjunto = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos subir el archivo.')),
      );
    } else {
      _documentoId = id;
    }
  }

  String? _documentoId;

  Future<String?> _subirAdjunto(Adjunto a) async {
    try {
      final FormData form = FormData.fromMap(<String, dynamic>{
        'file': await MultipartFile.fromFile(a.ruta, filename: a.nombre),
      });
      final Response<dynamic> r = await ref
          .read(apiClientProvider)
          .dio
          .post<dynamic>(
            '/api/documents',
            data: form,
            options: Options(contentType: 'multipart/form-data'),
          );
      final dynamic d = r.data;
      if (d is Map) return (d['id'] ?? d['document_id']) as String?;
      return null;
    } on Object {
      return null;
    }
  }

  // ── Dictado por voz (F3.24) ─────────────────────────────────────────
  Future<void> _alternarDictado() async {
    if (_grabando) return _detenerDictado();

    _dictado ??= Dictado(ref.read(apiClientProvider));
    final bool ok = await _dictado!.iniciar();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitamos permiso del micrófono para dictar.'),
        ),
      );
      return;
    }
    setState(() {
      _grabando = true;
      _segundosGrabando = 0;
    });
    _cronometro = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _segundosGrabando++),
    );
  }

  Future<void> _detenerDictado() async {
    _cronometro?.cancel();
    setState(() {
      _grabando = false;
      _transcribiendo = true;
    });
    final String? texto = await _dictado?.detenerYTranscribir();
    if (!mounted) return;
    setState(() => _transcribiendo = false);
    if (texto != null && texto.trim().isNotEmpty) {
      _textoDictado = texto.trim();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entendimos el dictado.')),
      );
    }
  }

  String? _textoDictado;

  Future<void> _cancelarDictado() async {
    _cronometro?.cancel();
    await _dictado?.cancelar();
    if (mounted) setState(() => _grabando = false);
  }

  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _enviar(String texto) {
    final bool ok = ref
        .read(chatControllerProvider(widget.sessionId).notifier)
        .enviar(
          texto,
          matterId: widget.matterId,
          documentIds: _documentoId == null ? null : <String>[_documentoId!],
          editArtifactId: widget.editArtifactId,
          seleccion: widget.seleccion,
        );
    if (!ok) {
      // Sin consentimiento de IA no hay token y no se puede invocar al agente.
      context.go(Rutas.consentimientoIa);
      return;
    }
    setState(() {
      _adjunto = null;
      _documentoId = null;
    });
    _alFinal();
  }

  /// Convierte la conversación en caso y lo confirma con el código.
  ///
  /// El código (`JUR-XXXX-XXXX`) es lo que el abogado va a usar para volver a
  /// encontrarlo, así que se muestra en la confirmación, no solo un «listo».
  Future<void> _promoverACaso() async {
    final CasoDelChat? c = await ref
        .read(chatControllerProvider(widget.sessionId).notifier)
        .promoverACaso();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          c == null
              ? 'No se pudo crear el caso. Inténtalo otra vez.'
              : 'Caso creado${c.codigo == null ? '' : ' · ${c.codigo}'}',
        ),
        action: c == null
            ? null
            : SnackBarAction(
                label: 'Abrir',
                onPressed: () => context.push('${Rutas.casos}/${c.matterId}'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatState estado = ref.watch(
      chatControllerProvider(widget.sessionId),
    );
    final Me? me = ref.watch(meProvider).valueOrNull;

    // `access.blocked` se parseaba y nunca se usaba: el usuario escribía, envía
    // y solo entonces descubría por SSE que estaba bloqueado —una ida y vuelta
    // perdida y la peor forma de enterarse. Ahora se dice antes de escribir.
    final bool sinCuota = me?.access.blocked ?? false;

    ref.listen(chatControllerProvider(widget.sessionId), (_, _) => _alFinal());

    // Prompt que llega desde Inicio o desde un caso: se envía una sola vez.
    if (!_promptEnviado && !estado.cargando) {
      if (widget.lanzarWorkflow && widget.matterId != null) {
        _promptEnviado = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(chatControllerProvider(widget.sessionId).notifier)
              .ejecutarWorkflow(widget.matterId!);
        });
      } else if (widget.promptInicial != null) {
        _promptEnviado = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _enviar(widget.promptInicial!),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          children: <Widget>[
            const JuroviaLogo(),
            if (estado.tituloSesion != null)
              Text(
                estado.tituloSesion!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JvText.de(context).menor,
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Rutas.inicio),
        ),
        actions: <Widget>[
          if (estado.enCurso)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              tooltip: 'Detener',
              onPressed: ref
                  .read(chatControllerProvider(widget.sessionId).notifier)
                  .detener,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _Cuerpo(estado: estado, scroll: _scroll, onHook: _enviar),
            ),
            Composer(
              habilitado: !estado.composerBloqueado && !_grabando && !sinCuota,
              // Dos motivos, y el orden importa: la cuota agotada es el que
              // deja al usuario sin poder trabajar, así que manda.
              motivoBloqueo: sinCuota
                  ? 'Alcanzaste el límite de tu plan.'
                  : estado.generandoEnOtroDispositivo
                  ? 'Hay una respuesta generándose en otro dispositivo.'
                  : null,
              onSaberMas: sinCuota
                  ? () => MuroPlan.mostrar(
                      context,
                      motivo: MotivoMuro.sinCuota,
                      me: me,
                      detalle: me?.access.resumen,
                    )
                  : null,
              onEnviar: _enviar,
              onAdjuntar: _adjuntar,
              onDictar: _alternarDictado,
              textoInicial: _textoDictado,
              encabezado: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // El caso manda sobre la sugerencia: si ya existe, no tiene
                  // sentido seguir ofreciendo crearlo.
                  if (estado.caso != null)
                    _BannerCaso(caso: estado.caso!)
                  else if (estado.sugerencia != null)
                    _ChipSugerenciaCaso(
                      sugerencia: estado.sugerencia!,
                      enCurso: estado.promocionando,
                      onGuardar: _promoverACaso,
                      onDescartar: ref
                          .read(
                            chatControllerProvider(widget.sessionId).notifier,
                          )
                          .descartarSugerencia,
                    ),
                  if (_adjunto != null)
                    ChipAdjunto(
                      adjunto: _adjunto!,
                      subiendo: _subiendoAdjunto,
                      onQuitar: () => setState(() {
                        _adjunto = null;
                        _documentoId = null;
                      }),
                    ),
                  if (_grabando || _transcribiendo)
                    BarraDictado(
                      segundos: _segundosGrabando,
                      transcribiendo: _transcribiendo,
                      onDetener: _detenerDictado,
                      onCancelar: _cancelarDictado,
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

/// Propuesta del agente: «esto parece un caso, ¿lo guardo?».
///
/// Se ofrece, no se impone: crear expedientes sin pedir permiso llena el
/// despacho de carpetas que el abogado no pidió y le quita la confianza en lo
/// que la app hace por su cuenta. Por eso hay un «Ahora no» del mismo tamaño.
class _ChipSugerenciaCaso extends StatelessWidget {
  const _ChipSugerenciaCaso({
    required this.sugerencia,
    required this.enCurso,
    required this.onGuardar,
    required this.onDescartar,
  });

  final SugerenciaCaso sugerencia;
  final bool enCurso;
  final VoidCallback onGuardar;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? nombre = sugerencia.nombre;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: JvShapes.rCampo,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.folder_special_outlined,
            size: 17,
            color: JvColors.purpura,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nombre == null
                      ? '¿Guardo esto como un caso?'
                      : '¿Guardo esto como «$nombre»?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: JvText.cuerpoMedio.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Así el trabajo y los documentos quedan en el expediente.',
                  style: JvText.de(context).menor.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (enCurso)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...<Widget>[
            TextButton(onPressed: onDescartar, child: const Text('Ahora no')),
            TextButton(onPressed: onGuardar, child: const Text('Guardar')),
          ],
        ],
      ),
    );
  }
}

/// La conversación ya pertenece a un caso.
class _BannerCaso extends StatelessWidget {
  const _BannerCaso({required this.caso});

  final CasoDelChat caso;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(
      color: JvColors.vigilanciaFondo,
      borderRadius: JvShapes.rCampo,
      border: Border.all(color: JvColors.vigilancia.withValues(alpha: 0.22)),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.folder_outlined, size: 16, color: JvColors.vigilancia),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                caso.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JvText.cuerpoMedio.copyWith(
                  fontSize: 13.5,
                  color: JvColors.vigilancia,
                ),
              ),
              if (caso.codigo != null)
                Text(caso.codigo!, style: JvText.de(context).codigo),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.push('${Rutas.casos}/${caso.matterId}'),
          child: const Text('Abrir'),
        ),
      ],
    ),
  );
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.estado,
    required this.scroll,
    required this.onHook,
  });

  final ChatState estado;
  final ScrollController scroll;
  final void Function(String) onHook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (estado.errorCarga != null) {
      return _ErrorCarga(
        onReintentar: () => ref
            .read(chatControllerProvider(estado.sessionId).notifier)
            .cargarHistorial(),
      );
    }
    if (estado.mensajes.isEmpty) {
      return const _Vacio();
    }

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: estado.mensajes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (BuildContext c, int i) {
        final Mensaje m = estado.mensajes[i];
        if (m.esUsuario) return BurbujaUsuario(texto: m.texto);
        return BurbujaAgente(
          mensaje: m,
          onReportar: () async {
            final bool enviado = await ReportSheet.abrir(
              c,
              sessionId: estado.sessionId,
              mensajeId: m.id,
              extracto: m.texto.length > 300
                  ? m.texto.substring(0, 300)
                  : m.texto,
            );
            if (enviado && c.mounted) {
              ScaffoldMessenger.of(c).showSnackBar(
                const SnackBar(content: Text('Gracias. Revisamos tu reporte.')),
              );
            }
          },
          onAbrirDocumento: (Artefacto a) =>
              c.push('${Rutas.inicio}documento/${a.id}', extra: a),
          onHook: (HookAccion h) => onHook(h.prompt),
          onReintentar: () {
            // Reintentar un turno huérfano crea uno NUEVO: nunca se reenvía el
            // que quedó a medias en el servidor.
            final int idx = estado.mensajes.indexOf(m);
            if (idx > 0 && estado.mensajes[idx - 1].esUsuario) {
              onHook(estado.mensajes[idx - 1].texto);
            }
          },
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AgentAvatar(tamano: 44),
            const SizedBox(height: 16),
            Text(
              '¿En qué te ayudo?',
              style: JvText.tituloHoja,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pregunta por una norma, un término o pide un borrador.',
              style: JvText.de(context).secundario,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: JvColors.de(context).terciario,
            ),
            const SizedBox(height: 14),
            Text(
              'No pudimos cargar esta conversación',
              style: JvText.cuerpoFuerte,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
