# Plan de implementación — Mejoras de Inicio, Casos y Notificaciones

> Análisis del backend desplegado y de la app tal como está hoy, plan de las
> mejoras propuestas, **análisis de regresión** sobre la app móvil, y evaluación
> de las notificaciones push para el Parte Diario.
>
> **Versión** 1.0 · 29 de julio de 2026 · **Estado** propuesto, **sin ejecutar**
> **Base** `ARQUITECTURA_APP_MOVIL_V2.md` · `AuditCheck.md` · `PLAN_IMPLEMENTACION.md`

---

## §1 · Estado verificado

### 1.1 Backend — todo lo necesario ya está desplegado

Comprobado contra el `openapi.json` **en producción**, no contra el código local.

| Recurso | Estado |
| --- | --- |
| `GET /api/briefing` | ✅ desplegada |
| `POST /api/sessions/{id}/promote-to-case` | ✅ desplegada |
| `GET /api/missions/attention` | ✅ desplegada |
| `code`, `display`, `autopilot_on` en `_mission_shape` | ✅ presentes |
| `case_suggestion` · `case_created` en `bridge.py` | ✅ definidos |
| Migraciones 0060 · 0061 · 0062 | ✅ aplicadas |
| Cron `parte-diario` (12:30 UTC = 7:30 COT) | ✅ registrado, **inerte** hasta `parte_diario_enabled` |

**Ninguna mejora del 1 al 8 está bloqueada por backend.** Todo es trabajo de app.

### 1.2 App — qué consume hoy

Inicio hace **cuatro llamadas** (`/api/deadlines`, `/api/tasks`,
`/api/missions/attention`, `/api/sessions`) y **compone la pantalla en el
cliente**. El `SseParser` reconoce 15 eventos; los dos nuevos caen en
`SseUnknown` y se descartan en silencio.

---

## §2 · Las mejoras

Son **9**, no 8: al leer el contrato encontré un desajuste más que rompe la
Bandeja hoy.

| # | Mejora | Impacto | Riesgo |
| --- | --- | --- | --- |
| **M1** | Inicio sobre `GET /api/briefing` (1 llamada, no 4) | 🔴 Alto | Bajo |
| **M2** | Los 5 bloques que faltan + `gate` (cold-start) | 🔴 Alto | Bajo |
| **M3** | Usar `display`, no `title` | 🔴 Alto | **Medio** |
| **M4** | Mostrar y buscar por `code` (JUR-XXXX-XXXX) | 🟡 Medio | Bajo |
| **M5** | `case_suggestion` + `case_created` + `matter_id` persistente | 🔴 Alto | **Alto** |
| **M6** | Tag «Vigilando» honesto | 🟡 Medio | Bajo |
| **M7** | `confidence` de términos en el detalle del caso | 🟡 Medio | Bajo |
| **M8** | `promote-to-case` desde el chat | 🟡 Medio | Medio |
| **M9** | **Bug: la Bandeja lee campos que no existen** | 🔴 Alto | Bajo |

### M9 — el bug que encontré analizando esto

`/api/notifications` devuelve `campaign_type` y `related_matter_id`. Mi modelo
lee `kind`/`type` y `matter_id`/`expId`. Consecuencia hoy:

- **Todos los avisos salen con el icono y el color genéricos**, porque el `switch`
  por tipo nunca acierta.
- **Tocar un aviso no navega al caso**, porque `matterId` siempre es nulo.
- El campo `radicado` que pinto **no existe** en la respuesta.

Es el mismo error de método que causó los «Caso sin nombre»: asumí nombres de
campo en vez de leerlos. Se arregla en el mismo sitio y va primero.

---

## §3 · Análisis de regresión cross-app

Grafo de imports real de `lib/` (53 archivos). La pregunta: **si toco X, ¿qué
puede romperse?**

### 3.1 Superficie de cada cambio

| Archivo a tocar | Lo importan | Mejoras | Riesgo |
| --- | --- | --- | --- |
| `shared/models/caso.dart` | **5** — data_providers, cases, case_detail, home, inbox | M3 M4 M6 M7 M9 | **Medio** |
| `core/data_providers.dart` | **7** — sync, cases, case_detail, home, inbox, profile, app_shell | M1 | **Medio** |
| `shared/models/chat.dart` | **7** | M5 (comparte `Artefacto`/`HookAccion`) | **Medio** |
| `core/network/sse_event.dart` | 4 | M5 | Bajo |
| `features/chat/chat_controller.dart` | 4 — sync, chat_screen, home, app_shell | M5 M8 | **Alto** |
| `features/chat/chat_repository.dart` | 1 | M5 M8 | Bajo |
| `features/home/home_screen.dart` | **1** — solo el router | M1 M2 | **Bajo** |
| `features/cases/*` | 1 cada uno — solo el router | M3 M4 M6 M7 | Bajo |

**La reescritura de Inicio, que parece el cambio más grande, es la de menor
riesgo:** solo el router lo importa. Nada más depende de él.

### 3.2 Lo que NO se toca — el núcleo del agente

| Componente | Usado por | Veredicto |
| --- | --- | --- |
| `core/network/sse_parser.dart` | 1 (`sse_client`) | **Intacto.** Es agnóstico al tipo de evento: parte por `\n\n` y delega en la fábrica. Añadir eventos **no lo modifica** |
| `core/network/sse_client.dart` | 2 | **Intacto.** No conoce los tipos |
| `compliance/ai_consent/ai_consent_gate.dart` | **8** | **Intacto.** El más acoplado del proyecto: tocarlo es tocar el cumplimiento |
| `compliance/store_policy.dart` | 1 | **Intacto** |
| `chat_repository.enviar()` | — | **Firma intacta.** `promote-to-case` es un método nuevo, no una modificación |

> **Ésta es la garantía central del plan: el pipeline del agente no se toca.**
> Los 15 eventos actuales siguen recorriendo el mismo camino. Los dos nuevos se
> añaden a un `switch` que ya tiene rama `_ => SseUnknown(...)`, así que el
> cambio es **aditivo por construcción**: si algo falla en el mapeo, el evento
> vuelve a caer en `SseUnknown` y el chat sigue funcionando igual que hoy.

### 3.3 Los 3 riesgos reales

**R1 · `matter_id` persistente rompe el ciclo de vida del `ChatController`** 🔴

Hoy `ChatController` es `autoDispose.family` sobre `sessionId`. Guardar el
`matter_id` que llega por `case_created` significa **estado que sobrevive al
turno**. Si se pierde al reconstruirse el provider, el usuario cree que trabaja
sobre el caso y no es así — **un fallo silencioso, que es el peor tipo**.

*Mitigación:* el `matter_id` vive en `ChatState`, que ya sobrevive mientras la
pantalla está montada; y se rehidrata desde `GET /api/sessions/{id}` al recargar
(el backend persiste el vínculo). **Nunca solo en memoria de un widget.**

**R2 · Cambiar `Caso` toca 5 archivos a la vez** 🟡

`nombre` pasa a leer `display`. Si algún consumidor asumía el valor viejo,
falla en silencio (texto vacío, no excepción).

*Mitigación:* cambio **aditivo**: se añade `codigo` y `display`, y `nombre`
resuelve `display ?? title ?? 'Caso sin nombre'`. Ningún consumidor cambia de
firma. Más una prueba por campo.

**R3 · Inicio pierde el `RefreshIndicator` y el ciclo de vida** 🟡

`refresh_policy.dart` invalida `terminosProvider`, `sesionesProvider` y
`noLeidasProvider` al volver a primer plano. Si Inicio pasa a `briefingProvider`
y no se actualiza el observador, **deja de refrescarse al enfocar** — y eso es
justo la Opción A de sincronización que decidimos.

*Mitigación:* `briefingProvider` entra en `ObservadorCicloVida` en el mismo
commit. Prueba: volver de segundo plano recarga el briefing.

### 3.4 Lo que NO cambia (verificado)

- Contrato SSE de los 15 eventos actuales
- Puerta de consentimiento de IA y `AiConsentToken`
- `StorePolicy` y sus 4 invariantes
- Rutas existentes del router (solo se **añaden** parámetros opcionales)
- Sistema de diseño (`colors`, `typography`, `shapes`) — los 3 más acoplados (31, 30 y 25 dependientes) **no se tocan**
- Auditoría de tienda: sigue en 17/17

---

## §4 · Plan de implementación

Cuatro entregas independientes. **Cada una compila, pasa pruebas y es
desplegable por sí sola.** Si hay que parar, se para entre entregas.

### Entrega 1 · Contratos (½ día) — sin UI nueva

Arregla lo que hoy está roto. Riesgo mínimo, valor inmediato.

| # | Tarea | Hecho cuando |
| --- | --- | --- |
| 1.1 | `Caso`: añadir `codigo` y `display`; `nombre` = `display ?? title ?? …` | Los casos muestran nombres legibles, no el prompt |
| 1.2 | **M9** `Notificacion`: `campaign_type` y `related_matter_id` | La Bandeja pinta iconos por tipo y navega al caso |
| 1.3 | `Termino`: exponer `auto_created` junto a `confidence` | — |
| 1.4 | Pruebas de contrato: un test por modelo con **JSON real capturado del backend** | 3 pruebas nuevas en verde |

> **1.4 es la lección de esta semana.** Los tres bugs de campos existían porque
> no había ninguna prueba que comparase mis modelos con la respuesta real.

### Entrega 2 · Casos (1 día)

| # | Tarea | Hecho cuando |
| --- | --- | --- |
| 2.1 | **M4** `code` en tarjeta y detalle, en monoespaciada seleccionable | Se ve `JUR-XXXX-XXXX` |
| 2.2 | **M4** Buscar por código → `GET /api/missions?q=JUR-…` | Buscar el código encuentra el caso |
| 2.3 | **M6** Tag «Vigilando» solo con `autopilot_on` **Y** radicado real | Sin radicado no aparece el tag |
| 2.4 | **M7** Chip «tentativo · confirma la fecha» en términos del detalle | Los auto-creados se distinguen |
| 2.5 | Mover el buscador al servidor (hoy filtra en el cliente) | Busca también dentro de documentos |

> 2.5 no estaba en la lista y es importante: el buscador del backend busca
> **dentro del contenido de los documentos**. El mío filtra la lista ya
> descargada, así que encuentra mucho menos.

### Entrega 3 · Inicio sobre el briefing (1½ días)

| # | Tarea | Hecho cuando |
| --- | --- | --- |
| 3.1 | Modelo `Briefing` completo con sus 6 bloques + `gate` | Deserializa la respuesta real |
| 3.2 | `briefingProvider` + entrada en `ObservadorCicloVida` (**R3**) | Volver de segundo plano recarga |
| 3.3 | 🌐 Novedades — 3 tarjetas de igual altura, CTA «Resolver →» abajo | Clic siembra el chat con `ask_query` |
| 3.4 | 🛡️ Tu escudo — con versión aspiracional si `vigilados == 0` | Nunca se oculta |
| 3.5 | 🔴 Esto es lo importante — Urgente/Preparado/Faltante con acciones | Los botones ejecutan |
| 3.6 | ✅ Pendientes · 🌙 Mientras no estabas · 📁 Procesos por prioridad | Orden por `score` del backend |
| 3.7 | `gate` decide el estado vacío | Cuenta nueva **nunca** ve pantalla vacía |
| 3.8 | **Retirar** las 4 llamadas viejas de Inicio | Una sola petición |

### Entrega 4 · Casos desde el chat (1 día) — la de más riesgo

| # | Tarea | Hecho cuando |
| --- | --- | --- |
| 4.1 | **M5** Añadir los 2 eventos a `SseEvent.desde()` | El `switch` los reconoce |
| 4.2 | **M5** Chip «📁 ¿Guardar como caso?» con «Crear caso» / «Ahora no» | Aparece con `case_suggestion` |
| 4.3 | **M8** `promote-to-case` desde el chip | Devuelve `matter_id` y `code` |
| 4.4 | **M5** Banner «Caso creado» con el código | Aparece con `case_created` |
| 4.5 | **M5 · R1** `matterId` en `ChatState`, enviado en los turnos siguientes | Prueba: turno 2 lleva el `matter_id` |
| 4.6 | **R1** Rehidratar el vínculo desde `GET /api/sessions/{id}` | Reabrir la sesión conserva el caso |

**Total: 4 días.** Con el 25–30 % de holgura de siempre: **~5 días**.

### Orden y por qué

1 → 2 → 3 → 4. La 1 arregla bugs vivos. La 4 va **al final** porque es la única
que toca el flujo del agente: cuando llegue, todo lo demás ya está estable y un
fallo se aísla sin ambigüedad.

---

## §5 · Notificaciones push del Parte Diario

Lo analicé aparte porque **no es trabajo de app: es sobre todo backend**, y hay
una alternativa que da el 70 % del valor sin construir nada de push.

### 5.1 Qué existe hoy

| Pieza | Estado |
| --- | --- |
| Tabla `notifications` con columna `channel` (`inapp\|email\|…`) | ✅ existe (migración 0013) |
| `GET /api/notifications` devuelve `channel` | ✅ |
| Cron del Parte Diario | ✅ registrado, inerte |
| `POST /api/jobs/parte_diario` | ✅ existe |
| **Tabla de tokens de dispositivo** | ❌ **no existe** |
| **Endpoint para registrar un token** | ❌ **no existe** |
| **Integración con FCM/APNs** | ❌ **no existe nada** en todo el backend |
| **El job escribe una notificación in-app** | ❌ **no**: solo envía correo |

> Verificado: no hay una sola referencia a `fcm`, `firebase`, `apns`,
> `push_token` ni `device_token` en el backend.

### 5.2 Opción A — «Parte del día» in-app (recomendada primero)

**Cambio: 5 líneas de backend. Cero infraestructura.**

Que `parte_diario_job`, **además del correo**, escriba una fila en
`notifications` con `channel='inapp'` y `campaign_type='parte_diario'`.

Con eso, gratis y hoy:

- La Bandeja de la app muestra **«Tu parte del día»** cada mañana.
- El **badge** del icono se enciende — reusa `unread-count`, ya implementado.
- Tocarlo lleva al Inicio, que **ya es el briefing** tras la Entrega 3.
- Funciona igual en web y móvil, sin permisos ni cuentas de tienda.

Lo que **no** da: aviso con la app cerrada. Para eso hace falta la Opción B.

### 5.3 Opción B — push real

Cuatro piezas, y **tres son de backend**:

**Backend**
1. Migración: tabla `device_tokens` (`org_id`, `user_id`, `token`, `platform`, `updated_at`), con RLS.
2. `POST /api/devices/register` y `DELETE /api/devices/{token}`.
3. Cliente FCM (HTTP v1, cuenta de servicio de Firebase) + envío desde `parte_diario_job` y desde los avisos de actuación.

**App**
4. `firebase_messaging`, permiso de notificaciones **en contexto**, registro del token tras el login, y manejo del *deep link* del payload.

### 5.4 Qué cuesta en la app — y qué toca del cumplimiento

Esto es lo que quiero que veas antes de decidir, porque **push no es gratis en
la ficha de tienda**:

| Efecto | Detalle |
| --- | --- |
| **Privacy manifest** | Hay que declarar el token de dispositivo. `NSPrivacyTracking` sigue en `false` (un token de push **no es** rastreo publicitario), así que **ATT sigue sin aplicar** |
| **App Privacy / Data Safety** | Nueva categoría: *Identificadores → ID de dispositivo* |
| **Auditoría de tienda** | Mi script marca `firebase_analytics` como SDK publicitario. `firebase_messaging` **no** lo dispara, pero conviene añadir una regla que impida que entre `firebase_analytics` de rebote como dependencia transitiva |
| **iOS** | Requiere **llave APNs** de la cuenta de Apple Developer → **bloqueado hasta que la cuenta esté verificada** |
| **Android** | Requiere `google-services.json` de un proyecto Firebase |
| **Permiso** | Android 13+ exige permiso explícito de notificaciones. Pedirlo **tras la primera alerta útil**, no al arrancar |

### 5.5 Abrir el Inicio desde el push

El payload debe traer una ruta, y el deep link `jurovia://` ya está registrado
en ambas plataformas. Con `go_router` ya montado:

```
payload: { "ruta": "/", "tipo": "parte_diario", "fecha": "2026-07-29" }
        → app en frío o en segundo plano → router.go('/')
```

**No hace falta nada nuevo de navegación.** Es la ventaja de haber puesto
`go_router` con deep links desde la Fase 1.

⚠️ Pendiente de la Fase 1 que aquí también hace falta: añadir **`jurovia://**` a
la `uri_allow_list` de Supabase**. Sin eso, ni el OTP ni los deep links del push
devuelven a la app.

### 5.6 Recomendación

**Opción A ahora** — 5 líneas de backend, valor inmediato, cero riesgo de
tienda.

**Opción B cuando estén las cuentas.** No antes: la llave APNs depende de la
cuenta de Apple verificada, así que empezarla hoy sería trabajo parado a mitad.
Y estimarla honestamente: **~2 días de backend + ~1½ de app**, más lo que sume
en las declaraciones de privacidad.

---

## §6 · Verificación

Se ejecuta **al cerrar cada entrega**, no solo al final:

```
flutter analyze --fatal-infos     # sin problemas
flutter test --exclude-tags integracion
python tool/auditoria_tienda.py   # debe seguir en 17/17
flutter build apk --debug         # compila
```

Más, específico de estas mejoras:

| Comprobación | Entrega |
| --- | --- |
| Un turno de chat completo sigue funcionando (los 15 eventos) | 4 |
| La puerta de consentimiento sigue bloqueando el agente | 4 |
| Reabrir una sesión conserva el vínculo con el caso | 4 |
| Volver de segundo plano recarga el briefing | 3 |
| Cuenta nueva (sin casos) no ve pantalla vacía | 3 |
| Buscar por `JUR-…` encuentra el caso | 2 |
| Un caso sin radicado **no** muestra «Vigilando» | 2 |
| Los modelos deserializan JSON real capturado del backend | 1 |

---

## §7 · Riesgos del plan

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| **El vínculo chat↔caso se pierde en silencio** | Alto | Vive en `ChatState` **y** se rehidrata del backend. Prueba explícita |
| Cambiar `Caso` rompe 5 pantallas | Medio | Cambio aditivo; `nombre` mantiene su firma |
| Inicio deja de refrescarse al enfocar | Medio | `briefingProvider` entra en `ObservadorCicloVida` en el mismo commit |
| El contrato del briefing cambia bajo nuestros pies | Medio | Pruebas con JSON capturado; el parser ignora campos desconocidos |
| Push arrastra `firebase_analytics` como transitiva | Bajo | Regla nueva en la auditoría de tienda |
| Añadir push obliga a rehacer declaraciones de privacidad | Bajo | Hacerlo **antes** de enviar a revisión, no después |

---

## §8 · La lección de método

Tres de las nueve mejoras (**M3, M7, M9**) son bugs míos por el mismo motivo:
**asumí los nombres de los campos en vez de leerlos del backend**. El backend
remapea sus columnas antes de responder —`name` → `title` → `display`,
`deadline_at` → `daysLeft`, `campaign_type`— y yo di por hecho que exponía el
esquema.

Por eso la tarea **1.4** no es opcional: pruebas de contrato con JSON real
capturado. Es lo único que convierte este tipo de fallo en algo que se detecta
en el *pull request* y no cuando tú abres la app.

---

## §9 · Estado de cierre (29-jul-2026)

**Entregas 1 a 4: implementadas.** `flutter analyze --fatal-infos` limpio ·
**92 pruebas verdes** · auditoría de tienda **17/17** · APK instalado y
corriendo en `jurovia_ligero` sin excepciones en tiempo de ejecución.

| Entrega | Qué quedó | Dónde |
| --- | --- | --- |
| **E1 · Contratos** | `Caso.codigo` + `display` primero · `vigilanciaVerificable` · `Termino.autoCreado` · `Notificacion` sobre `campaign_type`/`related_matter_id`/`read_at` | `shared/models/caso.dart`, `features/inbox/` |
| **E1.4 · La lección** | 36 pruebas de contrato con JSON copiado del backend, una por endpoint | `test/contratos/` |
| **E2 · Casos** | Código `JUR-` en tarjeta, cabecera y ficha (monoespaciada, seleccionable) · buscador **al servidor** (`?q=`, busca también dentro de los documentos) · tag de vigilancia con tres estados · chip de término tentativo | `features/cases/`, `shared/widgets/fila_termino.dart` |
| **E3 · Briefing** | Modelo completo + `briefingProvider` (fail-open) · seis bloques · `gate` decide el arranque en frío · **una** llamada en vez de cuatro | `shared/models/briefing.dart`, `features/home/briefing_blocks.dart` |
| **E4 · Chat↔caso** | `case_suggestion` y `case_created` tipados · chip «¿Lo guardo como caso?» con «Ahora no» · `promote-to-case` idempotente · banner con el código · `matterId` en todos los turnos siguientes | `core/network/sse_event.dart`, `features/chat/` |

### Lo que quedó fuera y por qué

- **Rehidratar el vínculo chat↔caso desde el servidor (parte del riesgo R1).**
  `GET /api/sessions/{id}` solo selecciona `id,title` de `chat_sessions`: **no
  devuelve `matter_id`**. Mientras tanto el vínculo se guarda en el dispositivo
  (`SharedPreferences`), así que reabrir la conversación en el **mismo** móvil
  conserva el caso, pero en otro dispositivo el banner no aparece hasta que se
  vuelva a mencionar. `ChatController._casoDe()` ya lee el campo: basta con que
  el backend lo añada al `select` para que funcione sin tocar la app.
- **El chip de sugerencia no sobrevive a recargar el chat.** El backend sí
  persiste la sugerencia (`message_parts` tipo `case_suggestion`), pero
  `get_session` no la reconstruye al aplanar los mensajes. Es una propuesta
  efímera del turno, no un dato perdido.
- **Push del Parte Diario (§5).** Sin cambios: sigue necesitando proyecto FCM y
  la columna de dispositivos en el backend, y arrastra declaraciones de
  privacidad que conviene resolver *antes* de enviar a revisión.

---

### Referencias

- Arquitectura: [`ARQUITECTURA_APP_MOVIL_V2.md`](ARQUITECTURA_APP_MOVIL_V2.md)
- Requisitos de tienda: [`AuditCheck.md`](AuditCheck.md)
- Plan base: [`PLAN_IMPLEMENTACION.md`](PLAN_IMPLEMENTACION.md)
- Contratos del backend: `app/api/missions.py` (`_mission_shape`) ·
  `app/agent/briefing.py` (`build_briefing`) · `app/bridge.py` (eventos) ·
  `app/api/notifications.py` · `app/api/jobs.py` (`parte_diario_job`)
