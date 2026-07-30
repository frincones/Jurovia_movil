import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../compliance/account_deletion/delete_account_screen.dart';
import '../../compliance/ai_consent/ai_consent_gate.dart';
import '../../compliance/ai_consent/ai_consent_screen.dart';
import '../../compliance/legal/legal_screen.dart';
import '../../compliance/legal/privacy_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/cases/case_detail_screen.dart';
import '../../features/cases/cases_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/documents/document_screen.dart';
import '../../features/hearings/hearings_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/inbox/inbox_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../shared/models/chat.dart';
import '../../shared/widgets/app_shell.dart';
import '../providers.dart';

abstract final class Rutas {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String consentimientoIa = '/consentimiento-ia';

  static const String inicio = '/';
  static const String casos = '/casos';
  static const String bandeja = '/bandeja';
  static const String perfil = '/perfil';

  static const String chat = '/chat';
  static const String audiencia = '/audiencia';
  static const String documento = '/documento';

  static const String privacidad = '/privacidad';
  static const String legal = '/legal';
  static const String eliminarCuenta = '/eliminar-cuenta';

  /// Destinos con barra inferior.
  static const List<String> conNav = <String>[inicio, casos, bandeja, perfil];
}

final GlobalKey<NavigatorState> _raiz = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shell = GlobalKey<NavigatorState>();

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    navigatorKey: _raiz,
    initialLocation: Rutas.splash,
    refreshListenable: _Escucha(ref),
    redirect: (BuildContext context, GoRouterState estado) {
      final bool autenticado = ref.read(autenticadoProvider);
      final AsyncValue<AiConsent> consent = ref.read(aiConsentProvider);
      final String ruta = estado.matchedLocation;

      // Mientras se resuelve el consentimiento guardado, quedarse en el splash.
      if (consent.isLoading) return ruta == Rutas.splash ? null : Rutas.splash;

      final bool enAuth = ruta == Rutas.login || ruta == Rutas.onboarding;

      if (!autenticado) return enAuth ? null : Rutas.login;

      // ── Puerta de consentimiento de IA (AuditCheck C8.1, Apple 5.1.2(i)) ──
      // El agente no es alcanzable por navegación sin consentimiento. El token
      // de AiConsentGate lo impide además por código.
      final bool puedeAgente = AiConsentGate.canUseAgent(consent.valueOrNull);
      if (!puedeAgente && ruta.startsWith(Rutas.chat)) {
        return Rutas.consentimientoIa;
      }

      if (enAuth || ruta == Rutas.splash) return Rutas.inicio;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: Rutas.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Rutas.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Rutas.consentimientoIa,
        builder: (_, _) => const AiConsentScreen(),
      ),

      // ── Destinos con barra inferior ──────────────────────────────────
      ShellRoute(
        navigatorKey: _shell,
        builder: (BuildContext c, GoRouterState s, Widget hijo) =>
            AppShell(rutaActual: s.matchedLocation, child: hijo),
        routes: <RouteBase>[
          GoRoute(path: Rutas.inicio, builder: (_, _) => const HomeScreen()),
          GoRoute(path: Rutas.casos, builder: (_, _) => const CasesScreen()),
          GoRoute(path: Rutas.bandeja, builder: (_, _) => const InboxScreen()),
          GoRoute(path: Rutas.perfil, builder: (_, _) => const ProfileScreen()),
        ],
      ),

      // ── Pantalla completa (sin barra inferior) ───────────────────────
      GoRoute(
        path: Rutas.chat,
        builder: (BuildContext c, GoRouterState s) => ChatScreen(
          sessionId: s.uri.queryParameters['sesion'],
          matterId: s.uri.queryParameters['caso'],
          promptInicial: s.uri.queryParameters['prompt'],
          editArtifactId: s.uri.queryParameters['artefacto'],
          seleccion: s.uri.queryParameters['seleccion'],
          lanzarWorkflow: s.uri.queryParameters['workflow'] == '1',
        ),
      ),
      GoRoute(
        path: '${Rutas.documento}/:id',
        builder: (BuildContext c, GoRouterState s) => DocumentScreen(
          documentoId: s.pathParameters['id']!,
          artefacto: s.extra is Artefacto ? s.extra! as Artefacto : null,
        ),
      ),
      GoRoute(
        path: '${Rutas.casos}/:id',
        builder: (BuildContext c, GoRouterState s) =>
            CaseDetailScreen(matterId: s.pathParameters['id']!),
      ),
      GoRoute(path: Rutas.audiencia, builder: (_, _) => const HearingsScreen()),
      GoRoute(path: Rutas.privacidad, builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: Rutas.legal, builder: (_, _) => const LegalScreen()),
      GoRoute(
        path: Rutas.eliminarCuenta,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState estado) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${estado.uri}')),
    ),
  );
});

/// Reevalúa el `redirect` cuando cambian la sesión o el consentimiento.
class _Escucha extends ChangeNotifier {
  _Escucha(this._ref) {
    _ref.listen<bool>(autenticadoProvider, (_, _) => notifyListeners());
    _ref.listen<AsyncValue<AiConsent>>(
      aiConsentProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
}
