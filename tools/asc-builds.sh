#!/usr/bin/env bash
#
# Was App Store Connect über unsere Builds und Zertifikate weiß — **nur lesend**.
#
#   tools/asc-builds.sh
#
# **Warum es das gibt.** Seit dem 31.07. steht in jedem Rundenbericht derselbe
# Satz: „Ob der Build die Verarbeitung übersteht, ist von hier aus nicht
# prüfbar." Das stimmte nie — es hat nur niemand gefragt. Derselbe
# API-Schlüssel, der zum Hochladen nicht reicht, darf **lesen**: Am 03.08. hat
# dieser Aufruf in einem Zug bestätigt, dass alle acht bis dahin unbestätigten
# Builds `VALID` sind, `2026.0803.1440` eingeschlossen.
#
# **Merksatz: „von hier aus nicht prüfbar" ist eine Behauptung über das
# Werkzeug, nicht über die Welt — und sie gehört geprüft wie jede andere.**
#
# Der zweite Abschnitt beantwortet die Frage, an der der Upload hängt: Welche
# Zertifikate hat das Konto? Am 03.08. war die Antwort **kein einziges
# Vertriebszertifikat** — nur zwei Entwicklungs- und ein Developer-ID-Zertifikat.
# Das ist kein verlorenes Zertifikat, das ist ein nie ausgestelltes; deshalb ist
# der Haken „Zugriff auf cloud-verwaltete Vertriebszertifikate" beim Schlüssel
# der eigentliche Weg und keine Abkürzung.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "✗ $*" >&2; exit 1; }

[ -f ~/.config/lechariot/asc-env ] || fail "~/.config/lechariot/asc-env fehlt — siehe docs/RELEASE.md."
# shellcheck disable=SC1090
source ~/.config/lechariot/asc-env
KEY="$(ls ~/.appstoreconnect/private_keys/AuthKey_*.p8 2>/dev/null | head -1)"
[ -n "$KEY" ] || fail "Kein AuthKey_*.p8 in ~/.appstoreconnect/private_keys/."
KID="$(basename "$KEY" | sed 's/AuthKey_//; s/\.p8//')"
[ -n "${ASC_ISSUER_ID:-}" ] || fail "ASC_ISSUER_ID ist nicht gesetzt."

python3 - "$KEY" "$KID" "$ASC_ISSUER_ID" <<'PY'
import sys, time, json, base64, subprocess, tempfile, os, urllib.request, urllib.error

key_path, kid, issuer = sys.argv[1], sys.argv[2], sys.argv[3]


def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def token():
    """ES256-JWT ohne PyJWT — openssl liefert DER, die API will r||s."""
    head = b64(json.dumps({"alg": "ES256", "kid": kid, "typ": "JWT"}, separators=(",", ":")).encode())
    now = int(time.time())
    body = b64(json.dumps(
        {"iss": issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        separators=(",", ":")).encode())
    signing_input = head + b"." + body
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(signing_input)
        tmp = f.name
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path, tmp],
                         capture_output=True, check=True).stdout
    os.unlink(tmp)
    i = 2 if der[1] < 0x80 else 3
    parts = []
    for _ in range(2):
        length = der[i + 1]
        parts.append(der[i + 2:i + 2 + length].lstrip(b"\x00").rjust(32, b"\x00"))
        i += 2 + length
    return (signing_input + b"." + b64(b"".join(parts))).decode()


BEARER = token()


def get(path):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/" + path,
                                 headers={"Authorization": "Bearer " + BEARER})
    try:
        return json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as e:
        return {"fehler": f"HTTP {e.code}", "text": e.read().decode()[:300]}
    except Exception as e:  # Netz weg, Zeitüberschreitung
        return {"fehler": str(e)}


builds = get("builds?limit=10&sort=-uploadedDate"
             "&fields[builds]=version,uploadedDate,processingState,expired")
print("=== Builds in App Store Connect (neueste zuerst) ===")
if "data" in builds:
    for entry in builds["data"] or []:
        a = entry["attributes"]
        print(f"  {a.get('version', '?'):16s} {a.get('processingState', '?'):12s} "
              f"{(a.get('uploadedDate') or '?')[:19]}  abgelaufen={a.get('expired')}")
    if not builds["data"]:
        print("  (keine)")
else:
    print(" ", builds)

certs = get("certificates?limit=200")
print("\n=== Zertifikate im Entwicklerkonto ===")
if "data" in certs:
    for entry in certs["data"] or []:
        a = entry["attributes"]
        print(f"  {a.get('certificateType', '?'):26s} {a.get('displayName', '?'):40s} "
              f"laeuft ab {(a.get('expirationDate') or '?')[:10]}")
    arten = {e["attributes"].get("certificateType") for e in certs["data"] or []}
    if not ({"DISTRIBUTION", "IOS_DISTRIBUTION"} & arten):
        print("\n  ⚠ Kein Vertriebszertifikat. Ohne eines kann `exportArchive` nicht")
        print("    signieren — weder lokal noch ueber den API-Schluessel, solange bei")
        print("    ihm „Zugriff auf cloud-verwaltete Vertriebszertifikate\" fehlt.")
else:
    print(" ", certs)
PY
