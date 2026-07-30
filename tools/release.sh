#!/usr/bin/env bash
#
# Baut ein signiertes Archiv und exportiert die .ipa für TestFlight.
#
#   tools/release.sh              # Archiv + .ipa, kein Upload
#   tools/release.sh --upload     # zusätzlich hochladen (App-Store-Connect-Key)
#   tools/release.sh --dirty      # auch mit ungespeicherten Änderungen bauen
#
# Die Build-Nummer ist die Commit-Zahl. Das ist die einzige Zahl im Projekt, die
# von allein steigt und nach einem `xcodegen generate` noch stimmt — in
# project.yml eingetragen wäre sie nach jedem Regenerieren wieder auf dem alten
# Stand, und App Store Connect nimmt dieselbe Build-Nummer kein zweites Mal an.
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

BUILD_NUMBER="$(git rev-list --count HEAD)"
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
	if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
		export_args+=(-authenticationKeyID "$ASC_KEY_ID"
			-authenticationKeyIssuerID "$ASC_ISSUER_ID"
			-authenticationKeyPath "$ASC_KEY_PATH")
	else
		echo "▸ Kein API-Schlüssel gesetzt — es gilt die in Xcode angemeldete Apple-ID."
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
