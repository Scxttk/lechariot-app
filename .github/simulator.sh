#!/usr/bin/env bash
#
# Das Gerät suchen, **bevor** `xcodebuild` danach fragt — und warten, bis es da
# ist.
#
# **Warum das nötig ist.** Auf einem frischen Runner ist der Simulator-Dienst
# beim ersten Zugriff noch nicht wach, und `xcodebuild` bekommt dann eine
# Geräteliste, die **nur Platzhalter** enthält:
#
#     Unable to find a device matching the provided destination specifier:
#         { platform:iOS Simulator, OS:26.2, name:iPhone 17 Pro }
#     Available destinations for the "LeChariot" scheme:
#         { platform:iOS Simulator, id:…SimulatorPlaceholder…, name:Any iOS Simulator Device }
#
# Kein fehlendes Gerät, sondern ein zu früher Blick: Am 10.08. lief derselbe
# Workflow auf demselben Image erst durch und beim nächsten Mal nicht. Ein
# Wettlauf, den man nicht sieht, wenn man ihn gewinnt.
#
# Der Aufruf zählt die Geräte, bis eines auftaucht, und gibt dann **die UDID**
# aus statt „Name + OS". Damit hängt der Lauf nicht mehr daran, ob `xcodebuild`
# den Namen so auflöst, wie er gemeint war.
#
# Findet sich nach allen Versuchen keines, ist das ein Befund und kein
# Rauschen — dann fehlt dem Image die Laufzeit, und der Lauf soll das laut
# sagen, statt auf ein anderes Gerät auszuweichen. Welches Gerät gemeint ist,
# ist eine Zusicherung der Suite (siehe `docs/TESTS.md`, „Das Gerät ist Teil des
# Ergebnisses").
set -euo pipefail

LAUFZEIT="${1:?Laufzeit, z. B. com.apple.CoreSimulator.SimRuntime.iOS-26-2}"
NAME="${2:?Gerätename, z. B. iPhone 17 Pro}"

for versuch in $(seq 1 12); do
	udid=$(xcrun simctl list devices available -j 2>/dev/null \
		| jq -r --arg lz "$LAUFZEIT" --arg name "$NAME" \
			'.devices[$lz]? // [] | .[] | select(.name == $name) | .udid' \
		| head -1)
	if [ -n "${udid:-}" ]; then
		echo "$udid"
		exit 0
	fi
	echo "CoreSimulator ist noch nicht so weit (Versuch $versuch)" >&2
	sleep 5
done

echo "::error::Kein „$NAME\" mit $LAUFZEIT auf diesem Runner." >&2
echo "Vorhanden ist:" >&2
xcrun simctl list devices available >&2
exit 1
