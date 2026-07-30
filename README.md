# Jurovia — app móvil

Cliente móvil de [Jurovia](https://juroviapp.com) en Flutter, para iOS y Android.

A las tiendas sube **solo este cliente**. El backend vive en Railway y la app lo
consume por HTTPS autenticando con el JWT de Supabase.

```
app (Flutter)  ──HTTPS──>  backend FastAPI (Railway)  ──>  Supabase / agente
```

## Estado

Andamiaje y **pipeline de publicación** listos. La app en sí todavía no existe:
la pantalla actual es un diagnóstico que muestra con qué configuración se
compiló el binario y comprueba que alcanza el backend.

Falta: login con Supabase, chat con el agente y eliminación de cuenta.

## Requisitos

- Flutter 3.44.8 (`flutter --version`)
- JDK 17 y Android SDK para compilar Android
- macOS con Xcode para compilar iOS (no hay forma de hacerlo desde Windows)

## Empezar

```powershell
flutter pub get
.\tool\run_local.ps1                              # emulador/dispositivo por defecto
.\tool\run_local.ps1 -Dispositivo emulator-5554   # uno concreto
```

El script toma la anon key del `.env.local` del frontend de Jurovia (mismo
proyecto de Supabase) y la inyecta por `--dart-define`, así que la llave nunca
se escribe dentro de este repositorio. Equivalente a mano:

```bash
flutter run --dart-define=SUPABASE_ANON_KEY=<la anon key>
```

La configuración entra por `--dart-define`, no por archivos `.env`; ver
[`lib/core/config/app_config.dart`](lib/core/config/app_config.dart).

> **Si ves la pantalla «Falta configuración»** no es un fallo de la app: se
> compiló sin la anon key. `flutter run` a secas la omite — usa el script.
> La app lo dice en vez de fallar más tarde con un error de red confuso.

## Comprobaciones

```bash
dart format .
flutter analyze --fatal-infos
flutter test
```

## Publicar

Todo el procedimiento, credenciales y requisitos de tienda están en
[`docs/DESPLIEGUE_TIENDAS.md`](docs/DESPLIEGUE_TIENDAS.md).

Resumen: los workflows **Publicar Android** y **Publicar iOS** en la pestaña
Actions compilan firmado y suben como borrador. Requieren las cuentas de
desarrollador y los secrets configurados.

## Nota sobre cobros

La app **no vende suscripciones**. Apple y Google exigen su propio sistema de
pago para desbloquear funciones digitales dentro de la app, así que el checkout
de Paddle solo vive en la web. La app permite registro y prueba gratis y muestra
el plan actual. Detalle y alternativas en la sección 6 del documento de
despliegue.
