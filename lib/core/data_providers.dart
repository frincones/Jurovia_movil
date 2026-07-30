import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/briefing.dart';
import '../shared/models/caso.dart';
import 'providers.dart';

/// Proveedores de datos de lectura. Todos van contra el backend, que resuelve
/// `org_id` server-side: la app nunca filtra por despacho.

List<T> _mapear<T>(
  List<dynamic> crudos,
  T Function(Map<String, dynamic>) desde,
) => crudos
    .whereType<Map<dynamic, dynamic>>()
    .map((Map<dynamic, dynamic> m) => desde(Map<String, dynamic>.from(m)))
    .toList();

// ────────────────────────────── Briefing ─────────────────────────────

/// El briefing del día: **una sola llamada** que reemplaza las cuatro que
/// hacía el Inicio (casos + atención + términos + no leídas).
///
/// No es solo eficiencia: el servidor prioriza con un `score` determinista que
/// el cliente no puede replicar (cruza términos, aprobaciones y progreso), y
/// entrega exactamente lo mismo que el Parte Diario por correo. Que la app y
/// el correo digan lo mismo es el punto.
///
/// **Fail-open**: si el endpoint falla, se devuelve un briefing vacío en vez
/// de propagar el error. El Inicio nunca debe quedarse en rojo — es la primera
/// pantalla que ve el abogado, y su plan B (escribirle al agente) sigue
/// funcionando aunque el resumen no cargue.
final AutoDisposeFutureProvider<Briefing> briefingProvider =
    FutureProvider.autoDispose<Briefing>((Ref ref) async {
      try {
        final Map<String, dynamic> j = await ref
            .watch(apiClientProvider)
            .get('/api/briefing');
        return Briefing.fromJson(j);
      } on Object {
        return Briefing.vacio;
      }
    });

// ─────────────────────────────── Casos ───────────────────────────────

final AutoDisposeFutureProvider<List<Caso>> casosProvider =
    FutureProvider.autoDispose<List<Caso>>((Ref ref) async {
      final List<dynamic> crudos = await ref
          .watch(apiClientProvider)
          .getLista('/api/missions');
      return _mapear(crudos, Caso.fromJson);
    });

/// Criterios de la lista de casos. Es un `record`: Dart le da igualdad
/// estructural, así que sirve de clave de `family` sin escribir `==`.
typedef ConsultaCasos = ({String texto, String? estado, bool? vigilancia});

/// Lista de casos **filtrada por el servidor**.
///
/// Se busca en el backend, no en la lista ya descargada, por dos razones que
/// no se pueden replicar en el cliente:
///
///  1. El servidor busca **dentro del contenido de los documentos** del caso
///     (tabla `chunks`), que la app nunca descarga.
///  2. La lista local está paginada (50): buscar sobre ella solo encuentra lo
///     que ya se había traído, y el caso viejo que el abogado busca es
///     justamente el que no está.
///
/// Sin `texto` ni filtros la llamada es idéntica a la de siempre.
final AutoDisposeFutureProviderFamily<List<Caso>, ConsultaCasos>
casosFiltradosProvider = FutureProvider.autoDispose
    .family<List<Caso>, ConsultaCasos>((Ref ref, ConsultaCasos c) async {
      final String texto = c.texto.trim();
      final List<dynamic> crudos = await ref
          .watch(apiClientProvider)
          .getLista(
            '/api/missions',
            query: <String, dynamic>{
              if (texto.isNotEmpty) 'q': texto,
              if (c.estado != null) 'estado': c.estado,
              if (c.vigilancia != null) 'vigilancia': c.vigilancia,
            },
          );
      return _mapear(crudos, Caso.fromJson);
    });

/// Casos que el backend marca como «requieren atención».
final AutoDisposeFutureProvider<List<Caso>> casosAtencionProvider =
    FutureProvider.autoDispose<List<Caso>>((Ref ref) async {
      try {
        final List<dynamic> crudos = await ref
            .watch(apiClientProvider)
            .getLista('/api/missions/attention');
        return _mapear(crudos, Caso.fromJson);
      } on Object {
        return <Caso>[];
      }
    });

final AutoDisposeFutureProviderFamily<Caso, String> casoProvider =
    FutureProvider.autoDispose.family<Caso, String>((Ref ref, String id) async {
      final Map<String, dynamic> j = await ref
          .watch(apiClientProvider)
          .get('/api/missions/$id');
      return Caso.fromJson(j);
    });

final AutoDisposeFutureProviderFamily<List<Actuacion>, String>
timelineCasoProvider = FutureProvider.autoDispose
    .family<List<Actuacion>, String>((Ref ref, String id) async {
      final List<dynamic> crudos = await ref
          .watch(apiClientProvider)
          .getLista('/api/missions/$id/timeline');
      return _mapear(crudos, Actuacion.fromJson);
    });

/// Documentos de un caso. El backend devuelve nombre y fecha.
final AutoDisposeFutureProviderFamily<List<Map<String, dynamic>>, String>
documentosCasoProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((Ref ref, String id) async {
      final List<dynamic> crudos = await ref
          .watch(apiClientProvider)
          .getLista('/api/missions/$id/documents');
      return crudos
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
          .toList();
    });

// ──────────────────────── Términos y pendientes ──────────────────────

final AutoDisposeFutureProvider<List<Termino>> terminosProvider =
    FutureProvider.autoDispose<List<Termino>>((Ref ref) async {
      final List<dynamic> crudos = await ref
          .watch(apiClientProvider)
          .getLista('/api/deadlines');
      return _mapear(crudos, Termino.fromJson)..sort((Termino a, Termino b) {
        final DateTime x = a.vence ?? DateTime(2100);
        final DateTime y = b.vence ?? DateTime(2100);
        return x.compareTo(y);
      });
    });

final AutoDisposeFutureProvider<List<Termino>> tareasProvider =
    FutureProvider.autoDispose<List<Termino>>((Ref ref) async {
      final List<dynamic> crudos = await ref
          .watch(apiClientProvider)
          .getLista('/api/tasks');
      return _mapear(crudos, Termino.fromJson);
    });

// ────────────────────────────── Bandeja ──────────────────────────────

final AutoDisposeFutureProvider<List<Notificacion>> notificacionesProvider =
    FutureProvider.autoDispose<List<Notificacion>>((Ref ref) async {
      final List<dynamic> crudos = await ref
          .watch(apiClientProvider)
          .getLista('/api/notifications');
      return _mapear(crudos, Notificacion.fromJson)
        ..sort((Notificacion a, Notificacion b) {
          final DateTime x = a.creadaEn ?? DateTime(1970);
          final DateTime y = b.creadaEn ?? DateTime(1970);
          return y.compareTo(x);
        });
    });

final AutoDisposeFutureProvider<int> noLeidasProvider =
    FutureProvider.autoDispose<int>((Ref ref) async {
      try {
        final Map<String, dynamic> j = await ref
            .watch(apiClientProvider)
            .get('/api/notifications/unread-count');
        return (j['count'] as num?)?.toInt() ??
            (j['unread'] as num?)?.toInt() ??
            0;
      } on Object {
        // El badge no puede tumbar la pantalla.
        return 0;
      }
    });

// ─────────────────────────────── Planes ──────────────────────────────

/// Catálogo de planes **desde el backend**.
///
/// ⚠️ Nunca escribir precios en el cliente: el prototipo traía valores que no
/// existen en producción (arquitectura §14, contradicción 4).
final AutoDisposeFutureProvider<Map<String, dynamic>> planesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((Ref ref) async {
      return ref.watch(apiClientProvider).get('/api/plans');
    });

// ──────────────────────────── Integraciones ──────────────────────────

final AutoDisposeFutureProvider<List<Map<String, dynamic>>>
integracionesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  Ref ref,
) async {
  try {
    final List<dynamic> crudos = await ref
        .watch(apiClientProvider)
        .getLista('/api/integrations');
    return crudos
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
        .toList();
  } on Object {
    return <Map<String, dynamic>>[];
  }
});
