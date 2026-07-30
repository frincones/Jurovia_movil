import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/typography.dart';
import '../../features/chat/chat_controller.dart';
import '../models/chat.dart';
import '../models/me.dart';
import 'jurovia_logo.dart';

/// Clave del Scaffold que contiene el drawer.
///
/// ⚠️ Cada pantalla del shell tiene **su propio Scaffold**, así que
/// `Scaffold.of(context)` desde dentro encuentra el interior —que no tiene
/// drawer— y no pasa nada al tocar el menú. Con esta clave se abre siempre el
/// correcto. Usar [abrirHistorial] desde las pantallas.
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Abre el drawer del historial desde cualquier pantalla del shell.
void abrirHistorial() => shellScaffoldKey.currentState?.openDrawer();

/// Medidas de la barra flotante. Un solo sitio: las pantallas derivan de aquí
/// el espacio que deben dejar libre, en vez de cablearlo a mano.
abstract final class BarraFlotante {
  static const double alto = 58;
  static const double margenLateral = 18;
  static const double margenInferior = 14;

  /// Tamaño del icono de un destino y de la pastilla que lo marca.
  static const double icono = 21;
  static const double altoDestino = 42;
  static const double radioPastilla = 14;

  /// Diámetro del botón del chat dentro de la pastilla.
  static const double chat = 44;

  /// Espacio que el contenido debe reservar para no quedar bajo el cristal.
  ///
  /// Antes cada pantalla escribía `100` a mano y nadie sabía de dónde salía.
  /// Con la barra flotando ese número dejaría de cuadrar —y el último elemento
  /// de cada lista se quedaría debajo del vidrio, visible pero no tocable.
  static double espacioContenido(BuildContext c) =>
      alto + margenInferior + MediaQuery.viewPaddingOf(c).bottom + JvShapes.lg;
}

/// Envoltorio de los 4 destinos con barra flotante.
///
/// El chat **no es una pestaña**: ocupa el centro de la barra con el gradiente
/// aurora. Decisión explícita del prototipo —el chat es el centro del producto,
/// no un destino más— conservada al pasar a la pastilla flotante.
///
/// La barra va en un [Stack] sobre el cuerpo, no en `bottomNavigationBar`. Esa
/// es la diferencia que hace que el rediseño se note: un
/// `bottomNavigationBar` **recorta** el cuerpo a su altura, así que el
/// contenido termina justo donde empieza la barra y el desenfoque no tendría
/// nada que desenfocar. Con el Stack la lista sigue por debajo del cristal.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.rutaActual, required this.child});

  final String rutaActual;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int noLeidas = ref.watch(noLeidasProvider).valueOrNull ?? 0;
    final Me? me = ref.watch(meProvider).valueOrNull;

    return Scaffold(
      key: shellScaffoldKey,
      drawer: const HistorialDrawer(),
      body: Stack(
        children: <Widget>[
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // Los márgenes transparentes no capturan toques: `Padding` no es
            // opaco al hit-test, así que se puede desplazar la lista tocando
            // justo al lado de la pastilla.
            child: Padding(
              padding: EdgeInsets.only(
                left: BarraFlotante.margenLateral,
                right: BarraFlotante.margenLateral,
                bottom:
                    BarraFlotante.margenInferior +
                    MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: _Barra(
                rutaActual: rutaActual,
                noLeidas: noLeidas,
                iniciales: me?.iniciales ?? 'JV',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.rutaActual,
    required this.noLeidas,
    required this.iniciales,
  });

  final String rutaActual;
  final int noLeidas;
  final String iniciales;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final ColorScheme cs = tema.colorScheme;
    final bool oscuro = tema.brightness == Brightness.dark;

    // Un cristal al 72 % sobre el fondo oscuro (#0F0D18) se ve sucio: la
    // superficie oscura tiene poco contraste con lo que hay detrás. Sube la
    // opacidad y densifica la sombra para que la pastilla se despegue.
    final double opacidad = oscuro ? 0.82 : 0.72;
    final Color sombra = oscuro
        ? const Color(0x73000000)
        : const Color(0x24191427);

    return ClipRRect(
      borderRadius: JvShapes.rPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: opacidad),
            borderRadius: JvShapes.rPill,
            border: Border.all(color: cs.outline.withValues(alpha: 0.7)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: sombra,
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            height: BarraFlotante.alto,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: <Widget>[
                  _Destino(
                    icono: Icons.home_outlined,
                    iconoActivo: Icons.home_rounded,
                    etiqueta: 'Inicio',
                    ruta: Rutas.inicio,
                    activo: rutaActual == Rutas.inicio,
                  ),
                  _Destino(
                    icono: Icons.folder_outlined,
                    iconoActivo: Icons.folder_rounded,
                    etiqueta: 'Casos',
                    ruta: Rutas.casos,
                    activo: rutaActual.startsWith(Rutas.casos),
                  ),
                  const _BotonChat(),
                  _Destino(
                    icono: Icons.notifications_none,
                    iconoActivo: Icons.notifications_rounded,
                    etiqueta: 'Bandeja',
                    ruta: Rutas.bandeja,
                    activo: rutaActual == Rutas.bandeja,
                    badge: noLeidas,
                  ),
                  _Destino(
                    // Perfil se identifica por el avatar, no por un icono
                    // genérico de persona. Sale de `me.iniciales`: no hace
                    // falta que el backend devuelva ninguna foto.
                    icono: Icons.person_outline,
                    iconoActivo: Icons.person_rounded,
                    etiqueta: 'Perfil',
                    ruta: Rutas.perfil,
                    activo: rutaActual.startsWith(Rutas.perfil),
                    iniciales: iniciales,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El chat, dentro de la pastilla (variante A del prototipo).
///
/// Conserva el gradiente y el centro, pero deja de sobresalir: una sola pieza
/// flotando en vez de dos peleándose por la atención.
class _BotonChat extends StatelessWidget {
  const _BotonChat();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nueva conversación con Jurovia',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push(Rutas.chat),
            child: Container(
              width: BarraFlotante.chat,
              height: BarraFlotante.chat,
              decoration: const BoxDecoration(
                gradient: JvColors.aurora,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x667B3DF5),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 21, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destino extends StatelessWidget {
  const _Destino({
    required this.icono,
    required this.iconoActivo,
    required this.etiqueta,
    required this.ruta,
    required this.activo,
    this.badge = 0,
    this.iniciales,
  });

  final IconData icono;

  /// Relleno cuando está activo. Es la **segunda** señal, además de la
  /// pastilla: el estado no puede depender solo del color.
  final IconData iconoActivo;

  final String etiqueta;
  final String ruta;
  final bool activo;
  final int badge;

  /// Si viene, el destino se pinta como avatar en vez de icono (Perfil).
  final String? iniciales;

  @override
  Widget build(BuildContext context) {
    final Color color = activo ? JvColors.purpura : JvColors.txtTerciario;
    final Duration duracion = JvMotion.efectiva(
      context,
      const Duration(milliseconds: 220),
    );

    return Expanded(
      child: Semantics(
        button: true,
        selected: activo,
        // Sin etiqueta visible, este texto es lo ÚNICO que nombra el destino
        // para un lector de pantalla.
        label: badge > 0 ? '$etiqueta, $badge sin leer' : etiqueta,
        // Lo de dentro no se anuncia: las iniciales del avatar («FR») y el
        // número del contador se leerían como ruido suelto, y el contador ya
        // va dicho en la etiqueta de arriba.
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(BarraFlotante.radioPastilla),
          child: InkWell(
            borderRadius: BorderRadius.circular(BarraFlotante.radioPastilla),
            onTap: () => context.go(ruta),
            child: AnimatedContainer(
              duration: duracion,
              curve: Curves.easeOut,
              height: BarraFlotante.altoDestino,
              decoration: BoxDecoration(
                color: activo
                    ? JvColors.purpura.withValues(alpha: 0.11)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(
                  BarraFlotante.radioPastilla,
                ),
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  if (iniciales != null)
                    _Avatar(iniciales: iniciales!, activo: activo)
                  else
                    Icon(
                      activo ? iconoActivo : icono,
                      size: BarraFlotante.icono,
                      color: color,
                    ),
                  // Fuera del icono, no encima: con un desplazamiento pequeño
                  // el contador de dos caracteres («9+») tapaba la campana y
                  // el destino dejaba de reconocerse —justo lo que no puede
                  // pasar en una barra sin etiquetas.
                  if (badge > 0)
                    Positioned(
                      top: -8,
                      right: -14,
                      child: _Cuenta(valor: badge),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.iniciales, required this.activo});

  final String iniciales;
  final bool activo;

  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(
      gradient: JvColors.aurora,
      shape: BoxShape.circle,
      border: activo ? Border.all(color: JvColors.purpura, width: 1.8) : null,
    ),
    alignment: Alignment.center,
    child: Text(
      iniciales,
      style: JvText.menor.copyWith(
        fontSize: 9.5,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Contador de la bandeja.
///
/// Instagram usa un punto pelado porque «alguien te escribió» no es una
/// cantidad sobre la que actúes. Aquí el número son términos y borradores
/// esperando: **seis pendientes y uno no son la misma mañana**, así que se
/// conserva la cuenta y solo se aligera —sin borde, más pequeña—. Sobre la
/// pastilla no hace falta el borde: no hay fondo contra el que recortar.
class _Cuenta extends StatelessWidget {
  const _Cuenta({required this.valor});

  final int valor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    constraints: const BoxConstraints(minWidth: 15),
    height: 15,
    decoration: const BoxDecoration(
      color: JvColors.peligro,
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.all(Radius.circular(999)),
    ),
    alignment: Alignment.center,
    child: Text(
      valor > 9 ? '9+' : '$valor',
      textAlign: TextAlign.center,
      style: JvText.menor.copyWith(
        fontSize: 8.5,
        height: 1,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Drawer lateral con el historial de conversaciones (patrón ChatGPT).
class HistorialDrawer extends ConsumerWidget {
  const HistorialDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SesionChat>> sesiones = ref.watch(sesionesProvider);
    final Me? me = ref.watch(meProvider).valueOrNull;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: cs.surface,
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(
                children: <Widget>[
                  const JuroviaLogo(),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ItemDrawer(
                icono: Icons.add_comment_outlined,
                texto: 'Nueva conversación',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(Rutas.chat);
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text('RECIENTES', style: JvText.etiqueta),
            ),
            Expanded(
              child: sesiones.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No se pudo cargar el historial.',
                    style: JvText.menor,
                  ),
                ),
                data: (List<SesionChat> lista) => lista.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Aún no tienes conversaciones.',
                          style: JvText.menor,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: lista.length,
                        itemBuilder: (_, int i) {
                          final SesionChat s = lista[i];
                          return _ItemDrawer(
                            texto: s.titulo,
                            trailing: s.cuando,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('${Rutas.chat}?sesion=${s.id}');
                            },
                          );
                        },
                      ),
              ),
            ),
            Divider(height: 1, color: cs.outline),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: JvColors.aurora,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      me?.iniciales ?? 'JV',
                      style: JvText.chip.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          me?.nombreCorto ?? 'Mi cuenta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JvText.cuerpoFuerte.copyWith(fontSize: 13.5),
                        ),
                        Text(
                          me?.plan.toUpperCase() ?? '',
                          style: JvText.menor.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
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

class _ItemDrawer extends StatelessWidget {
  const _ItemDrawer({
    required this.texto,
    required this.onTap,
    this.icono,
    this.trailing,
  });

  final String texto;
  final VoidCallback onTap;
  final IconData? icono;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: <Widget>[
              if (icono != null) ...<Widget>[
                Icon(icono, size: 17, color: JvColors.txtSecundario),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JvText.cuerpoMedio,
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: JvText.menor.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Transición del drawer con la curva de marca.
Duration duracionDrawer(BuildContext c) =>
    JvMotion.efectiva(c, JvMotion.drawer);
