import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/theme/typography.dart';

/// Composer persistente. El chat es el centro del producto, así que esto nunca
/// desaparece de la pantalla de conversación (decisión del prototipo).
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onEnviar,
    this.habilitado = true,
    this.motivoBloqueo,
    this.onSaberMas,
    this.onAdjuntar,
    this.onDictar,
    this.textoInicial,
    this.encabezado,
  });

  final void Function(String) onEnviar;
  final bool habilitado;

  /// Por qué está bloqueado: "generando en otro dispositivo", etc.
  final String? motivoBloqueo;

  /// Si el bloqueo tiene una explicación (p. ej. la cuota del plan), el aviso
  /// se vuelve tocable. Sin esto el usuario lee «no puedes» y se queda sin
  /// saber por qué ni qué hacer.
  final VoidCallback? onSaberMas;
  final VoidCallback? onAdjuntar;
  final VoidCallback? onDictar;
  final String? textoInicial;

  /// Contenido que se muestra sobre el campo: chip del adjunto, barra de
  /// dictado, aviso de bloqueo…
  final Widget? encabezado;

  @override
  State<Composer> createState() => ComposerState();
}

class ComposerState extends State<Composer> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _foco = FocusNode();
  bool _enfocado = false;

  @override
  void initState() {
    super.initState();
    if (widget.textoInicial != null) _c.text = widget.textoInicial!;
    _foco.addListener(() => setState(() => _enfocado = _foco.hasFocus));
    _c.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El dictado entrega el texto de forma asíncrona: se inserta al llegar.
    final String? nuevo = widget.textoInicial;
    if (nuevo != null && nuevo != oldWidget.textoInicial && nuevo.isNotEmpty) {
      _c.text = _c.text.isEmpty ? nuevo : '${_c.text} $nuevo';
      _foco.requestFocus();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _foco.dispose();
    super.dispose();
  }

  /// Permite rellenar el composer desde fuera (atajos, hooks).
  void rellenar(String texto) {
    _c.text = texto;
    _foco.requestFocus();
  }

  void _enviar() {
    final String t = _c.text.trim();
    if (t.isEmpty || !widget.habilitado) return;
    widget.onEnviar(t);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool puedeEnviar = widget.habilitado && _c.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.encabezado != null) widget.encabezado!,
          if (widget.motivoBloqueo != null) ...<Widget>[
            // Dos bloqueos distintos, dos colores: «se está generando en otro
            // dispositivo» es transitorio (azul) y «se acabó la cuota» requiere
            // una explicación (ámbar + toque).
            _AvisoBloqueo(
              texto: widget.motivoBloqueo!,
              onSaberMas: widget.onSaberMas,
            ),
          ],
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: JvShapes.rComposer,
              border: Border.all(
                color: _enfocado ? JvColors.purpura : cs.outline,
                width: 1.5,
              ),
              boxShadow: JvShapes.sombraTarjeta,
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _c,
                  focusNode: _foco,
                  enabled: widget.habilitado,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: JvText.cuerpoMedio,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.habilitado
                        ? 'Escribe a Jurovia…'
                        : 'Generando respuesta…',
                    hintStyle: JvText.cuerpoMedio.copyWith(
                      color: JvColors.de(context).terciario,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (widget.onAdjuntar != null)
                      _AccionCircular(
                        icono: Icons.add,
                        etiqueta: 'Adjuntar documento',
                        onTap: widget.habilitado ? widget.onAdjuntar : null,
                      ),
                    if (widget.onDictar != null) ...<Widget>[
                      const SizedBox(width: 7),
                      _AccionCircular(
                        icono: Icons.mic_none,
                        etiqueta: 'Dictar',
                        onTap: widget.habilitado ? widget.onDictar : null,
                      ),
                    ],
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: 'Enviar mensaje',
                      child: GestureDetector(
                        onTap: puedeEnviar ? _enviar : null,
                        child: Opacity(
                          opacity: puedeEnviar ? 1 : 0.4,
                          child: Container(
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
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccionCircular extends StatelessWidget {
  const _AccionCircular({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: etiqueta,
      child: Material(
        color: cs.surfaceContainerLow,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icono,
              size: 17,
              color: JvColors.de(context).secundario,
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso sobre el composer cuando no se puede escribir.
class _AvisoBloqueo extends StatelessWidget {
  const _AvisoBloqueo({required this.texto, this.onSaberMas});

  final String texto;
  final VoidCallback? onSaberMas;

  @override
  Widget build(BuildContext context) {
    final bool explicable = onSaberMas != null;
    final Color color = explicable ? JvColors.termino : JvColors.vigilancia;
    final Color fondo = explicable
        ? JvColors.terminoFondo
        : JvColors.vigilanciaFondo;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: fondo, borderRadius: JvShapes.rCampo),
      child: Material(
        color: Colors.transparent,
        borderRadius: JvShapes.rCampo,
        child: InkWell(
          borderRadius: JvShapes.rCampo,
          onTap: onSaberMas,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  explicable ? Icons.hourglass_empty : Icons.sync,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    texto,
                    style: JvText.de(context).menor.copyWith(color: color),
                  ),
                ),
                if (explicable) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    'Saber más',
                    style: JvText.de(
                      context,
                    ).menor.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
