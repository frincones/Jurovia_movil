import '../../shared/models/me.dart';
import '../store_policy.dart';

/// Dónde se contrató el plan del usuario.
enum FuenteSuscripcion {
  /// No hay suscripción: plan gratuito o prueba.
  ninguna,

  /// Se contrató fuera de la app (hoy: siempre).
  otraPlataforma,

  /// Se compró dentro de la app con IAP. **Todavía no existe.**
  dentroDeLaApp,
}

/// Qué intentaba hacer el usuario cuando apareció el muro.
///
/// El párrafo de explicación es **siempre el mismo**; lo que cambia es la
/// primera línea, que tiene que responder a lo que la persona acaba de tocar.
/// Un diálogo genérico obliga a releerlo para saber si va contigo.
enum MotivoMuro {
  /// Tocó «Gestionar suscripción» teniendo un plan de pago.
  gestionar,

  /// Quiere otro plan pero hoy no paga (Free o prueba).
  cambiarPlan,

  /// Se quedó sin turnos o sin créditos.
  sinCuota,

  /// La función no está incluida en su plan.
  funcionNoIncluida,
}

/// Textos del muro de plan. **Única copia en toda la app.**
///
/// Que vivan aquí no es estética: es lo que permite que la auditoría los
/// verifique en un solo sitio y que cambiarlos sea una decisión consciente en
/// vez de un descuido en la quinta pantalla.
///
/// ⚠️ **La línea que no se puede cruzar** (Apple 3.1.1 / 3.1.3):
/// la app puede decir **que** el plan se gestiona en otro lado, y **no puede**
/// decir **dónde**. Nada de URLs, precios, nombres de plataforma ni verbos de
/// compra («suscríbete», «mejora tu plan», «continuar con Pro»).
///
/// Lo que sí permite Apple es esto mismo: **3.1.3(b) Multiplatform Services**
/// deja usar dentro de la app una suscripción contratada fuera. Explicarlo con
/// claridad es legítimo; invitar a comprar, no.
abstract final class TextosMuro {
  /// El párrafo que explica el modelo. Se repite en todos los motivos **a
  /// propósito**: es la parte que no debe variar de una pantalla a otra.
  static const String explicacionConSuscripcion =
      'Esta suscripción no se puede cancelar ni modificar desde esta app '
      'porque se contrató en otra plataforma. Para gestionarla, inicia sesión '
      'en la cuenta con la que hiciste la compra.';

  static const String explicacionSinSuscripcion =
      'Tu plan no se puede cambiar desde esta app. Se administra desde la '
      'cuenta con la que te registraste.';

  static const String botonCerrar = 'Entendido';

  /// Etiqueta de la fila de Perfil e Inicio.
  static String filaGestionar(bool esPago) =>
      esPago ? 'Gestionar suscripción' : 'Tu plan';

  static String titulo(MotivoMuro motivo) => switch (motivo) {
    MotivoMuro.gestionar => 'Gestionar tu suscripción',
    MotivoMuro.cambiarPlan => 'Tu plan',
    MotivoMuro.sinCuota => 'Alcanzaste el límite de tu plan',
    MotivoMuro.funcionNoIncluida => 'No incluido en tu plan',
  };

  /// Explicación del modelo, según haya o no suscripción que gestionar.
  ///
  /// Decirle «tu suscripción» a alguien que está en Free sería falso, y quien
  /// paga no quiere leer que «se administra desde la cuenta con la que te
  /// registraste» cuando lo que busca es cancelar.
  static String explicacion(FuenteSuscripcion fuente) =>
      fuente == FuenteSuscripcion.otraPlataforma
      ? explicacionConSuscripcion
      : explicacionSinSuscripcion;
}

/// De dónde sale el cobro y qué se le puede decir al usuario.
abstract final class BillingPolicy {
  /// Origen de la suscripción del usuario.
  ///
  /// Hoy **no hace falta preguntárselo al backend**: `/api/me` no devuelve el
  /// origen del cobro y no necesita devolverlo, porque solo existe un carril de
  /// pago —Paddle en la web (`app/api/paddle.py`)— y no hay IAP. Que el 100 %
  /// de los planes de pago se contrataran fuera es un hecho de la arquitectura,
  /// no una suposición.
  ///
  /// Cuando exista IAP, el backend tendrá que añadir
  /// `access.billing_source ∈ {paddle, apple, google}` y esta función leerlo:
  /// sin ese campo se le mostraría el diálogo equivocado a quien pagó dentro.
  static FuenteSuscripcion fuente(Me? me) {
    if (me == null || !me.esPago) return FuenteSuscripcion.ninguna;
    if (StorePolicy.allowsInAppPurchase) {
      // Rama muerta hoy (la invariante es `false`), escrita para que el día
      // que se encienda IAP el fallo sea de compilación y no de producto.
      return FuenteSuscripcion.dentroDeLaApp;
    }
    return FuenteSuscripcion.otraPlataforma;
  }

  /// Motivo por defecto al tocar la fila de plan.
  static MotivoMuro motivoPara(Me? me) =>
      (me?.esPago ?? false) ? MotivoMuro.gestionar : MotivoMuro.cambiarPlan;
}
