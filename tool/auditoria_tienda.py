#!/usr/bin/env python3
"""Auditoría de tienda — comprobaciones mecánicas antes de enviar.

Corre en CI y en local. Falla el build si detecta algo que haría rechazable la
app en App Store o Google Play. Comprueba lo que se puede verificar leyendo el
repositorio; el resto está en `AuditCheck.md`.

    python tool/auditoria_tienda.py
"""
from __future__ import annotations

import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fallos: list[str] = []
avisos: list[str] = []
oks: list[str] = []


def leer(*partes: str) -> str:
    ruta = os.path.join(RAIZ, *partes)
    if not os.path.exists(ruta):
        return ""
    with open(ruta, encoding="utf-8", errors="ignore") as fh:
        return fh.read()


def dart_fuentes() -> list[tuple[str, str]]:
    salida = []
    for base in ("lib",):
        for dirpath, _, files in os.walk(os.path.join(RAIZ, base)):
            for f in files:
                if f.endswith(".dart"):
                    p = os.path.join(dirpath, f)
                    rel = os.path.relpath(p, RAIZ)
                    with open(p, encoding="utf-8", errors="ignore") as fh:
                        salida.append((rel, fh.read()))
    return salida


# ─────────────── 1. Sin comercio ni steering (Apple 3.1.1 / 3.1.3) ───────────
PATRONES_COMPRA = [
    r"suscr[ií]bete",
    r"comprar ahora",
    r"mejorar plan",
    r"actualiza tu plan",
    r"juroviapp\.com/planes",
    r"facturaci[óo]n en la web",
    r"paga en (?:la )?web",
    r"continuar con pro",
]
encontrados = []
for rel, src in dart_fuentes():
    # Se ignoran los comentarios: ahí SÍ se habla de estas reglas.
    codigo = re.sub(r"//.*", "", src)
    codigo = re.sub(r"/\*.*?\*/", "", codigo, flags=re.S)
    for pat in PATRONES_COMPRA:
        for m in re.finditer(pat, codigo, re.I):
            encontrados.append(f"{rel}: «{m.group(0)}»")

if encontrados:
    fallos.append(
        "Texto de compra o *steering* en la app (Apple 3.1.1 / 3.1.3):\n    "
        + "\n    ".join(encontrados)
    )
else:
    oks.append("Sin textos de compra ni steering en lib/")

# ─────────────── 2. StorePolicy sigue en sus invariantes ─────────────────────
policy = leer("lib", "compliance", "store_policy.dart")
for clave in (
    "allowsInAppPurchase = false",
    "allowsExternalPurchaseLink = false",
    "hasAdvertisingSdk = false",
    "hasThirdPartyLogin = false",
):
    if clave.replace(" ", "") not in policy.replace(" ", ""):
        fallos.append(f"StorePolicy: se esperaba `{clave}`")
if not fallos or all("StorePolicy" not in f for f in fallos):
    oks.append("StorePolicy conserva sus 4 invariantes")

if "Anthropic" not in policy:
    fallos.append(
        "StorePolicy.aiProvider debe nombrar al proveedor (Apple 5.1.2(i))"
    )
else:
    oks.append("El proveedor de IA está nombrado explícitamente")

# ─────────────── 2b. Muro de plan: explica sin hacer steering ────────────────
# Apple 3.1.3(b) permite USAR dentro de la app una suscripción contratada fuera,
# y explicarlo es legítimo. Lo que rechaza es decir DÓNDE pagar. La frontera
# está en el texto, así que se verifica que exista y que esté limpio.
muro = leer("lib", "compliance", "billing", "billing_policy.dart")
if not muro:
    fallos.append(
        "Falta el muro de plan (lib/compliance/billing/): sin él la app calla "
        "cuando el usuario choca con el límite de su plan"
    )
else:
    # Solo las cadenas literales: los comentarios sí hablan de estas reglas.
    literales = " ".join(re.findall(r"'([^']*)'", re.sub(r"//.*", "", muro)))
    sucio = [
        p
        for p in ("http", "www.", ".com", "juroviapp", "precio", "tarjeta",
                  "paddle", "app store", "google play")
        if p in literales.lower()
    ]
    if sucio:
        fallos.append(
            "El texto del muro de plan hace *steering* (Apple 3.1.3): "
            + ", ".join(f"«{s}»" for s in sucio)
        )
    elif "no se puede cancelar ni modificar desde esta app" not in literales:
        fallos.append(
            "TextosMuro perdió la explicación de multiplataforma: sin ella el "
            "usuario no sabe por qué no puede gestionar su plan aquí"
        )
    else:
        oks.append("Muro de plan presente y sin steering (Apple 3.1.3(b))")

# Un botón «Restaurar compras» sin IAP no puede restaurar nada, y los revisores
# lo tocan. Si aparece, es que se añadió IAP o que se prometió algo falso.
for rel, src in dart_fuentes():
    codigo = re.sub(r"//.*", "", src)
    if re.search(r"restaurar compras", codigo, re.I):
        fallos.append(
            f"{rel}: «Restaurar compras» sin IAP no restaura nada "
            "(allowsInAppPurchase = false)"
        )

# ─────────────── 3. Consentimiento de IA como puerta ─────────────────────────
repo_chat = leer("lib", "features", "chat", "chat_repository.dart")
if "AiConsentToken" not in repo_chat:
    fallos.append(
        "ChatRepository debe exigir un AiConsentToken: sin él, el agente sería "
        "invocable sin consentimiento (Apple 5.1.2(i))"
    )
else:
    oks.append("ChatRepository exige AiConsentToken en el constructor")

gate = leer("lib", "compliance", "ai_consent", "ai_consent_gate.dart")
if "AiConsentToken._()" not in gate:
    fallos.append("El constructor de AiConsentToken debe ser privado")
else:
    oks.append("Solo AiConsentGate puede emitir el token")

# ─────────────── 4. Etiquetado de IA y reporte (C8.8 / C8.11) ────────────────
if not leer("lib", "compliance", "reporting", "report_sheet.dart"):
    fallos.append("Falta la hoja de reporte de contenido de IA (Google)")
else:
    oks.append("Hoja de reporte de contenido de IA presente")

burbuja = leer("lib", "features", "chat", "widgets", "message_bubble.dart")
if "AiLabel" not in burbuja:
    fallos.append("Las respuestas del agente deben llevar la etiqueta AiLabel")
else:
    oks.append("Las respuestas llevan etiqueta de IA y descargo")

# ─────────────── 5. Borrado de cuenta (A3.29 / G7.27) ────────────────────────
borrado = leer("lib", "compliance", "account_deletion", "delete_account_screen.dart")
if "/api/me/delete" not in borrado:
    fallos.append("Falta la eliminación de cuenta dentro de la app")
else:
    oks.append("Eliminación de cuenta dentro de la app presente")

# ─────────────── 6. Android: permiso INTERNET en el manifiesto de release ────
manifest = leer("android", "app", "src", "main", "AndroidManifest.xml")
if "android.permission.INTERNET" not in manifest:
    fallos.append(
        "El manifiesto principal no declara INTERNET: el build de RELEASE "
        "saldría sin red (funciona en debug, muere en la tienda)"
    )
else:
    oks.append("INTERNET declarado en el manifiesto de release")

# ─────────────── 7. iOS: privacy manifest y purpose strings ──────────────────
if not leer("ios", "Runner", "PrivacyInfo.xcprivacy"):
    fallos.append(
        "Falta ios/Runner/PrivacyInfo.xcprivacy: App Store Connect rechaza la "
        "subida del binario sin él"
    )
else:
    oks.append("PrivacyInfo.xcprivacy presente")

info = leer("ios", "Runner", "Info.plist")
if "ITSAppUsesNonExemptEncryption" not in info:
    avisos.append(
        "Sin ITSAppUsesNonExemptEncryption, App Store Connect pregunta por "
        "cumplimiento de exportación en cada envío"
    )
else:
    oks.append("Declaración de cifrado de exportación presente")

# Permisos declarados en el manifiesto que deben tener purpose string.
pares = [
    ("android.permission.CAMERA", "NSCameraUsageDescription"),
    ("android.permission.RECORD_AUDIO", "NSMicrophoneUsageDescription"),
]
for perm, clave in pares:
    if perm in manifest and clave not in info:
        fallos.append(
            f"Android pide {perm} pero iOS no declara {clave}: rechazo seguro"
        )

# ─────────────── 8. Sin SDK publicitarios en pubspec ─────────────────────────
pubspec = leer("pubspec.yaml")
SOSPECHOSOS = [
    "facebook_app_events",
    "firebase_analytics",
    "google_mobile_ads",
    "appsflyer",
    "adjust_sdk",
    "amplitude",
]
hallados = [s for s in SOSPECHOSOS if s in pubspec]
if hallados:
    fallos.append(
        "SDK de publicidad/atribución en pubspec: obliga a App Tracking "
        f"Transparency y a declarar dominios de rastreo → {', '.join(hallados)}"
    )
else:
    oks.append("Sin SDK publicitarios (ATT no aplica)")

# ─────────────── 9. La anon key no está escrita en el código ─────────────────
for rel, src in dart_fuentes():
    if re.search(r"eyJhbGciOi[A-Za-z0-9_\-\.]{40,}", src):
        fallos.append(f"{rel}: hay un JWT escrito en el código. Usa --dart-define")
        break
else:
    oks.append("Ninguna llave escrita en el código")



# ─────── 10. Iconos presentes y sin alfa en iOS (A5.6 / G7.8) ────────────────
try:
    from PIL import Image  # type: ignore

    ios_icon = os.path.join(
        RAIZ, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset",
        "Icon-App-1024x1024@1x.png",
    )
    if not os.path.exists(ios_icon):
        fallos.append("Falta el icono 1024x1024 de iOS")
    else:
        im = Image.open(ios_icon)
        if im.mode in ("RGBA", "LA") or "transparency" in im.info:
            fallos.append(
                "El icono 1024 de iOS tiene canal alfa: Apple lo rechaza (A5.6)"
            )
        elif im.size != (1024, 1024):
            fallos.append(f"El icono de iOS mide {im.size}, debe ser 1024x1024")
        else:
            oks.append("Icono de iOS 1024x1024 sin alfa")

    faltan_android = [
        d for d in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
        if not os.path.exists(os.path.join(
            RAIZ, "android", "app", "src", "main", "res",
            f"mipmap-{d}", "ic_launcher.png"))
    ]
    if faltan_android:
        fallos.append(f"Faltan iconos de Android en: {', '.join(faltan_android)}")
    else:
        oks.append("Iconos de Android en las 5 densidades")
except ImportError:
    avisos.append("Pillow no instalado: no se pudo verificar el icono")


# ─────── 11. Privacy manifests de las dependencias nativas (A2.6) ────────────
lock = leer("pubspec.lock")
nativas = []
for nombre in re.findall(r"^  ([a-z0-9_]+):", lock, re.M):
    # Paquetes de Flutter con implementación nativa conocida.
    if nombre in {
        "flutter_secure_storage", "image_picker", "record", "path_provider",
        "share_plus", "url_launcher", "permission_handler",
        "shared_preferences", "supabase_flutter",
    }:
        nativas.append(nombre)
if nativas:
    avisos.append(
        "Dependencias con código nativo a verificar en App Store Connect "
        "(deben traer su PrivacyInfo.xcprivacy): " + ", ".join(sorted(set(nativas)))
    )


# ─────── 12. Ofuscación activada en los workflows de release (F5.06) ─────────
for wf in ("release-android.yml", "release-ios.yml"):
    contenido = leer(".github", "workflows", wf)
    if contenido and "--obfuscate" not in contenido:
        fallos.append(f"{wf}: falta --obfuscate en el build de release")
if all("--obfuscate" in leer(".github", "workflows", w)
       for w in ("release-android.yml", "release-ios.yml")):
    oks.append("Builds de release ofuscados con símbolos guardados")


# ─────── 13. Página pública de eliminación de cuenta (G7.28) ─────────────────
web = os.path.join(
    os.path.dirname(RAIZ), "Legal_AI_Frontend", "app", "eliminar-cuenta", "page.tsx"
)
if os.path.exists(web):
    oks.append("Página web /eliminar-cuenta presente en el frontend")
else:
    fallos.append(
        "Falta juroviapp.com/eliminar-cuenta: Google exige una URL pública "
        "de borrado accesible sin reinstalar la app (G7.28)"
    )


# ─────────────────────────────── Informe ─────────────────────────────────────
print("\n=== AUDITORÍA DE TIENDA ===\n")
for o in oks:
    print(f"  OK    {o}")
for a in avisos:
    print(f"  AVISO {a}")
for f in fallos:
    print(f"  FALLA {f}")

print(f"\n{len(oks)} correctas · {len(avisos)} avisos · {len(fallos)} fallas")
if fallos:
    print("\nLa app NO está lista para enviar. Ver AuditCheck.md")
    sys.exit(1)
print("\nComprobaciones mecánicas superadas.")
print("Lo que no se puede automatizar sigue en AuditCheck.md §10.")
