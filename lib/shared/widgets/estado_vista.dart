import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Estados vacío / error / sin conexión, unificados.
///
/// AuditCheck: la regla 2.1 de Apple rechaza pantallas incompletas, y ninguna
/// vista puede quedarse en blanco (arquitectura P5: degradar, nunca romper).

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icono, size: 38, color: JvColors.de(context).terciario),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: JvText.cuerpoFuerte,
            ),
            if (detalle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: JvText.de(context).secundario,
              ),
            ],
            if (accion != null) ...<Widget>[
              const SizedBox(height: 18),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}

class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.onReintentar,
    this.titulo = 'No pudimos cargar esta información',
    this.detalle,
  });

  final VoidCallback onReintentar;
  final String titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.cloud_off_outlined,
      titulo: titulo,
      detalle: detalle ?? 'Revisa tu conexión e inténtalo de nuevo.',
      accion: OutlinedButton.icon(
        onPressed: onReintentar,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Reintentar'),
      ),
    );
  }
}
