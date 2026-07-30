# Despliegue a App Store y Google Play

App móvil de Jurovia en **Flutter**. A las tiendas sube **solo el cliente**;
el backend se queda en Railway y la app le habla por HTTPS.

El repositorio ya tiene listo todo el lado técnico. Lo que falta son cosas que
**solo puede hacer el titular de la cuenta**: pagar, verificar identidad y
firmar contratos.

---

## 1. Identidad de la app (ya configurada)

| Concepto | Valor |
| --- | --- |
| Nombre visible | Jurovia |
| Paquete Dart | `jurovia` |
| Bundle ID iOS / applicationId Android | `com.jurovia.app` |
| Deep link | `jurovia://` |
| Versión | `1.0.0+1` (en `pubspec.yaml`) |
| Flutter | 3.44.8 (fijado en los workflows) |

> El identificador `com.jurovia.app` **no se puede cambiar** una vez publicada
> la app. Si prefieres otro (`com.tdxcore.jurovia`), hay que decidirlo ahora.
> Está en `android/app/build.gradle.kts` y en `ios/Runner.xcodeproj`.

El **build number** lo inyecta CI con `--build-number=${{ github.run_number }}`,
que siempre crece. Ambas tiendas rechazan un envío cuyo número no sea mayor que
el anterior, así que no hay que tocarlo a mano.

---

## 2. Cuentas de desarrollador — SOLO TÚ PUEDES HACER ESTO

### Apple Developer Program — 99 USD/año

1. https://developer.apple.com/programs/enroll/
2. Apple Account con **doble factor activo**.
3. Como **empresa** (TDX Core) Apple exige un número **D-U-N-S**: gratis pero
   tarda de días a semanas. Como **individuo** es inmediato, pero la app queda a
   tu nombre personal.
   → **Es el cuello de botella más largo de todo el proyecto. Decídelo primero.**
4. En App Store Connect: **My Apps → +**, con el bundle ID `com.jurovia.app`.
5. Aceptar los **Paid Apps Agreement** (Business → Agreements).

### Google Play Console — 25 USD pago único

1. https://play.google.com/console/signup
2. Verificación de identidad con documento.
3. **Regla de tiempo:** las cuentas **personales** creadas después de nov-2023
   deben correr una prueba cerrada con **12 testers durante 14 días seguidos**
   antes de pedir acceso a producción. Las de **organización** están exentas.
   Verifica la regla vigente al registrarte, que Google la ha ido cambiando.

---

## 3. Firma de la aplicación

### Android — keystore de subida

Se genera **una sola vez**:

```bash
keytool -genkey -v -keystore jurovia-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copia `android/key.properties.example` a `android/key.properties` y rellénalo
(el archivo real no se versiona). Sin él, los builds locales de release usan la
llave de debug y siguen funcionando.

> **Activa Play App Signing** en Play Console. Con eso Google conserva la llave
> de firma final y la tuya pasa a ser solo la de *subida*, que sí es
> reemplazable si la pierdes. Sin Play App Signing, perder el keystore significa
> **no poder volver a actualizar la app nunca**.

### iOS — certificado y perfil

Necesitas, desde tu cuenta de Apple Developer:

1. Un **Apple Distribution certificate** exportado como `.p12` con contraseña.
2. Un **provisioning profile** de tipo App Store para `com.jurovia.app`.
3. Una **App Store Connect API Key** (Users and Access → Integrations), rol
   *App Manager*. Descargas un `.p8` **que solo se puede bajar una vez**, y
   anotas **Key ID**, **Issuer ID** y **Team ID**.

---

## 4. Secrets en GitHub

`Settings → Secrets and variables → Actions`:

| Secret | Plataforma | Qué es |
| --- | --- | --- |
| `SUPABASE_ANON_KEY` | ambas | llave pública de Supabase |
| `ANDROID_KEYSTORE_BASE64` | Android | el `.jks` en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Android | contraseña del keystore |
| `ANDROID_KEY_PASSWORD` | Android | contraseña de la llave |
| `ANDROID_KEY_ALIAS` | Android | normalmente `upload` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Android | JSON del service account |
| `IOS_CERTIFICATE_BASE64` | iOS | el `.p12` en base64 |
| `IOS_CERTIFICATE_PASSWORD` | iOS | contraseña del `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | iOS | el `.mobileprovision` en base64 |
| `APPLE_ASC_KEY_BASE64` | iOS | el `.p8` en base64 |
| `APPLE_ASC_KEY_ID` | iOS | Key ID |
| `APPLE_ASC_ISSUER_ID` | iOS | Issuer ID |
| `APPLE_TEAM_ID` | iOS | Team ID |

Para pasar un archivo a base64:

```bash
base64 -w 0 jurovia-upload.jks    # Linux / Git Bash
certutil -encode jurovia-upload.jks salida.txt   # Windows nativo
```

### Service account de Google Play

1. Play Console → **Setup → API access** → vincular un proyecto de Google Cloud.
2. Crear un **service account** en Google Cloud IAM y generar llave **JSON**.
3. Play Console → **Users and permissions → Invite**, dar al service account
   permiso de **Release apps to testing tracks** y **Release to production**.

> **Restricción de la primera vez:** la API de Google Play **no puede crear la
> app ni subir el primer AAB**. Ese primero va a mano por Play Console. Del
> segundo en adelante, el workflow ya lo hace solo.

---

## 5. Requisitos de contenido

| Requisito | Estado |
| --- | --- |
| Política de privacidad | **Listo** → https://juroviapp.com/privacidad |
| Términos y condiciones | **Listo** → https://juroviapp.com/terminos |
| **Eliminación de cuenta** | **FALTA — bloqueante** |
| Icono 1024×1024 sin transparencia | Pendiente (hoy va el de la plantilla) |
| Capturas por tamaño de dispositivo | Pendiente |
| Clasificación por edad | Pendiente (formulario en cada consola) |
| Data safety / App Privacy | Pendiente |

### Eliminación de cuenta — bloqueante

Apple (regla 5.1.1(v)) y Google Play exigen que una app con registro permita
**borrar la cuenta desde dentro de la app**, y Google pide además una **URL
pública** de solicitud de borrado.

`https://juroviapp.com/eliminar-cuenta` hoy devuelve **404**. Hace falta:

1. Crear esa página en el frontend web.
2. Opción "Eliminar mi cuenta" dentro de la app.
3. Endpoint en el backend que borre de verdad los datos.

Sin esto, Apple rechaza el envío en revisión.

---

## 6. Cobro: por qué Paddle no puede ir dentro de la app

La regla **3.1.1** de Apple obliga a que cualquier desbloqueo de funciones
digitales dentro de la app pase por **In-App Purchase**. Google Play tiene la
regla equivalente con **Google Play Billing**. Abrir el checkout de Paddle
dentro del binario es causal de **rechazo en revisión** — no es un problema
técnico, el checkout funcionaría perfectamente.

Comisión: 30% por defecto, **15%** con el Small Business Program (menos de 1M
USD/año) y 15% para suscripciones después del primer año de cada suscriptor.

En **Estados Unidos** las apps ya pueden enlazar a un checkout externo sin
comisión, y en la **Unión Europea** con ciertas tarifas. En **Colombia** sigue
aplicando la regla tradicional.

**Decisión tomada en este repo:** `AppConfig.showPaddleCheckout` está en
`false`. La app permite registro y prueba gratis, muestra el plan actual, y no
ofrece ni enlaza la compra — que es lo que permite la regla **3.1.3(b)** y lo
que hacen Notion, Slack y Figma. Hay una prueba automática que falla si alguien
lo enciende por accidente.

Si más adelante se quiere vender dentro de la app, se implementan suscripciones
nativas (IAP), no Paddle.

---

## 7. Cómo se compila

```bash
# Android (local)
flutter build appbundle --release --build-number=1 \
  --dart-define=SUPABASE_ANON_KEY=...

# iOS: solo en macOS con Xcode
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Desde CI, en la pestaña **Actions**:

- **CI** — análisis y pruebas en cada push/PR. No necesita credenciales.
- **Publicar Android (Google Play)** — compila el AAB firmado y lo sube.
- **Publicar iOS (TestFlight / App Store)** — corre en runner **macOS**.

Los dos de publicación fallan de entrada, con mensaje claro, si falta un secret.
Suben como **borrador** (`draft` / TestFlight) para que nada llegue solo al
público.

> **iOS necesita macOS.** Xcode no existe para Windows ni Linux, así que ese job
> corre en `macos-latest`, que consume minutos de GitHub Actions a ~10× la
> tarifa de Linux. Para desarrollo diario de iOS hace falta un Mac.

---

## 8. Orden recomendado

1. Decidir **empresa vs individuo** en Apple. Si es empresa, pedir el D-U-N-S **hoy**.
2. Pagar Google Play y arrancar el reloj de los 14 días si aplica.
3. Confirmar la decisión de cobro (sin venta en la app, o IAP).
4. Construir la app: login con Supabase + chat contra el backend.
5. Página y endpoint de **eliminación de cuenta**.
6. Icono y capturas definitivos.
7. Añadir `jurovia://**` a la `uri_allow_list` de Supabase (Auth → URL Configuration),
   que hoy solo tiene dominios web y sin eso el OTP no regresa a la app.
8. Primer AAB a mano en Play Console; de ahí en adelante, todo automático.
