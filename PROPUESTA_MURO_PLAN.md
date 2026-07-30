# Propuesta · Muro de plan — «esto no se gestiona aquí»

**Fecha:** 29-jul-2026 · **Ámbito:** app móvil (Flutter) · **Backend:** sin cambios

---

## §1 · El problema real

Hoy la app **no vende nada** y eso está bien resuelto: `StorePolicy` compila
cuatro invariantes en `false`, la auditoría busca textos de compra en cada
*commit*, y la tarjeta de plan de Perfil no tiene botón.

El problema no es que venda. Es que **calla**.

Hay cinco puntos donde el abogado choca con el techo de su plan, y en todos la
app o no dice nada o dice «no puedes» sin explicar por qué:

| Superficie | Qué pasa hoy | Qué concluye el usuario |
| --- | --- | --- |
| `_TarjetaPlan` (Perfil) | Muestra plan y cuota. Sin botón, sin explicación | «Está roto / falta la pantalla» |
| Evento `blocked` (chat) | Pinta el mensaje del servidor y punto | «Se me acabó… ¿y ahora qué?» |
| `Composer.motivoBloqueo` | Una línea gris | Igual |
| `_ResumenCuenta` (Inicio) | Píldora informativa **no tocable** | Toca, no pasa nada, lo lee como bug |
| Módulos por `entitlements` | No aparecen | «A mí no me salió esa función» |

Lo que hace la app de Claude en las capturas es exactamente lo contrario:
**tiene** una fila «Manage subscription», y al tocarla responde con honestidad
—«esto se compró en otra plataforma, gestiónalo donde lo compraste»— en vez de
esconder el tema. Eso no es una concesión: es mejor producto **y** más seguro
frente a la revisión, porque un revisor que toca «Gestionar suscripción» y
recibe una explicación clara cierra el tema; uno que toca una píldora muerta se
pregunta qué le están ocultando.

### Por qué esto sí lo permite Apple

La regla que prohíbe vender es **3.1.1** (IAP obligatorio) y la que prohíbe
*steering* es **3.1.3** (no enlazar ni invitar a pagar fuera). Pero **3.1.3(b)
Multiplatform Services** permite explícitamente que contenido o suscripciones
adquiridos en otro sitio **se usen** dentro de la app.

La línea exacta está en el texto del diálogo: la app puede decir **que** se
gestiona en otro lado, y **no puede** decir **dónde**. El texto de Claude lo
respeta —«log in to your account where you made the purchase»— sin nombrar
`claude.ai` ni poner un enlace. La traducción tiene que conservar esa
propiedad: **cero URLs, cero precios, cero verbos de compra.**

---

## §2 · La propuesta

Un solo componente, un solo texto, invocado desde las cinco superficies.

```
lib/compliance/billing/
├─ billing_policy.dart   ← la única copia del texto + de dónde sale el plan
└─ muro_plan.dart        ← el diálogo + las filas de Perfil
```

Que el texto viva en **un** archivo no es estética: es lo que permite que la
auditoría lo verifique en un sitio y que cambiarlo sea una decisión consciente,
no un descuido en la quinta pantalla.

### 2.1 · El texto (español, calcado del patrón)

**Caso «tengo plan de pago»** — el de las capturas:

> **Gestionar tu suscripción**
>
> Esta suscripción no se puede cancelar ni modificar desde esta app porque se
> contrató en otra plataforma. Para gestionarla, inicia sesión en la cuenta con
> la que hiciste la compra.
>
> `Entendido`

**Caso «estoy en Free o en prueba»** — no hay suscripción que gestionar, así
que decir «tu suscripción» sería falso:

> **Tu plan**
>
> Tu plan no se puede cambiar desde esta app. Se administra desde la cuenta con
> la que te registraste, en el mismo lugar donde gestionas tu facturación.
>
> `Entendido`

**Caso «me quedé sin cuota»** — primero lo concreto, después la explicación:

> **Sin turnos por hoy**
>
> Se te acabaron los turnos de hoy. Vuelven mañana.
>
> Tu plan no se puede cambiar desde esta app. Se administra desde la cuenta con
> la que te registraste.
>
> `Entendido`

**Caso «esta función no está en mi plan»**:

> **No incluido en tu plan**
>
> Vigilancia judicial no está incluida en tu plan actual.
>
> Tu plan no se puede cambiar desde esta app. […]

### 2.2 · La API del componente

```dart
// Un motivo por superficie. El párrafo de explicación es SIEMPRE el mismo;
// lo que cambia es la primera línea, que responde a lo que el usuario intentó.
enum MotivoMuro { gestionar, cambiarPlan, sinCuota, funcionNoIncluida }

await MuroPlan.mostrar(context, motivo: MotivoMuro.gestionar, me: me);

// Guarda para módulos con entitlement: devuelve false y explica.
if (!await MuroPlan.exigir(context, 'vigilancia', me: me)) return;
```

### 2.3 · Cableado cross-módulos

| # | Módulo | Cambio | Motivo |
| --- | --- | --- | --- |
| 1 | **Perfil** | Fila «Gestionar suscripción» bajo la tarjeta de plan | `gestionar` / `cambiarPlan` según `me.esPago` |
| 2 | **Inicio** | La píldora `_ResumenCuenta` pasa a ser tocable | idem |
| 3 | **Chat · `blocked`** | El aviso gana un «¿Por qué?» | `sinCuota`, con el mensaje del servidor arriba |
| 4 | **Composer** | El motivo de bloqueo por cuota se vuelve tocable | `sinCuota` |
| 5 | **Módulos** | `MuroPlan.exigir()` antes de entrar | `funcionNoIncluida` |

### 2.4 · Una desviación deliberada de las capturas

**No se añade «Restaurar compras».**

En la app de Claude esa fila existe porque **sí** tienen IAP: hay compras que
restaurar. Jurovia no tiene ninguna (`allowsInAppPurchase = false`), así que un
botón «Restaurar compras» que no puede restaurar nada es una promesa vacía —y
los revisores de Apple **la tocan**. Añadirla sería crear la única función de la
app que no hace nada.

Si algún día se implementa IAP, la fila entra junto con él, no antes.

---

## §3 · De dónde sale «se contrató en otra plataforma»

Hoy no hace falta preguntárselo al backend: **`/api/me` no devuelve el origen
del cobro, y no necesita devolverlo, porque solo existe un carril de pago.**
Todo plan de pago pasó por Paddle en la web (`app/api/paddle.py`); no hay IAP.
Por tanto, desde la app, el 100 % de las suscripciones se contrataron «en otra
plataforma» — es un hecho de la arquitectura, no una suposición.

Aun así se modela como una función con un solo punto de cambio:

```dart
static FuenteSuscripcion fuente(Me? me) {
  // Cuando exista IAP, el backend añadirá `billing.source` y esto lo leerá.
  // Mientras haya un único carril, deducirlo es correcto y no inventa nada.
  if (me == null || !me.esPago) return FuenteSuscripcion.ninguna;
  return FuenteSuscripcion.otraPlataforma;
}
```

Lo que **sí** habría que pedirle al backend el día que exista IAP: un campo
`access.billing_source ∈ {paddle, apple, google}`. Sin él, la app cobraría dos
veces o mostraría el diálogo equivocado a quien pagó dentro.

---

## §4 · Regresión

| Riesgo | Por qué no ocurre |
| --- | --- |
| El texto nuevo dispara la auditoría de *steering* | Los patrones prohibidos (`suscríbete`, `mejorar plan`, URLs) no aparecen; se añade una comprobación nueva que lo verifica en positivo |
| Aparecen dos textos distintos con el tiempo | Hay un solo `TextosMuro`; las pantallas no escriben cadenas |
| El diálogo tapa el mensaje real del servidor | En `sinCuota` el mensaje del backend va **primero**; la explicación después |
| Se rompe el flujo del agente | Cero cambios en `ChatController`, `SseClient`, `SseParser` ni en el contrato SSE. Solo se añade un botón al widget de aviso |
| `Blocked` deja de informar | El evento sigue tratándose igual; el muro es aditivo |

**Backend: cero cambios.** Todo sale de `/api/me`, que ya se consume.

---

## §5 · Verificación

1. `flutter analyze --fatal-infos` limpio.
2. Pruebas nuevas: un test por motivo comprobando **qué dice y qué no dice** el
   diálogo (sin URL, sin precio, sin verbo de compra).
3. Auditoría de tienda: comprobación nueva #18 — el muro existe, tiene su texto
   en un único archivo y ese texto está libre de *steering*.
4. En emulador: las cinco superficies llegan al mismo diálogo.

---

## §6 · Estado (implementado el 29-jul-2026)

`flutter analyze --fatal-infos` limpio · **107 pruebas verdes** (15 nuevas) ·
auditoría de tienda **18/18 · 0 fallas** · corriendo en `jurovia_ligero` sin
excepciones.

| Superficie | Antes | Ahora |
| --- | --- | --- |
| Perfil | Tarjeta de plan sin nada más | + fila «Gestionar suscripción» / «Tu plan» |
| Inicio | Píldora que ignoraba el toque | Tocable → muro, con chevron que lo anuncia |
| Chat · aviso `blocked` | Mensaje del servidor y nada más | + «¿Por qué?» → muro con el mensaje arriba |
| Composer | `access.blocked` **parseado y nunca usado** | Bloquea antes de escribir + «Saber más» |
| Módulos | — | `MuroPlan.exigir()` listo, sin call site (ver abajo) |

### Dos cosas que cambié respecto de la propuesta

**1. `access.blocked` estaba muerto.** El campo se parseaba en `Access` y no lo
leía nadie: el abogado escribía su consulta, la enviaba, y solo entonces se
enteraba por el evento `blocked` de que no tenía cuota. Una ida y vuelta perdida
y la peor forma de descubrirlo. Ahora el composer se deshabilita antes, con la
explicación a un toque.

**2. El guardián de *entitlements* era fail-closed y el backend es
fail-open.** `plans.has_entitlement()` trata una clave ausente como
**permitida**; mi primera versión exigía `== true`, que le habría escondido
funciones a usuarios que sí tienen acceso. Corregido: solo un `false` explícito
niega. Y como hoy **ningún plan niega nada explícitamente**, `exigir()` queda
sin *call site*: poner una puerta que el servidor no aplica quitaría acceso en
vez de explicarlo.

### Lo que la auditoría vigila desde ahora

- El texto del muro existe y **no contiene** `http`, `.com`, `juroviapp`,
  `precio`, `tarjeta`, `paddle`, `app store` ni `google play`.
- La frase de multiplataforma no se puede borrar por descuido.
- Aparecer «Restaurar compras» en cualquier `.dart` **falla el build** mientras
  `allowsInAppPurchase = false`: sería un botón que no puede restaurar nada.

### Sin verificar en dispositivo

El login pide un código de 6 dígitos al correo del titular, así que las cinco
superficies están cubiertas por pruebas de widget (incluido el orden de los
párrafos y que solo exista un botón), pero no las he visto con una sesión real.

---

### Referencias

- [`AuditCheck.md`](AuditCheck.md) §3.3 (A3.15–A3.18) · Apple 3.1.1 · 3.1.3(b)
- [`ARQUITECTURA_APP_MOVIL_V2.md`](ARQUITECTURA_APP_MOVIL_V2.md) §4.5
- Backend: `app/api/paddle.py` (único carril de cobro) · `app/api/missions.py`
  (`/api/me`) · `app/credits.py` (`access_model`)
