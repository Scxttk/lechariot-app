#!/usr/bin/env bash
#
# Baut ein signiertes Archiv und exportiert die .ipa für TestFlight.
#
#   tools/release.sh              # Archiv + .ipa, kein Upload
#   tools/release.sh --upload     # zusätzlich hochladen (App-Store-Connect-Key)
#   tools/release.sh --dirty      # auch mit ungespeicherten Änderungen bauen
#
# Die Build-Nummer ist ein UTC-Zeitstempel, `JJJJ.MMTT.hhmm`.
#
# Vorher war es die Commit-Zahl, und das ging genau einmal gut. Ein
# Squash-Merge fasst dreizehn Commits zu einem zusammen: Die Zahl fiel von 85
# auf 76, also **rückwärts**, und App Store Connect verlangt für dieselbe
# Version eine steigende Build-Nummer. Dasselbe passiert bei jedem Rebase, der
# Commits zusammenfasst. Ein Zeitstempel kann das nicht — er steigt, egal was
# mit der Historie geschieht.
#
# Drei Bestandteile statt einer zwölfstelligen Zahl, damit jeder Teil unter
# 10000 bleibt; welcher Stand gebaut wurde, sagt der Commit-Hash in der
# Ausgabe unten und der Git-Verlauf.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS="$REPO/ios"
BUILD="$REPO/build"
ARCHIVE="$BUILD/LeChariot.xcarchive"
EXPORT="$BUILD/export"

upload=0
allow_dirty=0
for arg in "$@"; do
	case "$arg" in
		--upload) upload=1 ;;
		--dirty) allow_dirty=1 ;;
		*) echo "Unbekanntes Argument: $arg" >&2; exit 2 ;;
	esac
done

fail() { echo "✗ $*" >&2; exit 1; }

# Sucht den App-Store-Connect-API-Schlüssel, wenn er nicht schon in der
# Umgebung steht.
#
# **Warum überhaupt:** Bis zum 02.08. hing der Upload allein an der in Xcode
# angemeldeten Apple-ID. Das Xcode-Update auf 26.3 hat die Anmeldung entfernt
# und mit ihr das Verteilungs-Zertifikat — der Lauf brach mit „No Accounts" ab,
# und wiederherstellen konnte das nur der Mensch mit dem Passwort. Ein
# API-Schlüssel liegt als Datei da und überlebt jedes Update.
#
# Gesucht wird nur, was ohnehin eindeutig ist: **genau eine** `AuthKey_*.p8`
# unter `~/.appstoreconnect/private_keys` (der Ort, an dem auch `altool` und
# `xcodebuild` von sich aus nachsehen). Die Schlüssel-ID steht im Dateinamen,
# das ist Apples eigene Namensregel. Liegen mehrere Schlüssel da, wird geraten
# statt gefunden — dann bleibt es bei der Umgebung, mit einem Hinweis.
#
# Die Issuer-ID steht in `~/.config/lechariot/asc-env`, denn sie steht nirgends
# in der Datei. Kein Geheimnis (eine Team-UUID), aber auch nichts, was sich
# ableiten ließe.
find_asc_key() {
	[ -z "${ASC_KEY_PATH:-}" ] || return 0

	local env_file="$HOME/.config/lechariot/asc-env"
	# shellcheck source=/dev/null
	[ -f "$env_file" ] && . "$env_file"

	local dir="$HOME/.appstoreconnect/private_keys"
	[ -d "$dir" ] || return 0
	local keys=("$dir"/AuthKey_*.p8)
	[ -e "${keys[0]}" ] || return 0
	if [ "${#keys[@]}" -gt 1 ]; then
		echo "▸ Mehrere API-Schlüssel in $dir — keiner wird geraten." >&2
		return 0
	fi

	ASC_KEY_PATH="${keys[0]}"
	local base="${ASC_KEY_PATH##*/}"
	base="${base#AuthKey_}"
	ASC_KEY_ID="${base%.p8}"
	export ASC_KEY_PATH ASC_KEY_ID

	if [ -z "${ASC_ISSUER_ID:-}" ]; then
		echo "▸ Schlüssel $ASC_KEY_ID gefunden, aber ASC_ISSUER_ID fehlt." >&2
		echo "  Sie steht in App Store Connect über der Schlüsselliste und gehört nach" >&2
		echo "  $env_file als: export ASC_ISSUER_ID=…" >&2
		ASC_KEY_PATH=""
		ASC_KEY_ID=""
	fi
}

# ---- Vorbedingungen

cd "$REPO"

if [ "$allow_dirty" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
	fail "Arbeitsverzeichnis ist nicht sauber. Die Build-Nummer kommt aus der
  Commit-Zahl und würde sonst Code bezeichnen, den es nirgends gibt.
  Committen — oder bewusst mit --dirty bauen."
fi

# Ohne echte Schlüssel fällt APIConfig.isConfigured auf false und die App zeigt
# Mock-Angebote. Das würde niemand am Gerät als Fehler erkennen, deshalb ist es
# hier ein Abbruch und keine Warnung.
KEYS="$IOS/LeChariot/Resources/APIKeys.plist"
[ -f "$KEYS" ] || fail "$KEYS fehlt. APIKeys.example.plist kopieren und ausfüllen."
for key in SupabaseURL SupabaseKey; do
	value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$KEYS" 2>/dev/null || true)"
	case "$value" in
		""|*DEIN*|*YOUR*|*xxx*|*XXX*) fail "APIKeys.plist: $key ist nicht ausgefüllt ($value)." ;;
	esac
done

command -v xcodegen >/dev/null || fail "xcodegen fehlt: brew install xcodegen"

BUILD_NUMBER="$(date -u +%Y.%m%d.%H%M)"
VERSION="$(grep -m1 'MARKETING_VERSION:' "$IOS/project.yml" | awk '{print $2}')"
echo "▸ Le Chariot $VERSION (Build $BUILD_NUMBER) — $(git rev-parse --short HEAD)"

# ---- Bauen

rm -rf "$ARCHIVE" "$EXPORT"
mkdir -p "$BUILD"

(cd "$IOS" && xcodegen generate)

xcodebuild archive \
	-project "$IOS/LeChariot.xcodeproj" \
	-scheme LeChariot \
	-configuration Release \
	-destination 'generic/platform=iOS' \
	-archivePath "$ARCHIVE" \
	-allowProvisioningUpdates \
	CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

# Gegenprobe am fertigen Bundle, nicht am Projekt: das Privacy-Manifest muss im
# Bundle-Wurzelverzeichnis liegen, sonst weist App Store Connect den Upload ab.
APP="$ARCHIVE/Products/Applications/LeChariot.app"
[ -f "$APP/PrivacyInfo.xcprivacy" ] || fail "PrivacyInfo.xcprivacy fehlt im Bundle."

OPTIONS="$IOS/ExportOptions.plist"
export_args=(-exportArchive
	-archivePath "$ARCHIVE"
	-exportPath "$EXPORT"
	-allowProvisioningUpdates)

# Am eigenen Mac reicht die Apple-ID, die in Xcode angemeldet ist — am
# 2026-07-30 nachgefahren: Anmeldung und Team-Auflösung liefen damit durch, der
# Lauf brach erst am fehlenden App-Eintrag ab. Ein API-Schlüssel ist nur nötig,
# wo niemand angemeldet ist (CI). Sind die drei ASC_-Variablen gesetzt, werden
# sie benutzt; sonst nicht, statt den Lauf daran scheitern zu lassen.
#
# Die Export-Optionen werden dafür kopiert statt geändert: `destination: upload`
# im Repo hieße, dass ein versehentlicher Lauf ohne Argument gleich hochlädt.
if [ "$upload" -eq 1 ]; then
	OPTIONS="$BUILD/ExportOptions-upload.plist"
	cp "$IOS/ExportOptions.plist" "$OPTIONS"
	/usr/libexec/PlistBuddy -c "Set :destination upload" "$OPTIONS"
	find_asc_key
	if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
		echo "▸ API-Schlüssel $ASC_KEY_ID — unabhängig von der Xcode-Anmeldung."
		export_args+=(-authenticationKeyID "$ASC_KEY_ID"
			-authenticationKeyIssuerID "$ASC_ISSUER_ID"
			-authenticationKeyPath "$ASC_KEY_PATH")
	else
		echo "▸ Kein API-Schlüssel gefunden — es gilt die in Xcode angemeldete Apple-ID."
		echo "  Am 02.08. war genau das der Blocker: Nach dem Xcode-Update auf 26.3"
		echo "  war keine Apple-ID mehr angemeldet und das Verteilungs-Zertifikat weg."
		echo "  Einrichten: docs/RELEASE.md, Abschnitt API-Schlüssel."
	fi
fi

xcodebuild "${export_args[@]}" -exportOptionsPlist "$OPTIONS"

echo
if [ "$upload" -eq 1 ]; then
	echo "✓ Build $BUILD_NUMBER hochgeladen. Die Verarbeitung in App Store Connect"
	echo "  dauert ein paar Minuten, danach steht der Build unter TestFlight."
else
	echo "✓ $EXPORT/LeChariot.ipa"
	echo "  Hochladen: Xcode → Organizer → Distribute App, oder tools/release.sh --upload"
fi
