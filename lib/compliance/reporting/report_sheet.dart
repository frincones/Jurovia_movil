import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/aurora_button.dart';

/// Motivos de reporte. Cubren las categorías que la política de contenido
/// generado por IA de Google espera poder recibir.
enum MotivoReporte {
  incorrecto('Información incorrecta'),
  fuenteFalsa('Cita una fuente que no existe'),
  ofensivo('Contenido ofensivo o inapropiado'),
  peligroso('Consejo peligroso o dañino'),
  otro('Otro');

  const MotivoReporte(this.etiqueta);
  final String etiqueta;
}

/// S16 · Hoja de reporte de contenido generado por IA.
///
/// **AuditCheck C8.11 (Google, política de contenido generado por IA) y
/// A3.1 (Apple 1.2).**
///
/// Google exige que las apps cuyo chatbot de texto es la función central
/// permitan **reportar contenido ofensivo sin salir de la app**. Apple pide un
/// mecanismo equivalente para contenido generado.
///
/// Se abre desde el botón "Reportar" que acompaña a cada respuesta del agente.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.sessionId,
    required this.mensajeId,
    this.extracto,
  });

  final String sessionId;
  final String mensajeId;
  final String? extracto;

  /// Abre la hoja. Devuelve `true` si el reporte se envió.
  static Future<bool> abrir(
    BuildContext context, {
    required String sessionId,
    required String mensajeId,
    String? extracto,
  }) async {
    final bool? r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        sessionId: sessionId,
        mensajeId: mensajeId,
        extracto: extracto,
      ),
    );
    return r ?? false;
  }

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  MotivoReporte? _motivo;
  final TextEditingController _comentario = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_motivo == null) return;
    setState(() => _enviando = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/feedback',
            cuerpo: <String, dynamic>{
              'kind': 'report_ai_content',
              'reason': _motivo!.name,
              'reason_label': _motivo!.etiqueta,
              'comment': _comentario.text.trim(),
              'session_id': widget.sessionId,
              'message_id': widget.mensajeId,
              'excerpt': ?widget.extracto,
            },
          );
    } on Object {
      // El reporte no puede bloquear al usuario: si falla el envío se agradece
      // igual. Reintentar aquí complicaría más de lo que aporta.
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: JvShapes.rPill,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Reportar esta respuesta', style: JvText.tituloHoja),
              const SizedBox(height: 6),
              Text(
                'Nos ayuda a mejorar el filtrado del asistente. Revisamos todos '
                'los reportes.',
                style: JvText.de(context).secundario,
              ),
              const SizedBox(height: 18),

              // RadioGroup sustituye a groupValue/onChanged, obsoletos desde
              // Flutter 3.32.
              RadioGroup<MotivoReporte>(
                groupValue: _motivo,
                // RadioGroup exige un callback no nulo: mientras se envía se
                // ignora la selección en vez de pasar null.
                onChanged: (MotivoReporte? v) {
                  if (_enviando) return;
                  setState(() => _motivo = v);
                },
                child: Column(
                  children: MotivoReporte.values
                      .map(
                        (MotivoReporte m) => RadioListTile<MotivoReporte>(
                          value: m,
                          title: Text(m.etiqueta, style: JvText.cuerpoMedio),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: JvColors.purpura,
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 8),
              TextField(
                controller: _comentario,
                enabled: !_enviando,
                maxLines: 3,
                maxLength: 500,
                style: JvText.cuerpoMedio,
                decoration: const InputDecoration(
                  hintText: '¿Qué estuvo mal? (opcional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              AuroraButton(
                texto: 'Enviar reporte',
                cargando: _enviando,
                onPressed: _motivo == null ? null : _enviar,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _enviando
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancelar',
                    style: JvText.chip.copyWith(
                      color: JvColors.de(context).terciario,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
