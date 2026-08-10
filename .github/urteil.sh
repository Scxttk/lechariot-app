#!/usr/bin/env bash
#
# Das Urteil über einen Suite-Lauf — aus den Befunden der Scherben, nicht aus
# ihren Ampeln.
#
# Als eigene Datei und nicht als `run:`-Block im Workflow, weil sie die einzige
# Stelle ist, an der „grün" definiert wird. In YAML eingerückt liest das
# niemand, und ändern lässt es sich ohne einen Lauf nicht ausprobieren.
#
# Rot ist ein Lauf, wenn eines davon zutrifft:
#
#   1. Ein Test ist gefallen und im zweiten Anlauf nicht wieder aufgestanden.
#   2. Eine Klasse aus dem Quellbaum hat keinen einzigen Test gemeldet. Das
#      fängt beides: den ausgefallenen Arbeiter (am 08.08. lokal
#      stillschweigend durchgegangen, 138 statt 139 Journeys) und die ganze
#      Scherbe, deren Job gestorben ist und die gar keinen Befund abgeliefert
#      hat. Der Sollwert kommt aus `tools/testlauf.sh soll`, also aus demselben
#      Quellbaum wie die Tests — nicht aus den Befunden, sonst prüfte sich der
#      fehlende Befund selbst.
#
# Alles andere — ein Runner, der beim Klon-Start stolpert, ein Durchgang, der
# Fehlschlag meldet, ohne dass eine Zusicherung gefallen ist — wird gemeldet
# und nicht bestraft. Siehe `docs/TESTS.md`.
set -uo pipefail

# Alles doppelt: einmal ins Protokoll, einmal in die Zusammenfassung des Laufs.
# Wer eine rote Ampel sieht, soll den Befund sehen, ohne ein Job-Protokoll
# aufzuklappen.
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && exec > >(tee -a "$GITHUB_STEP_SUMMARY")

berichte=(bericht-*.txt)
[ -e "${berichte[0]}" ] || { echo "::error::Kein einziger Befund angekommen."; exit 1; }

wert() { sed -n "s/^$2=//p" "$1"; }

fehler=0
gesamt_gelaufen=0
alle_rot=""
alle_wackelig=""
gemeldete_klassen=""
laengste=0

echo "## Suite"
echo
echo "| Scherbe | Tests | Wanduhr | rot | wackelig |"
echo "|---|---|---|---|---|"

for b in $(printf '%s\n' "${berichte[@]}" | sort); do
	nr=$(wert "$b" scherbe)
	gelaufen=$(wert "$b" gelaufen)
	sek=$(wert "$b" sekunden)
	rot=$(wert "$b" rot)
	wackelig=$(wert "$b" wackelig)
	klassen=$(wert "$b" klassen)

	gesamt_gelaufen=$((gesamt_gelaufen + ${gelaufen:-0}))
	[ "${sek:-0}" -gt "$laengste" ] && laengste=${sek:-0}
	alle_rot="$alle_rot $rot"
	alle_wackelig="$alle_wackelig $wackelig"
	gemeldete_klassen="$gemeldete_klassen $klassen"

	printf '| %s | %s | %d:%02d | %s | %s |\n' "$nr" "$gelaufen" \
		$((sek / 60)) $((sek % 60)) \
		"$([ -n "$rot" ] && echo "$rot" || echo '–')" \
		"$([ -n "$wackelig" ] && echo "$wackelig" || echo '–')"
done
echo

# 1. Gefallen und nicht wieder aufgestanden.
rote=$(echo "$alle_rot" | tr ' ' '\n' | grep -v '^$' | sort -u)
if [ -n "$rote" ]; then
	echo "**Rot** — diese Tests sind gefallen und im zweiten Anlauf nicht wieder aufgestanden:"
	echo
	echo "$rote" | sed 's/^/- `/; s/$/`/'
	echo
	fehler=1
fi

# 2. Hat jede Klasse, die es im Baum gibt, auch einen Test gemeldet?
#
# Verglichen wird der kurze Klassenname: der Sollwert trägt `Ziel/Klasse`, das
# Protokoll nur `Klasse`.
fehlend=""
for z in $(tools/testlauf.sh soll); do
	kurz=${z##*/}
	case " $gemeldete_klassen " in
		*" $kurz "*) ;;
		*) fehlend="$fehlend $kurz" ;;
	esac
done
if [ -n "$fehlend" ]; then
	echo "**Rot** — diese Klassen stehen im Quellbaum und haben keinen einzigen"
	echo "Test gemeldet:"
	echo
	for k in $fehlend; do echo "- \`$k\`"; done
	echo
	echo "Das ist kein Simulator-Rauschen. Entweder ist ein Arbeiter ausgefallen und"
	echo "seine Klassen sind ungeprüft durchgegangen, oder eine ganze Scherbe hat"
	echo "keinen Befund abgeliefert."
	echo
	fehler=1
fi

# Gemeldet, nicht bestraft.
wackler=$(echo "$alle_wackelig" | tr ' ' '\n' | grep -v '^$' | sort -u)
if [ -n "$wackler" ]; then
	echo "**Erst im zweiten Anlauf grün** — diese Journeys wackeln:"
	echo
	echo "$wackler" | sed 's/^/- `/; s/$/`/'
	echo
	echo "Wer hier öfter auftaucht, gehört repariert. Siehe \`docs/TESTS.md\`."
	echo
fi

bauzeit=$(sed -n 's/^bauen_sekunden=//p' bauzeit.txt 2>/dev/null || echo 0)
printf '**%d Tests gelaufen.** Bauen %d:%02d, längste Scherbe %d:%02d.\n\n' \
	"$gesamt_gelaufen" $((bauzeit / 60)) $((bauzeit % 60)) \
	$((laengste / 60)) $((laengste % 60))

if [ "$fehler" -eq 0 ]; then
	echo "✓ Kein Test ist gefallen, und jede zugeteilte Klasse hat gemeldet."
fi

# **Beratend oder sperrend.** Solange `GATE=0` ist, sagt dieser Lauf, was er
# gefunden hat, und lässt den PR durch. Das ist kein Nachlassen, sondern die
# Reihenfolge: Eine Ampel, die öfter grundlos rot ist als der lokale Lauf,
# erzieht dazu, rote Ampeln zu überblättern — und dann fängt sie auch den
# echten Fehler nicht mehr.
if [ "$fehler" -ne 0 ] && [ "${GATE:-0}" = "0" ]; then
	echo
	echo "_Beratend: Dieser Lauf sperrt den PR (noch) nicht._"
	fehler=0
fi

exit "$fehler"
