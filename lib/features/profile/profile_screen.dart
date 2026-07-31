import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compliance/billing/muro_plan.dart';
import '../../compliance/legal/disclaimer.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/models/me.dart';
import '../../shared/widgets/aurora_button.dart';
import '../../shared/widgets/estado_vista.dart';

/// S12 · Perfil.
///
/// ⚠️ **AuditCheck A3.15–A3.18 — la tarjeta de plan es de SOLO LECTURA.**
///
/// No hay botón de comprar, ni enlace a juroviapp.com, ni texto que sugiera
/// pagar fuera. Un revisor de Apple no debe encontrar ninguna forma de comprar
/// dentro de la app (modelo Web2App). El prototipo traía "Continuar con Pro" y
/// "Facturación en la web de Jurovia": ambos eliminados.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Me?> me = ref.watch(meProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 18, 6),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.menu, size: 20),
                    tooltip: 'Historial de conversaciones',
                    onPressed: abrirHistorial,
                  ),
                  Text('Perfil', style: JvText.tituloSeccion),
                ],
              ),
            ),
            Expanded(
              child: me.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => EstadoError(
                  onReintentar: () => ref.read(meProvider.notifier).refrescar(),
                ),
                data: (Me? m) => RefreshIndicator(
                  onRefresh: () => ref.read(meProvider.notifier).refrescar(),
                  child: _Cuerpo(me: m),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.me});

  final Me? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Me? m = me;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        BarraFlotante.espacioContenido(context),
      ),
      children: <Widget>[
        // ── Identidad ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: JvShapes.rTarjeta,
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: JvColors.aurora,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  m?.iniciales ?? 'JV',
                  style: JvText.cuerpoFuerte.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      m?.nombreCorto ?? 'Mi cuenta',
                      style: JvText.cuerpoFuerte,
                    ),
                    if (m?.email != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(m!.email!, style: JvText.de(context).secundario),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _TarjetaPlan(me: m),

        // La fila que faltaba: sin ella, quien quiere cancelar o cambiar de
        // plan no encuentra dónde preguntar y lo lee como pantalla a medias.
        // No vende ni enlaza: explica dónde se gestiona (Apple 3.1.3(b)).
        const SizedBox(height: 10),
        FilaGestionarPlan(me: m),

        const SizedBox(height: 24),
        Text('CUENTA', style: JvText.de(context).etiqueta),
        const SizedBox(height: 10),
        _Fila(
          icono: Icons.privacy_tip_outlined,
          titulo: 'Privacidad y datos',
          onTap: () => context.push(Rutas.privacidad),
        ),
        _Fila(
          icono: Icons.gavel_outlined,
          titulo: 'Legal',
          onTap: () => context.push(Rutas.legal),
        ),
        _Fila(
          icono: Icons.mic_none,
          titulo: 'Audiencias',
          onTap: () => context.push(Rutas.audiencia),
        ),

        const SizedBox(height: 24),
        Text('INTEGRACIONES', style: JvText.de(context).etiqueta),
        const SizedBox(height: 10),
        const _Integraciones(),

        const SizedBox(height: 24),
        const DisclaimerBanner(),

        const SizedBox(height: 20),
        SecondaryButton(
          texto: 'Cerrar sesión',
          destructivo: true,
          onPressed: () async {
            await ref.read(authServiceProvider).cerrar();
            await ref.read(secureStoreProvider).purgar();
          },
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Jurovia · Medellín, Colombia',
            style: JvText.de(context).menor.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de plan **informativa**. Ver la advertencia de [ProfileScreen].
class _TarjetaPlan extends ConsumerWidget {
  const _TarjetaPlan({required this.me});

  final Me? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<Map<String, dynamic>> planes = ref.watch(planesProvider);
    final Me? m = me;

    // El nombre del plan sale SIEMPRE de /api/plans, nunca escrito a mano.
    String nombrePlan = m?.plan.toUpperCase() ?? '—';
    planes.whenData((Map<String, dynamic> p) {
      final List<dynamic> lista = (p['plans'] as List<dynamic>?) ?? <dynamic>[];
      for (final dynamic e in lista) {
        if (e is Map && e['tier'] == m?.plan) {
          nombrePlan = (e['name'] as String? ?? nombrePlan).toUpperCase();
        }
      }
    });

    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: JvColors.aurora,
        borderRadius: BorderRadius.circular(JvShapes.tarjeta + 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: JvShapes.rTarjeta,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('TU PLAN', style: JvText.de(context).etiqueta),
                      const SizedBox(height: 4),
                      Text(nombrePlan, style: JvText.cifra),
                    ],
                  ),
                ),
                if (m != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: JvShapes.rPill,
                    ),
                    // Cuota según access.model: créditos O turnos diarios.
                    child: Text(m.access.resumen, style: JvText.chip),
                  ),
              ],
            ),
            if (m?.trialEndsAt != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Tu prueba termina el ${m!.trialEndsAt!.day}/'
                '${m.trialEndsAt!.month}/${m.trialEndsAt!.year}.',
                style: JvText.de(context).menor,
              ),
            ],
            // ⚠️ Aquí NO va ningún botón de compra ni enlace a la web.
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.onTap});

  final IconData icono;
  final String titulo;
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: JvShapes.rLista,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: <Widget>[
                Icon(icono, size: 18, color: JvColors.de(context).secundario),
                const SizedBox(width: 12),
                Expanded(child: Text(titulo, style: JvText.cuerpoMedio)),
                Icon(
                  Icons.chevron_right,
                  size: 18,
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

/// F3.17 · Estado de las integraciones del despacho (Gmail, calendario…).
///
/// Solo informa: conectar una integración abre un flujo OAuth que hoy vive en
/// la web. Aquí se muestra el estado para que el abogado sepa qué tiene activo.
class _Integraciones extends ConsumerWidget {
  const _Integraciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<Map<String, dynamic>> lista =
        ref.watch(integracionesProvider).valueOrNull ??
        <Map<String, dynamic>>[];

    if (lista.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: JvShapes.rCampo,
        ),
        child: Text(
          'No tienes integraciones conectadas. Puedes conectarlas desde '
          'Jurovia en el navegador.',
          style: JvText.de(context).menor.copyWith(height: 1.5),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: JvShapes.rLista,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: lista.map((Map<String, dynamic> i) {
          final String nombre =
              i['name'] as String? ?? i['toolkit'] as String? ?? 'Integración';
          final bool activa =
              i['connected'] as bool? ?? i['enabled'] as bool? ?? false;
          final bool ultima = i == lista.last;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              border: ultima
                  ? null
                  : Border(bottom: BorderSide(color: cs.surfaceContainerLow)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  activa ? Icons.check_circle : Icons.circle_outlined,
                  size: 17,
                  color: activa
                      ? JvColors.exito
                      : JvColors.de(context).terciario,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombre,
                    style: JvText.cuerpoMedio.copyWith(fontSize: 14),
                  ),
                ),
                Text(
                  activa ? 'Conectado' : 'Sin conectar',
                  style: JvText.de(context).menor.copyWith(
                    color: activa
                        ? JvColors.exito
                        : JvColors.de(context).terciario,
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
