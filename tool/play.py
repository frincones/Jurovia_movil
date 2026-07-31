#!/usr/bin/env python3
"""Cliente de la Google Play Developer API — despliegue sin navegador.

Una cuenta de servicio se autentica con un JWT firmado, no con OAuth
interactivo, así que todo esto corre sin abrir una sola pestaña.

    python tool/play.py estado
    python tool/play.py siguiente-version
    python tool/play.py subir --track internal --notas "Primera build"
    python tool/play.py promover --de internal --a alpha

La credencial se busca, en este orden:
  1. $GOOGLE_PLAY_SERVICE_ACCOUNT_JSON  (ruta o el JSON entero)
  2. credentials/google-play-service-account.json

Esa carpeta está en `.gitignore`: la llave nunca entra al repositorio.

LO QUE LA API **NO** PUEDE HACER, por diseño de Google:
  · crear la app
  · el formulario de Seguridad de los datos
  · el cuestionario de clasificación de contenido
  · público objetivo, acceso a la app, apps gubernamentales/financieras/salud
  · aceptar acuerdos ni la verificación de desarrollador
Eso se rellena una vez a mano en la Console. Todo lo demás —subir, publicar,
promover entre canales, ajustar despliegue por porcentaje, editar la ficha— sí.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PAQUETE = "com.jurovia.app"
AAB = RAIZ / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"

API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
SUBIDA = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
AMBITO = "https://www.googleapis.com/auth/androidpublisher"

# Producción exige un `--si-de-verdad` explícito: un despliegue accidental a
# producción se ve, se descarga y no se puede "deshacer" — solo se sustituye.
CANALES = ("internal", "alpha", "beta", "production")


def _cargar_credencial():
    crudo = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    datos = None
    if crudo.startswith("{"):
        datos = json.loads(crudo)
    elif crudo and Path(crudo).exists():
        datos = json.loads(Path(crudo).read_text(encoding="utf-8"))
    else:
        ruta = RAIZ / "credentials" / "google-play-service-account.json"
        if ruta.exists():
            datos = json.loads(ruta.read_text(encoding="utf-8"))

    if not datos:
        sys.exit(
            "No encuentro la cuenta de servicio.\n"
            "  Ponla en credentials/google-play-service-account.json\n"
            "  o exporta GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.\n"
            "  Cómo crearla: docs/DESPLIEGUE_TIENDAS.md"
        )
    return datos


def sesion():
    """Sesión HTTP con el token ya puesto y renovándose solo."""
    try:
        from google.auth.transport.requests import AuthorizedSession
        from google.oauth2 import service_account
    except ImportError:
        sys.exit("Falta google-auth:  pip install google-auth requests")

    cred = service_account.Credentials.from_service_account_info(
        _cargar_credencial(), scopes=[AMBITO]
    )
    return AuthorizedSession(cred)


def _pedir(s, metodo, url, **kw):
    r = s.request(metodo, url, **kw)
    if not r.ok:
        # El cuerpo del error de Google dice exactamente qué falta; enseñarlo
        # entero ahorra media hora de adivinanzas.
        sys.exit(f"\n{metodo} {url}\nHTTP {r.status_code}\n{r.text}\n")
    return r.json() if r.content else {}


# ─────────────────────────────── Comandos ────────────────────────────────


def cmd_estado(_):
    """Qué hay publicado ahora mismo en cada canal."""
    s = sesion()
    edit = _pedir(s, "POST", f"{API}/applications/{PAQUETE}/edits")
    eid = edit["id"]
    try:
        print(f"App: {PAQUETE}\n")
        for canal in CANALES:
            r = s.get(f"{API}/applications/{PAQUETE}/edits/{eid}/tracks/{canal}")
            if r.status_code == 404:
                print(f"  {canal:<11} —")
                continue
            if not r.ok:
                print(f"  {canal:<11} (sin acceso)")
                continue
            versiones = r.json().get("releases") or []
            if not versiones:
                print(f"  {canal:<11} sin versiones")
            for v in versiones:
                vc = ", ".join(str(x) for x in v.get("versionCodes") or [])
                estado = v.get("status", "?")
                frac = v.get("userFraction")
                pct = f" · {frac * 100:.0f}% de usuarios" if frac else ""
                print(f"  {canal:<11} v{vc}  [{estado}]{pct}  {v.get('name', '')}")
    finally:
        s.delete(f"{API}/applications/{PAQUETE}/edits/{eid}")


def cmd_siguiente_version(_):
    """El versionCode más alto ya visto + 1.

    Play rechaza una subida con un versionCode que ya existe, aunque esa
    versión esté borrada. Preguntárselo al servidor es lo único fiable:
    llevar la cuenta a mano en pubspec o en el contador de CI se desincroniza
    en cuanto alguien sube algo a mano desde la Console.
    """
    s = sesion()
    edit = _pedir(s, "POST", f"{API}/applications/{PAQUETE}/edits")
    eid = edit["id"]
    try:
        mayor = 0
        for canal in CANALES:
            r = s.get(f"{API}/applications/{PAQUETE}/edits/{eid}/tracks/{canal}")
            if not r.ok:
                continue
            for v in r.json().get("releases") or []:
                for vc in v.get("versionCodes") or []:
                    mayor = max(mayor, int(vc))
        print(mayor + 1)
    finally:
        s.delete(f"{API}/applications/{PAQUETE}/edits/{eid}")


def cmd_subir(a):
    if a.track == "production" and not a.si_de_verdad:
        sys.exit(
            "Producción se despliega con --si-de-verdad.\n"
            "No es burocracia: una vez fuera, la única forma de retirarla es "
            "publicar otra encima."
        )

    aab = Path(a.aab) if a.aab else AAB
    if not aab.exists():
        sys.exit(f"No existe {aab}\n  flutter build appbundle --release …")

    s = sesion()
    print(f"AAB: {aab.name}  ({aab.stat().st_size / 1e6:.1f} MB)")

    edit = _pedir(s, "POST", f"{API}/applications/{PAQUETE}/edits")
    eid = edit["id"]
    print(f"edición {eid}")

    try:
        with aab.open("rb") as fh:
            sub = _pedir(
                s,
                "POST",
                f"{SUBIDA}/applications/{PAQUETE}/edits/{eid}/bundles"
                "?uploadType=media",
                data=fh,
                headers={"Content-Type": "application/octet-stream"},
            )
        vc = sub["versionCode"]
        print(f"subido  versionCode {vc}")

        version = {
            "versionCodes": [str(vc)],
            "status": "completed" if a.porcentaje is None else "inProgress",
        }
        if a.porcentaje is not None:
            version["userFraction"] = a.porcentaje / 100
        if a.notas:
            version["releaseNotes"] = [{"language": "es-419", "text": a.notas}]
        if a.nombre:
            version["name"] = a.nombre

        _pedir(
            s,
            "PUT",
            f"{API}/applications/{PAQUETE}/edits/{eid}/tracks/{a.track}",
            json={"track": a.track, "releases": [version]},
        )
        print(f"canal   {a.track}")

        if a.borrador:
            print("\nborrador: NO se confirma la edición (nada cambia en Play)")
            return

        _pedir(s, "POST", f"{API}/applications/{PAQUETE}/edits/{eid}:commit")
        eid = None
        print(f"\nlisto · v{vc} en «{a.track}»")
        if a.track != "internal":
            print("Google la revisará antes de que llegue a nadie.")
    finally:
        if eid:
            s.delete(f"{API}/applications/{PAQUETE}/edits/{eid}")


def cmd_promover(a):
    """Mueve la versión que ya está en un canal al siguiente, sin recompilar."""
    if a.a == "production" and not a.si_de_verdad:
        sys.exit("Producción se despliega con --si-de-verdad.")

    s = sesion()
    edit = _pedir(s, "POST", f"{API}/applications/{PAQUETE}/edits")
    eid = edit["id"]
    try:
        origen = _pedir(
            s, "GET", f"{API}/applications/{PAQUETE}/edits/{eid}/tracks/{a.de}"
        )
        versiones = origen.get("releases") or []
        if not versiones:
            sys.exit(f"«{a.de}» no tiene ninguna versión que promover.")
        v = dict(versiones[0])
        v["status"] = "completed"
        v.pop("userFraction", None)

        _pedir(
            s,
            "PUT",
            f"{API}/applications/{PAQUETE}/edits/{eid}/tracks/{a.a}",
            json={"track": a.a, "releases": [v]},
        )
        _pedir(s, "POST", f"{API}/applications/{PAQUETE}/edits/{eid}:commit")
        eid = None
        vc = ", ".join(str(x) for x in v.get("versionCodes") or [])
        print(f"v{vc}: {a.de} → {a.a}")
    finally:
        if eid:
            s.delete(f"{API}/applications/{PAQUETE}/edits/{eid}")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("estado", help="qué hay en cada canal").set_defaults(
        f=cmd_estado
    )
    sub.add_parser(
        "siguiente-version", help="versionCode libre siguiente"
    ).set_defaults(f=cmd_siguiente_version)

    s1 = sub.add_parser("subir", help="sube el AAB y crea la versión")
    s1.add_argument("--track", default="internal", choices=CANALES)
    s1.add_argument("--aab", help="ruta del .aab (por defecto el de release)")
    s1.add_argument("--notas", help="notas de la versión (es-419)")
    s1.add_argument("--nombre", help="nombre interno de la versión")
    s1.add_argument(
        "--porcentaje", type=float, help="despliegue gradual, 0-100"
    )
    s1.add_argument(
        "--borrador",
        action="store_true",
        help="prepara todo pero NO confirma: no cambia nada en Play",
    )
    s1.add_argument("--si-de-verdad", action="store_true")
    s1.set_defaults(f=cmd_subir)

    s2 = sub.add_parser("promover", help="mueve una versión entre canales")
    s2.add_argument("--de", required=True, choices=CANALES)
    s2.add_argument("--a", required=True, choices=CANALES)
    s2.add_argument("--si-de-verdad", action="store_true")
    s2.set_defaults(f=cmd_promover)

    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
