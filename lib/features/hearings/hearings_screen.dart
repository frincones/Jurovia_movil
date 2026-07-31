import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../chat/attachments.dart';
import 'hearing_upload.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/estado_vista.dart';

/// S10 · Audiencias: transcripción y acta.
///
/// El archivo **no pasa por el backend**: se pide una URL firmada, se sube
/// directo a **Supabase Storage** (bucket `audiencia_tmp`) y se encola el job.
/// Un audio de audiencia puede durar horas; subirlo por el backend lo tumbaría.
class HearingsScreen extends ConsumerStatefulWidget {
  const HearingsScreen({super.key});

  @override
  ConsumerState<HearingsScreen> createState() => _HearingsScreenState();
}

class _HearingsScreenState extends ConsumerState<HearingsScreen> {
  bool _cargandoJobs = true;
  List<Map<String, dynamic>> _jobs = <Map<String, dynamic>>[];
  String? _error;

  SubidaAudiencia? _subida;
  ProgresoSubida? _progreso;
  Timer? _sondeo;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Polling del estado de los jobs mientras haya alguno en proceso.
    _sondeo = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_jobs.any(
        (Map<String, dynamic> j) => <String>[
          'queued',
          'processing',
          'transcribing',
          'downloading',
        ].contains(j['status']),
      )) {
        _cargar();
      }
    });
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    _subida?.cancelar();
    super.dispose();
  }

  /// Elige un archivo de audio/vídeo y lo sube (F4.01–F4.03).
  Future<void> _subirArchivo() async {
    final Adjunto? a = await SelectorAdjuntos.galeria();
    if (a == null || !mounted) return;

    final File f = a.archivo;
    final int tam = await f.length();
    if (tam > SubidaAudiencia.umbralWifi && mounted) {
      final bool seguir = await _avisarWifi(tam) ?? false;
      if (!seguir) return;
    }

    _subida = SubidaAudiencia(ref.read(apiClientProvider));
    setState(() => _progreso = const ProgresoSubida(enviados: 0, total: 1));

    final String? jobId = await _subida!.subir(
      archivo: f,
      nombre: a.nombre,
      onProgreso: (ProgresoSubida p) {
        if (mounted) setState(() => _progreso = p);
      },
    );

    if (!mounted) return;
    setState(() => _progreso = null);
    if (jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos subir la grabación.')),
      );
    } else {
      await _cargar();
    }
  }

  Future<bool?> _avisarWifi(int bytes) => showDialog<bool>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: const Text('Archivo grande'),
      content: Text(
        'La grabación pesa ${(bytes / 1024 / 1024).toStringAsFixed(0)} MB. '
        'Conviene subirla por Wi-Fi para no gastar tus datos móviles.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('Subir igual'),
        ),
      ],
    ),
  );

  /// Encola una audiencia desde un enlace público.
  Future<void> _pegarEnlace() async {
    final TextEditingController ctrl = TextEditingController();
    final String? enlace = await showDialog<String>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Pegar enlace'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://youtube.com/… o Rama Judicial',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(ctrl.text.trim()),
            child: const Text('Analizar'),
          ),
        ],
      ),
    );
    if (enlace == null || enlace.isEmpty || !mounted) return;

    _subida ??= SubidaAudiencia(ref.read(apiClientProvider));
    final String? jobId = await _subida!.desdeEnlace(enlace);
    if (!mounted) return;
    if (jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos procesar ese enlace.')),
      );
    } else {
      await _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargandoJobs = true;
      _error = null;
    });
    try {
      final List<dynamic> crudos = await ref
          .read(apiClientProvider)
          .getLista('/api/audiencias');
      if (!mounted) return;
      setState(() {
        _jobs = crudos
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
            .toList();
        _cargandoJobs = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargandoJobs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Analizar audiencia')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: <Widget>[
              // Zona de subida.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant,
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      JvColors.rosa.withValues(alpha: 0.07),
                      JvColors.purpura.withValues(alpha: 0.06),
                      JvColors.azul.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const _Ecualizador(),
                    const SizedBox(height: 14),
                    Text(
                      'Sube la grabación o pega el enlace',
                      style: JvText.cuerpoFuerte,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'MP3, M4A, MP4 o enlace de YouTube / Rama Judicial. '
                      'Jurovia transcribe, identifica intervinientes y arma el acta.',
                      style: JvText.de(context).secundario,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    if (_progreso != null)
                      _BarraSubida(progreso: _progreso!)
                    else
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _subirArchivo,
                            icon: const Icon(Icons.upload_file, size: 17),
                            label: const Text('Subir grabación'),
                            style: FilledButton.styleFrom(
                              backgroundColor: JvColors.purpura,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pegarEnlace,
                            icon: const Icon(Icons.link, size: 17),
                            label: const Text('Pegar enlace'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text('EN PROCESO', style: JvText.de(context).etiqueta),
              const SizedBox(height: 10),

              if (_cargandoJobs)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                EstadoError(onReintentar: _cargar)
              else if (_jobs.isEmpty)
                Text(
                  'No hay audiencias en proceso.',
                  style: JvText.de(context).menor,
                )
              else
                ..._jobs.map(_TarjetaJob.new),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaJob extends StatelessWidget {
  const _TarjetaJob(this.job, {super.key});

  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String estado = job['status'] as String? ?? 'queued';
    final String nombre = job['filename'] as String? ?? 'Audiencia';

    final (String texto, double progreso) = switch (estado) {
      'queued' => ('En cola', 0.08),
      'downloading' ||
      'processing' ||
      'transcribing' => ('Transcribiendo', 0.54),
      'done' || 'completed' => ('Acta lista', 1.0),
      'error' || 'failed' => ('Falló', 0.0),
      _ => (estado, 0.3),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: JvShapes.rTarjeta,
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JvText.cuerpoFuerte.copyWith(fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: JvColors.vigilanciaFondo,
                    borderRadius: JvShapes.rPill,
                  ),
                  child: Text(
                    texto,
                    style: JvText.de(
                      context,
                    ).menor.copyWith(fontSize: 11, color: JvColors.vigilancia),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: JvShapes.rPill,
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerLow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barras del prototipo (`jvBar`), con desfase de .12 s.
class _Ecualizador extends StatefulWidget {
  const _Ecualizador();

  @override
  State<_Ecualizador> createState() => _EcualizadorState();
}

class _EcualizadorState extends State<_Ecualizador>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  static const List<Color> _colores = <Color>[
    JvColors.rosa,
    JvColors.magenta,
    JvColors.purpura,
    JvColors.purpuraHover,
    JvColors.azul,
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool sinMovimiento = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 38,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(5, (int i) {
            final double t = (_c.value + i * 0.12) % 1.0;
            final double alto = sinMovimiento
                ? 0.7
                : 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              width: 4,
              height: 38 * alto,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: _colores[i],
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Progreso de la subida directa a Supabase Storage.
class _BarraSubida extends StatelessWidget {
  const _BarraSubida({required this.progreso});

  final ProgresoSubida progreso;

  @override
  Widget build(BuildContext context) {
    final String titulo = switch (progreso.fase) {
      'preparando' => 'Preparando la subida…',
      'encolando' => 'Encolando para transcribir…',
      _ => 'Subiendo · ${progreso.porcentaje}%',
    };

    return Column(
      children: <Widget>[
        Text(titulo, style: JvText.cuerpoMedio),
        if (progreso.legible.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(progreso.legible, style: JvText.de(context).menor),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: JvShapes.rPill,
          child: LinearProgressIndicator(
            value: progreso.fase == 'subiendo' ? progreso.fraccion : null,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
