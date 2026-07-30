# AuditCheck — Requisitos obligatorios de App Store y Google Play

> Auditoría de cumplimiento para publicar **Jurovia** en iOS y Android sin rechazos
> ni retrasos. Cada ítem es verificable y trazable a la política oficial.
>
> **Versión** 1.0 · 28 de julio de 2026
> **Alcance** Jurovia app móvil (Flutter) · mercado Colombia · modelo Web2App
>
> ⚠️ **Las políticas de tienda cambian sin aviso.** Este documento refleja el estado
> a julio de 2026. **Reverificar contra la fuente oficial 2 semanas antes de enviar.**
> Los enlaces oficiales están en §9.

---

## Índice

- [§0 · Resumen ejecutivo: los 9 bloqueantes de Jurovia](#0)
- [§1 · Apple — Prerrequisitos de cuenta](#1)
- [§2 · Apple — Gates técnicos de compilación](#2)
- [§3 · Apple — App Review Guidelines aplicables](#3)
- [§4 · Apple — Privacidad](#4)
- [§5 · Apple — Metadata y App Store Connect](#5)
- [§6 · Google — Cuenta, verificación y pruebas](#6)
- [§7 · Google — Gates técnicos y declaraciones](#7)
- [§8 · Ambas — Requisitos derivados de ser una app de IA jurídica](#8)
- [§9 · Fuentes oficiales](#9)
- [§10 · Matriz de verificación final](#10)

---

<a id="0"></a>
## §0 · Resumen ejecutivo: los 9 bloqueantes de Jurovia

Ordenados por riesgo de rechazo o retraso. **Ninguno es opcional.**

| # | Bloqueante | Tienda | Estado hoy |
| --- | --- | --- | --- |
| 1 | **Consentimiento explícito para enviar datos a IA de terceros** (Anthropic, por nombre) — regla 5.1.2(i) | Apple | ❌ no existe |
| 2 | **Reporte de contenido dentro de la app** — política de contenido generado por IA | Google | ❌ no existe |
| 3 | **Eliminación de cuenta**: botón en la app **y** URL pública | Ambas | ⚠️ backend listo, falta UI + URL |
| 4 | **Cuenta de prueba para el revisor** con plan activo — regla 2.1 | Ambas | ❌ no existe |
| 5 | **Sin comercio dentro de la app** (regla 3.1.1) — el prototipo tiene CTA de compra | Apple | ❌ el diseño lo incumple |
| 6 | **Mac con macOS 15.6+ y Xcode 26** — obligatorio desde 28-abr-2026 | Apple | ❌ no hay Mac |
| 7 | **Privacy manifest** `PrivacyInfo.xcprivacy` + Required Reason APIs | Apple | ❌ no existe |
| 8 | **Verificación de identidad / D-U-N-S** si la cuenta es de organización | Ambas | ❌ sin cuentas |
| 9 | **Prueba cerrada 12 testers × 14 días** si la cuenta de Google es personal | Google | ❌ sin cuenta |

> **El #6 y el #8 son los que marcan el calendario.** El D-U-N-S tarda hasta 28 días
> y sin Mac no hay build de iOS. Todo lo demás se puede hacer en paralelo.

---

<a id="1"></a>
## §1 · Apple — Prerrequisitos de cuenta

| ID | Requisito | Detalle | ✓ |
| --- | --- | --- | --- |
| A1.1 | Apple Developer Program | **99 USD/año**, renovación anual | ☐ |
| A1.2 | Doble factor activo | Obligatorio en el Apple Account | ☐ |
| A1.3 | Tipo de entidad **decidido** | Individuo (inmediato, app a nombre personal) vs Organización (requiere **D-U-N-S**, días–semanas) | ☐ |
| A1.4 | D-U-N-S | Solo si es organización. Gratis. **Pedirlo primero de todo.** | ☐ |
| A1.5 | Entidad legal verificada | Nombre legal exacto, dirección, sitio web y teléfono verificables | ☐ |
| A1.6 | Registro de app creado | App Store Connect → My Apps → **+**, bundle `com.jurovia.app` | ☐ |
| A1.7 | **Paid Apps Agreement** aceptado | Business → Agreements. Aunque la app no venda, se requiere si algún día habrá IAP | ☐ |
| A1.8 | Datos bancarios y fiscales | Solo si se activa IAP. **No aplica** en Web2App | n/a |
| A1.9 | App Store Connect API Key | Rol *App Manager*. `.p8` **descargable una sola vez** | ☐ |
| A1.10 | Certificado de distribución + perfil App Store | Para `com.jurovia.app` | ☐ |

---

<a id="2"></a>
## §2 · Apple — Gates técnicos de compilación

Estos **bloquean la subida del binario**. No son opinión del revisor: el sistema rechaza.

| ID | Requisito | Detalle | ✓ |
| --- | --- | --- | --- |
| A2.1 | **Xcode 26 + SDK de iOS 26** | Obligatorio para nuevas subidas y actualizaciones **desde el 28 de abril de 2026**. Ya está vigente. | ☐ |
| A2.2 | **macOS Sequoia 15.6 o superior** | Requisito de Xcode 26. Implica un Mac. | ☐ |
| A2.3 | Flutter compatible con el SDK de iOS 26 | Verificar que Flutter 3.44.8 compile contra iOS 26 SDK antes de comprometer fechas | ☐ |
| A2.4 | **`PrivacyInfo.xcprivacy`** en el bundle | Obligatorio desde el 1-may-2024. Sin él, **App Store Connect rechaza la subida** | ☐ |
| A2.5 | **Required Reason APIs declaradas** | Ver §4.3 | ☐ |
| A2.6 | Privacy manifests de los SDK de terceros | Cada paquete Flutter con código nativo debe traer el suyo. Auditar `pubspec.lock` | ☐ |
| A2.7 | Firma de SDK de terceros | Los SDK de la lista de Apple deben venir firmados | ☐ |
| A2.8 | `ITSAppUsesNonExemptEncryption` | Ya configurado en `false`. Evita el cuestionario en cada envío | ✅ |
| A2.9 | Bitcode | Obsoleto, no aplica | n/a |
| A2.10 | Arquitecturas | arm64. Sin binarios de simulador en el IPA | ☐ |
| A2.11 | Tamaño del IPA | Sin límite duro relevante; vigilar descarga celular (>200 MB avisa) | ☐ |
| A2.12 | Build number creciente | Cada envío debe superar el anterior. **Ya resuelto** con `--build-number=${{ github.run_number }}` | ✅ |
| A2.13 | Sin APIs privadas | Uso de API no públicas = rechazo automático | ☐ |
| A2.14 | Sin código ejecutable descargado | Regla 2.5.2: nada de cargar binarios o intérpretes en runtime | ☐ |

---

<a id="3"></a>
## §3 · Apple — App Review Guidelines aplicables

### 3.1 · Sección 1 — Safety

| ID | Guía | Requisito | Aplica a Jurovia | ✓ |
| --- | --- | --- | --- | --- |
| A3.1 | **1.2** Contenido generado por usuario | Si hay UGC: filtro de contenido, **mecanismo de reporte**, bloqueo de usuarios, contacto publicado | ⚠️ El chat con IA no es UGC clásico, pero el **reporte** se exige por la vía de IA. Implementarlo. | ☐ |
| A3.2 | **1.4** Daño físico | Apps de salud/medicina tienen carga extra | No aplica | n/a |
| A3.3 | **1.4.1** Consejo profesional | Apps que dan asesoría deben ser precisas y responsables | ✅ Sí — la app da orientación jurídica. **Disclaimer visible obligatorio** | ☐ |
| A3.4 | **1.5** Información de contacto | Datos de soporte accesibles y funcionales | ☐ |

### 3.2 · Sección 2 — Performance

| ID | Guía | Requisito | ✓ |
| --- | --- | --- | --- |
| A3.5 | **2.1** App Completeness | Versión final, sin *placeholders*, **URLs funcionales**, probada en dispositivo real. **Incluir credenciales de demo con el backend encendido.** | ☐ |
| A3.6 | 2.1 (bis) | Si no se puede dar cuenta de demo: modo demo integrado **con aprobación previa de Apple** | n/a |
| A3.7 | **2.2** Beta | Nada de software de prueba en producción. Sin "próximamente" | ☐ |
| A3.8 | **2.3.1** Sin funciones ocultas | **Describir con especificidad en las Notas para Revisión. Las descripciones genéricas se rechazan.** | ☐ |
| A3.9 | **2.3.3** Capturas | Deben mostrar la **app en uso**, no el splash ni el login | ☐ |
| A3.10 | **2.3.7** Nombre y keywords | Nombre **máx. 30 caracteres**, sin marcas ajenas ni relleno | ☐ |
| A3.11 | **2.5.1** APIs públicas | Solo API documentadas | ☐ |
| A3.12 | **2.5.2** Sin código descargado | Nada de ejecutar código remoto | ☐ |
| A3.13 | **2.5.4** Multitarea / segundo plano | Solo los modos que realmente se usan | ☐ |
| A3.14 | **2.5.13** Precisión de compras | No aplica sin IAP | n/a |

### 3.3 · Sección 3 — Business (lo más crítico para Jurovia)

| ID | Guía | Requisito | ✓ |
| --- | --- | --- | --- |
| A3.15 | **3.1.1** In-App Purchase | Desbloquear funciones digitales **exige IAP**. Jurovia **no vende dentro de la app** | ☐ |
| A3.16 | **3.1.1(a)** Enlaces externos | Permitido **solo en la tienda de EE. UU.** Colombia: prohibido | ☐ |
| A3.17 | **3.1.3(b)** Multiplataforma | Cobertura de Jurovia: acceso a lo comprado en la web. **Preparar el argumento por escrito** | ☐ |
| A3.18 | **3.1.3** Prohibición de *steering* | **Ni un texto** que dirija a pagar fuera: nada de "suscríbete en la web", "facturación en juroviapp.com" ni enlaces | ☐ |
| A3.19 | 3.2.2 | Sin prácticas comerciales inaceptables | ☐ |

> **Riesgo documentado (no teórico):** hay casos reales de apps B2B SaaS **solo de login,
> sin pantallas de precio ni enlaces**, rechazadas igualmente con
> *"Your app accesses digital content purchased outside the app, and that content is
> not available through in-app purchase."*
> **Mitigación obligatoria:** capa gratuita con utilidad real (registro + prueba en la
> app), y respuesta preparada para el Resolution Center citando 3.1.3(b), el público
> objetivo (profesionales del derecho), y que el servicio existe en web desde antes.

### 3.4 · Sección 4 — Design

| ID | Guía | Requisito | ✓ |
| --- | --- | --- | --- |
| A3.20 | **4.0** Calidad de diseño | HIG. La app debe verse nativa, no un contenedor web | ☐ |
| A3.21 | **4.1** Copias | Sin imitar apps existentes | ☐ |
| A3.22 | **4.2** Funcionalidad mínima | **"Más que un sitio web reempaquetado."** Debe tener utilidad duradera. Riesgo real si la app es un chat y poco más → **incluir funciones nativas: cámara, notificaciones, archivos, audiencias** | ☐ |
| A3.23 | **4.2.3(i)** | Debe funcionar sola, sin requerir otra app | ☐ |
| A3.24 | **4.3(b)** Apps de baja calidad | **Endurecido en junio de 2026.** Debe ofrecer "experiencia significativamente diferente o mejorada" | ☐ |
| A3.25 | **4.5.3** Live Activities | No usar para spam. Solo si se implementan | n/a |
| A3.26 | **4.8** Login Services | Si se usa Google Sign-In → **obligatorio ofrecer Sign in with Apple** (u otro que limite datos a nombre+correo y permita ocultar el correo). **Excepción:** si solo se usa el sistema propio (OTP por correo de Supabase), **no aplica** | ☐ |

> **Decisión recomendada:** dejar **solo OTP por correo** en v1. Elimina el requisito
> 4.8 por completo. El prototipo dibuja "Continuar con Google" — **quitarlo**, o
> asumir también Sign in with Apple.

### 3.5 · Sección 5 — Legal

| ID | Guía | Requisito | ✓ |
| --- | --- | --- | --- |
| A3.27 | **5.1.1(i)** Política de privacidad | Enlace en App Store Connect **y dentro de la app**. Debe decir qué datos, cómo, para qué, con quién se comparten, retención y **cómo revocar y pedir borrado** | ⚠️ existe en web, falta enlazarla en la app |
| A3.28 | **5.1.1(ii)** Consentimiento y *purpose strings* | Consentimiento para recolección; **las cadenas de permiso deben describir el uso con claridad**; forma accesible de retirar el consentimiento | ☐ |
| A3.29 | **5.1.1(v)** **Eliminación de cuenta** | Si hay registro, **debe poder borrarse la cuenta desde dentro de la app**. No basta con desactivar | ☐ |
| A3.30 | **5.1.2(i)** **Datos a terceros / IA** | **"Debes revelar claramente dónde se compartirán los datos personales con terceros, incluida IA de terceros, y obtener permiso explícito antes de hacerlo."** | 🔴 **Bloqueante #1** |
| A3.31 | 5.1.2(ii) | No reutilizar datos para otro fin sin consentimiento nuevo | ☐ |
| A3.32 | 5.1.2(iii) | Sin perfilado encubierto | ☐ |
| A3.33 | **5.1.5** Servicios de ubicación | Solo si se usan. Jurovia no los necesita → **no pedir el permiso** | n/a |
| A3.34 | 5.2 | Propiedad intelectual: no reproducir textos legales de terceros sin derecho | ☐ |
| A3.35 | 5.3 | Juego/apuestas: no aplica | n/a |

---

<a id="4"></a>
## §4 · Apple — Privacidad

### 4.1 · App Privacy (etiquetas de la ficha)

Cuestionario obligatorio en App Store Connect. **Debe coincidir con lo que el binario
hace de verdad**; Apple audita y una discrepancia es rechazo o retirada.

Para Jurovia hay que declarar como mínimo:

| Categoría | Recolectado | Vinculado a identidad | Usado para rastreo | Propósito |
| --- | --- | --- | --- | --- |
| Correo electrónico | Sí | Sí | No | Funcionalidad de la app |
| Nombre | Sí | Sí | No | Funcionalidad de la app |
| Identificador de usuario | Sí | Sí | No | Funcionalidad de la app |
| **Contenido del usuario** (mensajes, documentos, casos) | Sí | Sí | No | Funcionalidad de la app |
| Datos de uso / diagnóstico | Sí | Depende | No | Analítica y rendimiento |

> **"Contenido del usuario" es la categoría delicada.** Los abogados suben expedientes
> con datos de terceros. Debe declararse y explicarse en la política de privacidad.

### 4.2 · Privacy Manifest (`PrivacyInfo.xcprivacy`)

| ID | Requisito | ✓ |
| --- | --- | --- |
| A4.1 | Archivo presente en el bundle de la app | ☐ |
| A4.2 | `NSPrivacyTracking` = `false` (si no se rastrea) | ☐ |
| A4.3 | `NSPrivacyTrackingDomains` vacío si no hay rastreo | ☐ |
| A4.4 | `NSPrivacyCollectedDataTypes` coherente con las etiquetas de §4.1 | ☐ |
| A4.5 | `NSPrivacyAccessedAPITypes` con todas las Required Reason APIs | ☐ |
| A4.6 | Cada paquete Flutter con código nativo trae su propio manifest | ☐ |

### 4.3 · Required Reason APIs — las que probablemente use Jurovia

| API | Motivo típico | Código |
| --- | --- | --- |
| `UserDefaults` | Acceso a datos propios de la app | `CA92.1` |
| Timestamps de archivo | Mostrar fechas de documentos al usuario | `C617.1` / `DDA9.1` |
| Espacio en disco | Comprobar antes de descargar/subir | `E174.1` / `85F4.1` |
| *System boot time* | Medir tiempos dentro de la app | `35F9.1` |
| `ActiveKeyboards` | Solo si aplica | — |

> Auditar con `grep` sobre el proyecto y **todas** las dependencias. Un motivo faltante
> = rechazo automático de la subida, no del revisor.

### 4.4 · App Tracking Transparency (ATT)

| ID | Requisito | ✓ |
| --- | --- | --- |
| A4.7 | **Si NO se integra SDK de publicidad ni se rastrea entre apps → ATT no aplica** | ☐ |
| A4.8 | Si se integra Meta SDK / atribución publicitaria → **ATT obligatorio** antes de recolectar el IDFA, con `NSUserTrackingUsageDescription` | ☐ |

> **Recomendación fuerte:** en v1 **no integrar ningún SDK publicitario**. Elimina ATT,
> `NSPrivacyTracking`, dominios de rastreo y una categoría entera de rechazos.
> La atribución del embudo ya se hace server-side en la web.

### 4.5 · Purpose strings a preparar (`Info.plist`)

Solo declarar los permisos que **realmente** se usan. Un permiso declarado y no usado
también genera rechazo.

| Clave | Cuándo | Texto sugerido |
| --- | --- | --- |
| `NSCameraUsageDescription` | Escanear documentos | "Jurovia usa la cámara para que puedas escanear documentos y anexarlos a tus casos." |
| `NSPhotoLibraryUsageDescription` | Adjuntar imágenes | "Jurovia accede a tus fotos para adjuntar imágenes de documentos a un caso." |
| `NSMicrophoneUsageDescription` | Dictado por voz | "Jurovia usa el micrófono para transcribir lo que dictas y convertirlo en texto." |
| `NSFaceIDUsageDescription` | Bloqueo biométrico | "Jurovia usa Face ID para proteger el acceso a la información de tus casos." |

---

<a id="5"></a>
## §5 · Apple — Metadata y App Store Connect

| ID | Requisito | Especificación | ✓ |
| --- | --- | --- | --- |
| A5.1 | Nombre de la app | **≤ 30 caracteres**. "Jurovia" | ☐ |
| A5.2 | Subtítulo | ≤ 30 caracteres | ☐ |
| A5.3 | Descripción | ≤ 4.000 caracteres | ☐ |
| A5.4 | Keywords | ≤ 100 caracteres, separadas por coma, sin espacios | ☐ |
| A5.5 | Texto promocional | ≤ 170 caracteres, editable sin nueva versión | ☐ |
| A5.6 | **Icono 1024×1024** | PNG, **sin transparencia, sin esquinas redondeadas propias, sin canal alfa** | ☐ |
| A5.7 | **Capturas iPhone 6.9"** | Obligatorias. Mínimo 3, hasta 10. La app **en uso** | ☐ |
| A5.8 | Capturas iPad | Solo si se declara compatible con iPad | ☐ |
| A5.9 | URL de soporte | Obligatoria y **funcional** | ☐ |
| A5.10 | URL de política de privacidad | Obligatoria → `juroviapp.com/privacidad` | ✅ |
| A5.11 | URL de marketing | Opcional | ☐ |
| A5.12 | **Clasificación por edad** | Cuestionario completo. Respuestas parciales bloquean el envío | ☐ |
| A5.13 | Categoría | Sugerido: *Business* (principal), *Productivity* (secundaria) | ☐ |
| A5.14 | Copyright | "© 2026 <razón social>" | ☐ |
| A5.15 | **Notas para Revisión** | **Con especificidad.** Ver plantilla abajo | ☐ |
| A5.16 | **Cuenta de demo** | Usuario + contraseña/OTP accesible, **con plan activo y créditos** | ☐ |
| A5.17 | Export compliance | Resuelto por `ITSAppUsesNonExemptEncryption=false` | ✅ |
| A5.18 | Contenido de terceros | Declarar derechos sobre normas/jurisprudencia citadas | ☐ |

### 5.1 · Plantilla de Notas para Revisión

> Apple rechaza notas genéricas. Esta plantilla se anticipa a los tres rechazos más
> probables (3.1.1, 4.2 y 2.1).

```
CUENTA DE PRUEBA
Correo: revisor@juroviapp.com
Código OTP: se envía al correo. Alternativamente, código fijo de prueba: 000000
Esta cuenta tiene plan Pro activo con créditos suficientes.

QUÉ ES LA APP
Jurovia es un asistente de investigación y redacción jurídica para abogados
colombianos. La app permite consultar normativa y jurisprudencia con verificación
contra fuentes oficiales, redactar documentos, gestionar casos y transcribir
audiencias.

SOBRE COMPRAS DENTRO DE LA APP (Guideline 3.1.1 / 3.1.3(b))
Esta app NO ofrece ninguna compra. No contiene botones de suscripción, precios,
enlaces de pago ni referencias a comprar fuera de la app.
Jurovia es un servicio multiplataforma que existe en web (juroviapp.com) desde
2026 y es utilizado por despachos jurídicos. Los usuarios acceden con su cuenta
existente, conforme a la Guideline 3.1.3(b) Multiplatform Services.
La app ofrece registro gratuito y una prueba sin costo con funcionalidad real.

SOBRE INTELIGENCIA ARTIFICIAL
La app usa modelos de Anthropic (Claude) para generar respuestas. Al primer uso se
muestra una pantalla de consentimiento explícito que identifica al proveedor por
nombre y explica qué datos se le envían. Sin ese consentimiento la función no opera.
Todo contenido generado por IA está etiquetado como tal y puede reportarse desde el
propio mensaje.

CÓMO PROBAR
1. Iniciar sesión con la cuenta de prueba.
2. Aceptar el consentimiento de IA.
3. Escribir: "¿Cuándo prescribe la acción de responsabilidad civil extracontractual?"
4. Observar la respuesta con fuentes verificadas.
5. Perfil → Eliminar cuenta muestra el borrado (no ejecutar en la cuenta de prueba).
```

---

<a id="6"></a>
## §6 · Google — Cuenta, verificación y pruebas

| ID | Requisito | Detalle | ✓ |
| --- | --- | --- | --- |
| G6.1 | Cuenta de Play Console | **25 USD pago único**. Tarjeta real, **no prepago** | ☐ |
| G6.2 | Tipo de cuenta decidido | **Personal** → ID gubernamental + **prueba cerrada obligatoria**. **Organización** → **D-U-N-S** + documentos + sitio verificado, **exenta de la prueba cerrada** | ☐ |
| G6.3 | Verificación de identidad | Bloquea toda publicación hasta completarse | ☐ |
| G6.4 | D-U-N-S | Solo organización. Hasta **28 días** | ☐ |
| G6.5 | **Prueba cerrada** | Si la cuenta es personal (creada después de nov-2023): **≥12 testers optados durante ≥14 días continuos**, en dispositivos reales | ☐ |
| G6.6 | Cuestionario de acceso a producción | 3 secciones. Revisión ~7 días | ☐ |
| G6.7 | Revisión final de la app | Hasta 7 días, a veces más | ☐ |

> **Recomendación:** si es viable, **cuenta de organización**. Se salta los 14 días de
> prueba cerrada, a cambio del D-U-N-S. Como el D-U-N-S ya hace falta para Apple
> empresa, se pide una sola vez para las dos tiendas.

> **Calendario realista para cuenta personal: 3 a 5 semanas** desde cero.

---

<a id="7"></a>
## §7 · Google — Gates técnicos y declaraciones

### 7.1 · Técnicos

| ID | Requisito | Detalle | ✓ |
| --- | --- | --- | --- |
| G7.1 | **Android App Bundle (.aab)** | Obligatorio para apps nuevas. APK no se acepta | ✅ configurado |
| G7.2 | **Play App Signing** | Obligatorio. Google custodia la llave de firma; la tuya pasa a ser de **subida** | ☐ |
| G7.3 | **Target API 36 (Android 16)** | Obligatorio para apps nuevas y actualizaciones desde el **31-ago-2026** (prórroga hasta 1-nov-2026). **VERIFICADO:** Flutter 3.44.8 usa `targetSdkVersion = 36` por defecto (`FlutterExtension.kt`) | ✅ |
| G7.4 | **Soporte de páginas de 16 KB** | Obligatorio desde el 1-nov-2025 para apps que apuntan a Android 15+. **VERIFICADO sobre el AAB compilado**: las 6 librerías nativas (`libapp.so`, `libflutter.so` × 3 ABIs) están alineadas a 16 KB o 64 KB. **Revalidar al añadir plugins con código nativo** | ✅ |
| G7.5 | versionCode creciente | **Ya resuelto** en CI | ✅ |
| G7.6 | Permiso `INTERNET` en manifiesto de release | **Corregido** (la plantilla solo lo ponía en debug/profile) | ✅ |
| G7.7 | Sin permisos innecesarios | Cada permiso declarado debe usarse | ☐ |
| G7.8 | Icono con máscara dinámica | Desde 15-jun-2026 se renderiza con **30% de radio**; zona segura ~15–18% | ☐ |

### 7.2 · App Content — todas las declaraciones obligatorias

Play Console → **App content**. Sin completarlas no se puede publicar en ninguna pista.

| ID | Declaración | Detalle | ✓ |
| --- | --- | --- | --- |
| G7.9 | **Política de privacidad** | URL pública y activa → `juroviapp.com/privacidad` | ✅ |
| G7.10 | **App access** | Credenciales para el revisor (hasta 5 juegos). **Credenciales inválidas o vencidas = rechazo clásico** | ☐ |
| G7.11 | **Ads** | Declarar si hay publicidad, incluidos SDK de terceros. Jurovia: **No** | ☐ |
| G7.12 | **Content rating (IARC)** | Cuestionario completo | ☐ |
| G7.13 | **Target audience** | Público: adultos (profesionales). **No dirigido a menores** | ☐ |
| G7.14 | **News apps** | No aplica | n/a |
| G7.15 | **COVID-19** | No aplica | n/a |
| G7.16 | **Data safety** | Ver §7.3 | ☐ |
| G7.17 | **Government apps** | No aplica | n/a |
| G7.18 | **Financial features** | Jurovia no es financiera. Declarar "ninguna" | ☐ |
| G7.19 | **Health apps** | No aplica | n/a |
| G7.20 | **Sensitive app permissions** | Solo si se piden permisos restringidos | ☐ |
| G7.21 | **Account deletion** | **Obligatorio si hay registro.** Ver §7.4 | ☐ |
| G7.22 | **AI-generated content** | Ver §8 | ☐ |

### 7.3 · Data Safety — la que más rechazos causa

Play Console corre **comprobaciones automáticas contra el AAB**. Si el binario accede
a datos que no declaraste, te marca **antes** de la revisión humana.

Para cada una de las 14 categorías hay que declarar: si se recolecta, si se comparte,
para qué, si está cifrada en tránsito y si el usuario puede pedir su borrado.

Declaración mínima de Jurovia:

| Tipo de dato | Recolecta | Comparte | Propósito | Obligatorio |
| --- | --- | --- | --- | --- |
| Nombre | Sí | No | Funciones de la app | Opcional |
| Correo | Sí | No | Funciones, gestión de cuenta | Obligatorio |
| ID de usuario | Sí | No | Funciones de la app | Obligatorio |
| **Otro contenido del usuario** (mensajes, documentos) | Sí | **Sí** → proveedor de IA | Funciones de la app | Obligatorio |
| Archivos y documentos | Sí | **Sí** → proveedor de IA | Funciones de la app | Opcional |
| Interacciones con la app | Sí | No | Analítica | Opcional |
| Registros de fallos / diagnóstico | Sí | No | Diagnóstico | Opcional |

Más:

| ID | Requisito | ✓ |
| --- | --- | --- |
| G7.23 | **Cifrado en tránsito** declarado (TLS) | ☐ |
| G7.24 | **El usuario puede solicitar el borrado** → sí | ☐ |
| G7.25 | **URL de eliminación de cuenta** en el formulario | ☐ |
| G7.26 | Coherencia total con la política de privacidad y con las etiquetas de Apple | ☐ |

> ⚠️ **"Comparte con terceros" debe marcarse Sí** porque el contenido del usuario va al
> proveedor de IA para generar la respuesta. Ocultarlo es causa de retirada.

### 7.4 · Eliminación de cuenta (Google)

Enforcement pleno desde el 15-abr-2024. Dos vías **obligatorias**:

| ID | Requisito | ✓ |
| --- | --- | --- |
| G7.27 | **Dentro de la app**: el usuario puede pedir el borrado de cuenta y datos | ☐ |
| G7.28 | **Fuera de la app**: URL web que permite pedirlo **sin reinstalar** | ☐ |
| G7.29 | URL cargada en el campo del formulario de Data safety | ☐ |
| G7.30 | Borrado **real** de los datos asociados. Desactivar o congelar **no cuenta** | ✅ backend lo hace |
| G7.31 | Si se retiene algo por ley o antifraude, **informarlo claramente** | ☐ |

> Aplica **aunque el registro sea opcional**. Basta con que exista la posibilidad de
> crear cuenta.
> **Estado de Jurovia:** `POST /api/me/delete` ya cancela Paddle, borra el org en
> cascada y limpia por correo. Falta **la pantalla en la app** y **la página web**
> (`juroviapp.com/eliminar-cuenta` hoy da **404**).

---

<a id="8"></a>
## §8 · Ambas — Requisitos por ser una app de IA jurídica

Esta es la sección que se suele pasar por alto y la que más riesgo tiene para Jurovia.

### 8.1 · Apple — Consentimiento de IA de terceros (5.1.2(i))

Texto literal de la guía:

> *"You must clearly disclose where personal data will be shared with third parties,
> **including with third-party AI**, and obtain explicit permission before doing so."*

Jurovia envía el contenido de los casos —con datos de clientes de abogados— a Anthropic.
Eso activa la regla de lleno.

| ID | Requisito | ✓ |
| --- | --- | --- |
| C8.1 | Pantalla de consentimiento **antes del primer uso** del agente | ☐ |
| C8.2 | **Identificar al proveedor por nombre**: "Anthropic (Claude)" | ☐ |
| C8.3 | Explicar **qué datos** se envían (mensajes, documentos adjuntos) | ☐ |
| C8.4 | **Permiso explícito**, con acción afirmativa. No basta con seguir usando | ☐ |
| C8.5 | **No enterrarlo** en los términos ni en la política de privacidad | ☐ |
| C8.6 | Poder **revocar** el consentimiento desde Ajustes | ☐ |
| C8.7 | Registrar el consentimiento server-side (ya existe tabla `consents`) | ☐ |

### 8.2 · Ambas — Etiquetado de contenido generado por IA

| ID | Requisito | Tienda | ✓ |
| --- | --- | --- | --- |
| C8.8 | Indicar visiblemente que la respuesta la generó IA | Ambas | ☐ |
| C8.9 | No inducir a creer que la escribió una persona | Ambas | ☐ |
| C8.10 | Describir con honestidad lo que la IA puede y no puede hacer | Apple | ☐ |

### 8.3 · Google — Política de contenido generado por IA

Aplica porque **el chatbot de texto es la función central** de Jurovia.

| ID | Requisito | ✓ |
| --- | --- | --- |
| C8.11 | **Mecanismo de reporte dentro de la app**, en el propio contenido generado, **sin salir de la app** | ☐ |
| C8.12 | Usar los reportes para mejorar el filtrado y la moderación | ☐ |
| C8.13 | Salvaguardas contra generación de contenido prohibido | ☐ |
| C8.14 | Declararlo en App Content | ☐ |
| C8.15 | Pruebas documentadas de los modelos frente a *prompts* adversarios | ☐ |

> **Implementación mínima:** botón "Reportar" junto a los de copiar / pulgar arriba /
> reintentar que el prototipo ya dibuja en cada respuesta del agente. Es un cambio
> pequeño y cubre C8.11 y A3.1 a la vez.

### 8.4 · Asesoría jurídica — descargos de responsabilidad

| ID | Requisito | ✓ |
| --- | --- | --- |
| C8.16 | Aviso visible de que **no sustituye asesoría legal profesional** | ☐ |
| C8.17 | Aviso de que las respuestas pueden contener errores y **deben verificarse** | ☐ |
| C8.18 | El dorado de "fuente verificada" **solo** en fuentes realmente contrastadas | ☐ |
| C8.19 | Términos accesibles desde la app, no solo desde la web | ☐ |

> La marca ya tiene el mensaje correcto: **"Tú revisas y decides."** Debe aparecer
> en la app, no solo en el material de marketing.

### 8.5 · Colombia — Habeas Data (fuera de tienda, pero exigible)

| ID | Requisito | ✓ |
| --- | --- | --- |
| C8.20 | Cumplir Ley 1581 de 2012 y Decreto 1377 de 2013 | ☐ |
| C8.21 | Autorización para el tratamiento de datos personales | ☐ |
| C8.22 | Aviso de privacidad accesible | ☐ |
| C8.23 | Canal para ejercer derechos (conocer, actualizar, rectificar, suprimir) | ☐ |
| C8.24 | Considerar el registro en el RNBD ante la SIC | ☐ |

> Los abogados suben **datos de terceros** (sus clientes). Jurovia es *encargado del
> tratamiento*. Conviene revisión legal propia; excede el alcance de las tiendas.

---

<a id="9"></a>
## §9 · Fuentes oficiales

Reverificar aquí antes de enviar.

**Apple**
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Upcoming requirements / SDK mínimo](https://developer.apple.com/news/upcoming-requirements/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [TN3183 — Required reason API entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)

**Google**
- [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)
- [AI-Generated Content policy](https://support.google.com/googleplay/android-developer/answer/14094294)
- [App account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Declare permissions](https://support.google.com/googleplay/android-developer/answer/9214102)
- [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)

---

<a id="10"></a>
## §10 · Matriz de verificación final

Nada se envía hasta que **todas** las filas críticas estén en ✅.

### 10.1 · Crítico — el envío falla sin esto

| # | Ítem | Apple | Google | ✓ |
| --- | --- | --- | --- | --- |
| 1 | Cuenta de desarrollador pagada y verificada | ✅ | ✅ | ☐ |
| 2 | D-U-N-S (si organización) | ✅ | ✅ | ☐ |
| 3 | Mac con macOS 15.6+ y **Xcode 26 / SDK iOS 26** | ✅ | — | ☐ |
| 4 | `PrivacyInfo.xcprivacy` + Required Reason APIs | ✅ | — | ☐ |
| 5 | Target API 36 (desde 31-ago-2026) | — | ✅ | ✅ verificado |
| 6 | AAB + Play App Signing | — | ✅ | ☐ (AAB ✅ · falta activar Play App Signing) |
| 7 | Soporte de páginas de 16 KB | — | ✅ | ✅ verificado en el AAB |
| 8 | **Consentimiento explícito de IA de terceros** | ✅ | ✅ | ☐ |
| 9 | **Reporte de contenido de IA dentro de la app** | ✅ | ✅ | ☐ |
| 10 | **Eliminación de cuenta en la app** | ✅ | ✅ | ☐ |
| 11 | **URL pública de eliminación de cuenta** | — | ✅ | ☐ |
| 12 | **Cero comercio y cero *steering* en la app** | ✅ | — | ☐ |
| 13 | Cuenta de demo funcional con plan activo | ✅ | ✅ | ☐ |
| 14 | Política de privacidad enlazada **dentro** de la app | ✅ | ✅ | ☐ |
| 15 | Formulario de Data safety completo y coherente | — | ✅ | ☐ |
| 16 | App Privacy labels completas y coherentes | ✅ | — | ☐ |
| 17 | Clasificación por edad / IARC | ✅ | ✅ | ☐ |
| 18 | Prueba cerrada 12×14 días (cuenta personal) | — | ✅ | ☐ |

### 10.2 · Alto — rechazo probable

| # | Ítem | ✓ |
| --- | --- | --- |
| 19 | Icono 1024×1024 sin alfa ni transparencia | ☐ |
| 20 | Capturas mostrando la app **en uso** (≥3 en 6.9") | ☐ |
| 21 | Notas para Revisión específicas (plantilla §5.1) | ☐ |
| 22 | Todos los enlaces de la ficha funcionando | ☐ |
| 23 | Sin *placeholders* ni funciones "próximamente" | ☐ |
| 24 | Purpose strings claros para cada permiso pedido | ☐ |
| 25 | Sin permisos declarados que no se usen | ☐ |
| 26 | Sin SDK publicitarios (evita ATT) | ☐ |
| 27 | Funcionalidad nativa suficiente (regla 4.2) | ☐ |
| 28 | Descargo de responsabilidad jurídica visible | ☐ |
| 29 | Sin crashes en dispositivo real, iOS y Android | ☐ |
| 30 | Solo login OTP propio (evita la regla 4.8) | ☐ |

### 10.3 · Medio — retrasos o retiradas posteriores

| # | Ítem | ✓ |
| --- | --- | --- |
| 31 | Etiquetado de contenido generado por IA en cada respuesta | ☐ |
| 32 | Consentimiento revocable desde Ajustes | ☐ |
| 33 | Habeas Data / Ley 1581 | ☐ |
| 34 | Modo oscuro coherente | ☐ |
| 35 | Estados de error y sin conexión decentes | ☐ |
| 36 | Accesibilidad básica (contraste, tamaños dinámicos, VoiceOver/TalkBack) | ☐ |
| 37 | Pruebas adversarias del modelo documentadas | ☐ |
| 38 | Canal de soporte publicado y atendido | ☐ |

---

## Apéndice · Orden de ataque recomendado

**Semana 0 — lo que tarda por sí solo**
D-U-N-S (si organización) · comprar cuentas Apple y Google · verificación de identidad ·
conseguir el Mac · arrancar la prueba cerrada de Google si la cuenta es personal.

**Semanas 1–2 — lo que solo depende de código**
Consentimiento de IA · botón de reporte · eliminación de cuenta en la app ·
página web `/eliminar-cuenta` · quitar todo comercio del diseño ·
descargo jurídico · privacy manifest.

**Semana 3 — activos y formularios**
Icono · capturas · descripciones · Data safety · App Privacy · clasificación por edad ·
cuenta de demo · notas para revisión.

**Semana 4 — envío**
Primer AAB **a mano** en Play Console (la API no puede crear la app ni subir el
primero) · TestFlight interno · envío a revisión de ambas.

> **La ruta crítica no es el código: es el D-U-N-S, el Mac y los 14 días de prueba
> cerrada.** Empezar por ahí.
