import '../store_policy.dart';

/// Estado del consentimiento de IA de este usuario en este dispositivo.
///
/// ⚠️ **Se guarda en local, no en el backend.**
///
/// El backend tiene una tabla `consents`, pero es para Habeas Data
/// (`accepted_tos` / `accepted_privacy` / `doc_version`, Ley 1581) y no cubre
/// el tratamiento por IA de terceros. `GET /api/me` tampoco expone nada de esto.
///
/// Guardarlo en local **cumple** el requisito de Apple 5.1.2(i) —el permiso se
/// obtiene antes de enviar nada— pero tiene un límite conocido: el usuario
/// vuelve a consentir si reinstala o cambia de dispositivo. Sincronizarlo entre
/// dispositivos exige trabajo de backend (columna + endpoint), que está fuera
/// del alcance de la Fase 1.
class AiConsent {
  const AiConsent({this.aceptado = false, this.version = 0, this.fecha});

  final bool aceptado;
  final int version;
  final DateTime? fecha;

  static const AiConsent ninguno = AiConsent();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'aceptado': aceptado,
    'version': version,
    'fecha': fecha?.toIso8601String(),
  };

  factory AiConsent.fromJson(Map<String, dynamic> j) => AiConsent(
    aceptado: j['aceptado'] as bool? ?? false,
    version: (j['version'] as num?)?.toInt() ?? 0,
    fecha: DateTime.tryParse(j['fecha'] as String? ?? ''),
  );
}

/// Prueba de que el usuario consintió el envío de sus datos a la IA de terceros.
///
/// **Solo [AiConsentGate] puede crear una instancia**: el constructor es
/// privado. Ningún repositorio puede fabricarse uno.
///
/// Es lo que convierte el consentimiento en una **propiedad estructural**:
/// `ChatRepository` exige un [AiConsentToken] en el constructor, así que el
/// compilador impide invocar al agente sin consentimiento. No depende de que
/// nadie recuerde comprobarlo.
final class AiConsentToken {
  const AiConsentToken._();
}

/// Puerta de consentimiento de IA — AuditCheck C8.1–C8.7 · Apple 5.1.2(i).
///
/// > *"You must clearly disclose where personal data will be shared with third
/// > parties, **including with third-party AI**, and obtain explicit permission
/// > before doing so."*
///
/// Jurovia envía el contenido de los casos —con datos de clientes de abogados—
/// a [StorePolicy.aiProvider]. Sin consentimiento, el agente **no es
/// alcanzable**: ni navegando ni por código.
abstract final class AiConsentGate {
  /// Proveedor que la pantalla de consentimiento debe **nombrar**.
  /// No basta con "servicios de terceros".
  static const String provider = StorePolicy.aiProvider;

  /// Versión del texto consentido.
  ///
  /// Subirla obliga a volver a pedir el consentimiento a todo el mundo. Se sube
  /// cuando cambia el proveedor, los datos que se envían o la finalidad.
  static const int version = 1;

  /// Datos que salen hacia el proveedor. Se muestran literalmente al usuario.
  static const List<String> datosCompartidos = <String>[
    'Los mensajes que escribes al asistente',
    'Los documentos que adjuntas a una consulta',
    'El contexto del caso sobre el que preguntas',
  ];

  /// ¿Puede este usuario usar el agente?
  static bool canUseAgent(AiConsent? consent) {
    if (consent == null) return false;
    return consent.aceptado && consent.version >= version;
  }

  /// Emite el token. **Único punto del código que lo crea.**
  static AiConsentToken? tokenPara(AiConsent? consent) =>
      canUseAgent(consent) ? const AiConsentToken._() : null;

  /// Consentimiento reciente, listo para persistir.
  static AiConsent otorgar(DateTime ahora) =>
      AiConsent(aceptado: true, version: version, fecha: ahora);
}
