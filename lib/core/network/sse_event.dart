/// Contrato de eventos SSE del backend.
///
/// Fuente de verdad: `Legal_AI_Backend/app/bridge.py`. El cable es
/// `event: <nombre>\ndata: <json>\n\n`, y el latido es el comentario `:hb`.
///
/// Se modela con clases selladas de Dart 3 en vez de `freezed`: no hace falta
/// generación de código y el `switch` exhaustivo lo comprueba el compilador.
library;

sealed class SseEvent {
  const SseEvent();

  /// Construye el evento tipado a partir del nombre y la carga.
  ///
  /// Un evento desconocido **no es un error**: el backend puede añadir tipos
  /// nuevos y una app antigua debe seguir funcionando. Se devuelve
  /// [SseUnknown] y la UI lo ignora.
  factory SseEvent.desde(String nombre, Map<String, dynamic> d) {
    return switch (nombre) {
      'text_delta' => TextDelta(
        texto: d['text'] as String? ?? '',
        messageId: d['message_id'] as String?,
      ),
      'thinking' => Thinking(
        texto: d['text'] as String? ?? '',
        messageId: d['message_id'] as String?,
      ),
      'phase' => Phase(
        nombre: d['name'] as String? ?? '',
        estado: d['status'] as String? ?? '',
      ),
      'agent_step' => AgentStep(datos: d),
      'tool_call' => ToolCall(
        id: d['id'] as String? ?? '',
        nombre: d['name'] as String? ?? '',
        entrada: d['input'],
      ),
      'tool_result' => ToolResult(datos: d),
      'verify_progress' => VerifyProgress(
        estado: d['status'] as String? ?? '',
        datos: d,
      ),
      'artifact' => Artifact(datos: d),
      'approval_request' => ApprovalRequest(datos: d),
      'hooks' => Hooks(
        hooks: (d['hooks'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> h) => Hook(
                etiqueta: h['label'] as String? ?? '',
                tipo: h['tipo'] as String? ?? '',
                prompt: h['prompt'] as String? ?? '',
              ),
            )
            .toList(growable: false),
      ),
      'case_suggestion' => CaseSuggestion(
        nombre: d['nombre'] as String?,
        cliente: d['cliente'] as String?,
        contraparte: d['contraparte'] as String?,
        materia: d['materia'] as String?,
        radicado: d['radicado'] as String?,
        sessionId: d['session_id'] as String?,
      ),
      'case_created' => CaseCreated(
        matterId: d['matter_id'] as String? ?? '',
        codigo: d['code'] as String?,
        nombre: d['nombre'] as String? ?? 'Nuevo caso',
        radicado: d['radicado'] as String?,
        sessionId: d['session_id'] as String?,
      ),
      'credits' => Credits(
        saldo: (d['balance'] as num?)?.toInt(),
        tope: (d['cap'] as num?)?.toInt(),
        bajo: d['low'] as bool? ?? false,
      ),
      'usage' => Usage(datos: d),
      'blocked' => Blocked(
        razon: d['reason'] as String? ?? 'desconocida',
        mensaje: d['message'] as String?,
      ),
      'error' => ErrorEvent(
        mensaje: d['message'] as String? ?? 'Error desconocido',
        subtipo: d['subtype'] as String?,
      ),
      'done' => Done(
        sessionId: d['session_id'] as String?,
        resultado: d['result'] as String?,
      ),
      _ => SseUnknown(nombre: nombre, datos: d),
    };
  }
}

/// Fragmento de texto de la respuesta. Se concatena en orden.
final class TextDelta extends SseEvent {
  const TextDelta({required this.texto, this.messageId});
  final String texto;
  final String? messageId;
}

/// Razonamiento del agente. Se muestra colapsado ("Pensó durante X s").
final class Thinking extends SseEvent {
  const Thinking({required this.texto, this.messageId});
  final String texto;
  final String? messageId;
}

/// Fase de actividad en curso, para el timeline vivo.
final class Phase extends SseEvent {
  const Phase({required this.nombre, required this.estado});
  final String nombre;
  final String estado;
}

final class AgentStep extends SseEvent {
  const AgentStep({required this.datos});
  final Map<String, dynamic> datos;
}

final class ToolCall extends SseEvent {
  const ToolCall({required this.id, required this.nombre, this.entrada});
  final String id;
  final String nombre;
  final Object? entrada;
}

final class ToolResult extends SseEvent {
  const ToolResult({required this.datos});
  final Map<String, dynamic> datos;
}

/// Progreso de la verificación de fuentes contra fuente oficial.
final class VerifyProgress extends SseEvent {
  const VerifyProgress({required this.estado, required this.datos});
  final String estado;
  final Map<String, dynamic> datos;
}

/// Documento generado por el agente.
final class Artifact extends SseEvent {
  const Artifact({required this.datos});
  final Map<String, dynamic> datos;

  String? get id => datos['id'] as String?;
  String? get nombre =>
      datos['name'] as String? ?? datos['filename'] as String?;
}

final class ApprovalRequest extends SseEvent {
  const ApprovalRequest({required this.datos});
  final Map<String, dynamic> datos;
}

/// Sugerencia de próxima acción (Hook Model).
final class Hook {
  const Hook({
    required this.etiqueta,
    required this.tipo,
    required this.prompt,
  });
  final String etiqueta;
  final String tipo;
  final String prompt;
}

final class Hooks extends SseEvent {
  const Hooks({required this.hooks});
  final List<Hook> hooks;
}

/// El agente cree que esta conversación es un caso, y **pregunta**.
///
/// Es una propuesta, no un hecho: el backend la emite cuando la señal no es lo
/// bastante fuerte para crear el expediente solo. Crear casos a espaldas del
/// abogado le ensucia el despacho con carpetas que él no pidió, así que aquí
/// solo se ofrece un botón.
final class CaseSuggestion extends SseEvent {
  const CaseSuggestion({
    this.nombre,
    this.cliente,
    this.contraparte,
    this.materia,
    this.radicado,
    this.sessionId,
  });

  final String? nombre;
  final String? cliente;
  final String? contraparte;
  final String? materia;
  final String? radicado;
  final String? sessionId;
}

/// El agente ya creó el caso (señal fuerte: normalmente venía un radicado).
///
/// El resto del turno queda ligado a ese expediente en el servidor, así que la
/// app **tiene** que enterarse: si no, sigue mandando los turnos siguientes sin
/// `matter_id` y el trabajo se guarda fuera del caso.
final class CaseCreated extends SseEvent {
  const CaseCreated({
    required this.matterId,
    required this.nombre,
    this.codigo,
    this.radicado,
    this.sessionId,
  });

  final String matterId;
  final String nombre;
  final String? codigo;
  final String? radicado;
  final String? sessionId;
}

/// Saldo de créditos tras el turno.
final class Credits extends SseEvent {
  const Credits({this.saldo, this.tope, this.bajo = false});
  final int? saldo;
  final int? tope;
  final bool bajo;
}

final class Usage extends SseEvent {
  const Usage({required this.datos});
  final Map<String, dynamic> datos;
}

/// Acción bloqueada: sin créditos, sin turnos, plan agotado.
///
/// ⚠️ La UI **informa y no vende**: sin botón de compra ni enlace a la web
/// (Apple 3.1.1 / 3.1.3).
final class Blocked extends SseEvent {
  const Blocked({required this.razon, this.mensaje});
  final String razon;
  final String? mensaje;
}

final class ErrorEvent extends SseEvent {
  const ErrorEvent({required this.mensaje, this.subtipo});
  final String mensaje;
  final String? subtipo;
}

/// Fin del turno. El backend ya persistió todo.
final class Done extends SseEvent {
  const Done({this.sessionId, this.resultado});
  final String? sessionId;
  final String? resultado;
}

/// Latido `:hb`. Mantiene viva la conexión durante bloques largos sin salida.
///
/// **No es ruido:** su ausencia durante 90 s es lo único que debe considerarse
/// desconexión.
final class Heartbeat extends SseEvent {
  const Heartbeat();
}

/// Evento no reconocido. Compatibilidad hacia adelante.
final class SseUnknown extends SseEvent {
  const SseUnknown({required this.nombre, required this.datos});
  final String nombre;
  final Map<String, dynamic> datos;
}
