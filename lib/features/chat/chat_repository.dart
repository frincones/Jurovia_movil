import '../../compliance/ai_consent/ai_consent_gate.dart';
import '../../core/network/sse_client.dart';
import '../../core/network/sse_event.dart';

/// Acceso al agente.
///
/// ⚠️ **Exige un [AiConsentToken] en el constructor.**
///
/// Ese token solo lo puede emitir [AiConsentGate.tokenPara], y solo lo emite si
/// hay consentimiento vigente. Así el **compilador** impide invocar al agente
/// sin permiso del usuario: no depende de que alguien recuerde comprobarlo, ni
/// de que el router esté bien configurado.
///
/// Es la implementación del requisito AuditCheck C8.1 (Apple 5.1.2(i)) como
/// propiedad estructural del código, no como una comprobación más.
// Dart no permite parámetros con nombre privado (`this._sse`), así que los
// campos se asignan en la lista de inicialización. La regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

class ChatRepository {
  ChatRepository({
    required SseClient sse,
    required AiConsentToken consentimiento,
  }) : _sse = sse,
       _consentimiento = consentimiento;

  final SseClient _sse;

  /// Se conserva como prueba de que el consentimiento existía al construir el
  /// repositorio. No se usa en tiempo de ejecución: su valor es la garantía en
  /// tiempo de compilación.
  // ignore: unused_field
  final AiConsentToken _consentimiento;

  /// Envía un turno y devuelve el stream de eventos.
  ///
  /// `POST /api/chat/{sessionId}` responde `text/event-stream`.
  Stream<SseEvent> enviar({
    required String sessionId,
    required String mensaje,
    String? matterId,
    List<String>? documentIds,
    String? editArtifactId,
    String? seleccion,
  }) {
    return _sse.stream(
      ruta: '/api/chat/$sessionId',
      cuerpo: <String, dynamic>{
        'message': mensaje,
        // Entrada null-aware sobre el valor: se omite si `matterId` es null.
        'matter_id': ?matterId,
        if (documentIds != null && documentIds.isNotEmpty)
          'document_ids': documentIds,
        // Edición de un documento existente conservando su formato: el backend
        // devuelve una versión nueva del artefacto.
        'edit_artifact_id': ?editArtifactId,
        'selection': ?seleccion,
      },
    );
  }

  /// Orquesta el workflow del pack de una misión (F3.07).
  ///
  /// `POST /api/missions/{id}/run-workflow` usa **el mismo contrato SSE** que
  /// el chat, así que la UI no necesita nada especial: reutiliza el mismo
  /// pipeline de eventos.
  Stream<SseEvent> ejecutarWorkflow({required String matterId}) {
    return _sse.stream(ruta: '/api/missions/$matterId/run-workflow');
  }

  /// Cancela el stream en curso.
  ///
  /// Ojo: **no detiene el turno en el servidor**. El backend sigue y persiste
  /// el resultado; al volver, la UI lo recupera con `GET /api/sessions/{id}`.
  void cancelar() => _sse.cancelar();
}
