import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../compliance/ai_consent/ai_consent_gate.dart';
import '../features/auth/auth_service.dart';
import '../shared/models/me.dart';
import 'network/api_client.dart';
import 'network/sse_client.dart';
import 'storage/secure_store.dart';

/// Proveedores raíz de la app.

final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>(
  (Ref ref) => SecureStore(),
);

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(Supabase.instance.client),
);

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (Ref ref) => ApiClient(tokens: ref.watch(authServiceProvider)),
);

final Provider<SseClient> sseClientProvider = Provider<SseClient>(
  (Ref ref) => SseClient(dio: ref.watch(apiClientProvider).dio),
);

/// Estado de sesión de Supabase. Emite en cada login/logout/refresh.
final StreamProvider<AuthState> authStateProvider = StreamProvider<AuthState>(
  (Ref ref) => ref.watch(authServiceProvider).cambios,
);

/// ¿Hay sesión ahora mismo? Lectura síncrona para el `redirect` del router.
final Provider<bool> autenticadoProvider = Provider<bool>((Ref ref) {
  ref.watch(authStateProvider); // se recalcula al cambiar la sesión
  return ref.watch(authServiceProvider).autenticado;
});

/// Consentimiento de IA, leído del almacén cifrado del dispositivo.
final AsyncNotifierProvider<AiConsentNotifier, AiConsent> aiConsentProvider =
    AsyncNotifierProvider<AiConsentNotifier, AiConsent>(AiConsentNotifier.new);

class AiConsentNotifier extends AsyncNotifier<AiConsent> {
  @override
  Future<AiConsent> build() =>
      ref.watch(secureStoreProvider).leerConsentimientoIa();

  /// Acepta el tratamiento por IA. Acción afirmativa explícita del usuario.
  Future<void> aceptar() async {
    final AiConsent c = AiConsentGate.otorgar(DateTime.now());
    await ref.read(secureStoreProvider).guardarConsentimientoIa(c);
    state = AsyncData<AiConsent>(c);
  }

  /// Revoca el consentimiento (Ajustes → Privacidad y datos).
  Future<void> revocar() async {
    await ref.read(secureStoreProvider).revocarConsentimientoIa();
    state = const AsyncData<AiConsent>(AiConsent.ninguno);
  }
}

/// `GET /api/me` — la llamada de arranque.
///
/// Devuelve identidad, plan, *entitlements*, *features* y modelo de acceso ya
/// resueltos server-side. **Nada de esto se recalcula en el cliente.**
final AsyncNotifierProvider<MeNotifier, Me?> meProvider =
    AsyncNotifierProvider<MeNotifier, Me?>(MeNotifier.new);

class MeNotifier extends AsyncNotifier<Me?> {
  @override
  Future<Me?> build() async {
    if (!ref.watch(autenticadoProvider)) return null;
    final Map<String, dynamic> j = await ref
        .watch(apiClientProvider)
        .get('/api/me');
    return Me.fromJson(j);
  }

  /// Recarga desde el servidor. Se llama al volver a primer plano y tras cada
  /// `done` del chat (§11.3 de la arquitectura).
  Future<void> refrescar() async {
    state = const AsyncLoading<Me?>();
    state = await AsyncValue.guard<Me?>(() async {
      if (!ref.read(autenticadoProvider)) return null;
      final Map<String, dynamic> j = await ref
          .read(apiClientProvider)
          .get('/api/me');
      return Me.fromJson(j);
    });
  }
}
