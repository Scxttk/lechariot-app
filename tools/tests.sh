#!/usr/bin/env bash
#
# Die Suite laufen lassen — parallel, wo es geht.
#
#   tools/tests.sh                          # alles: Unit + UI
#   tools/tests.sh AddFlowJourneyTests      # nur diese Klassen (beim Arbeiten)
#   tools/tests.sh --unit                   # nur die Unit-Tests (~25 s)
#   tools/tests.sh --workers 2              # weniger Klone, wenn der Mac zu tun hat
#   tools/tests.sh RundgangShots --result /tmp/bogen.xcresult   # mit Bildern
#
# **Warum ein Skript und nicht `xcodebuild test`.** Auf der Kommandozeile lässt
# sich nicht in *einem* Lauf sagen „verteile auf Klone, aber diese eine Klasse
# nicht" — und genau das kostet sonst Stunden.
#
# `-parallel-testing-enabled YES` verteilt die Testklassen auf Simulator-Klone.
# Das ist der ganze Hebel: Die Suite ist ein Rudel unabhängiger App-Starts, und
# ein einzelner Simulator lastet diesen Mac nicht aus. Das Messgeschirr darf
# aber nicht mitfahren — es vergleicht CPU-Zahlen gegen Grundwerte aus dem
# Leerlauf (siehe `SERIELL` unten).
#
# **Und warum `build-for-testing` getrennt.** Zwei Läufe, ein Bau. Ohne die
# Trennung baut der zweite Durchgang alles noch einmal.
#
# Die Politik dazu — wann welcher Lauf dran ist — steht in `docs/TESTS.md`.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS="$REPO/ios"
DERIVED="${LECHARIOT_DERIVED_DATA:-$REPO/build/tests-dd}"
DESTINATION="${LECHARIOT_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"
# Die Zahl der Klone. Vorgabe passend zu diesem Mac (M1, 8 Kerne, 16 GB).
# Auf einer größeren Maschine ist sie anzuheben; die Untergrenze eines Laufs
# bleibt trotzdem die längste einzelne Testklasse (siehe `docs/TESTS.md`).
WORKERS="${LECHARIOT_TEST_WORKERS:-3}"

# Die Klassen, die **allein auf einer ruhigen Maschine** laufen müssen.
#
# Nur eine: `PerformanceJourneyTests` misst CPU und Speicher der App und
# vergleicht gegen `tools/perf-baseline.json` — Grundwerte von diesem Mac im
# Leerlauf. Neben zwei weiteren Simulatoren gemessen wären sie eine Aussage
# über die Auslastung und über nichts sonst.
#
# Der Rundgang (`TutorialJourneyTests`, `TourTargetJourneyTests`) gehört
# ausdrücklich **nicht** hierher, obwohl er Zeiten benutzt: Er misst Geometrie
# — wo das wandernde Loch nach dem Einschwingen liegt —, und die hängt nicht an
# der Auslastung. Seine Schonfristen sind `Thread.sleep`, also Wanduhr, und die
# läuft auf einem Klon genauso.
#
# Wer hier etwas einträgt, sagt damit „das kostet Wanduhr, seriell" — die Liste
# ist absichtlich kurz zu halten.
# Und eine, die unter Last nicht langsamer wird, sondern **umkippt**:
# `TermGridJourneyTests.testNothingMovesUnderTheThumbWhileTyping` zählt je
# Buchstabe alle Knöpfe mit `buttons.matching(…).count`. `.count` muss jeden
# Treffer wirklich holen, also den ganzen Barrierefreiheits-Baum über den
# Prozess hinweg — fünfmal, bei stehender Tastatur. Allein gemessen 9,4 s,
# neben zwei Klonen **552,5 s**. Die beiden Nachbartests derselben Klasse auf
# demselben Klon blieben bei 11 s und 12 s; es ist also die Abfrage und nicht
# der Klon.
#
# Serialisiert statt umgeschrieben: Die Zählung ist der Beweis, dass die Probe
# überhaupt etwas beweist („die Trefferzahl muss sich unterwegs geändert
# haben"). Wer sie billiger macht, muss erst zeigen, dass sie dasselbe prüft —
# das ist eine eigene Aufgabe, keine Nebenwirkung dieser.
# Und eine dritte, die denselben Befund trägt wie `TermGridJourneyTests`, nur
# aus der anderen Richtung: `TileGestureJourneyTests`
# (`testATapChecksTheItemWithoutWaitingForALongPress`) prüft, dass ein **kurzer**
# Tipp abhakt, ohne auf den langen Druck zu warten — also eine Frist zwischen
# zwei Gesten. Auf drei Klonen fiel der Test am 09.08. **zweimal von zwei**
# Versuchen, allein auf einem Simulator ist er grün. Eine Zusicherung über
# Gestendauer misst unter Last die Last.
SERIELL=(
	LeChariotUITests/PerformanceJourneyTests
	LeChariotUITests/TermGridJourneyTests
	LeChariotUITests/TileGestureJourneyTests
)

only=()
unit_only=0
# Wohin das Ergebnisbündel geht. Leer heisst: keins — der Normalfall, denn ein
# Bündel je Lauf kostet Platte und wird nie gelesen. Gebraucht wird es von den
# Bilderbögen (`RundgangShots`, `BedienrundeShots`): Sie hängen ihre PNGs ans
# Ergebnis, und ohne Bündel gibt es nichts, woraus man sie holen könnte.
RESULT=""
while [ $# -gt 0 ]; do
	case "$1" in
		--unit) unit_only=1; shift ;;
		--workers) WORKERS="$2"; shift 2 ;;
		--destination) DESTINATION="$2"; shift 2 ;;
		--result) RESULT="$2"; shift 2 ;;
		-h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
		# Ein blosser Klassenname reicht; das Ziel davor ist geraten, wenn es
		# fehlt, damit `tools/tests.sh AddFlowJourneyTests` tut, was es sagt.
		*) case "$1" in
			*/*) only+=("$1") ;;
			*Journey*|*Audit*) only+=("LeChariotUITests/$1") ;;
			*) only+=("LeChariotTests/$1") ;;
		   esac
		   shift ;;
	esac
done

# **Nicht zwei Läufe gleichzeitig.** Der Checkout ist geteilt, und zwei
# Sitzungen, die beide Klone hochfahren, sind nicht nur langsamer — der zweite
# Lauf bekommt beim Start
#
#     Simulator device failed to launch …xctrunner
#     … denied … for reason: Busy ("Application failed preflight checks")
#
# und verliert den ganzen Arbeiter samt seiner Klassen. Am 08.08. hat das einen
# Lauf von 27 auf 34 Minuten gebracht und ihn rot gemeldet, ohne dass ein
# einziger Test etwas dagegen hatte.
if pgrep -qf "[x]codebuild.*test"; then
	echo "✗ Auf dieser Maschine läuft schon ein Testlauf." >&2
	echo "  pgrep -fl xcodebuild — warten oder den anderen Lauf beenden." >&2
	exit 3
fi

# Klone eines abgebrochenen Laufs stehen sonst noch da und halten den
# Simulator-Dienst beschäftigt. **Nur Xcodes eigenes Klon-Verzeichnis** — die
# Simulatoren, die im Simulator.app stehen, gehören dem Menschen und werden
# hier nicht angefasst.
KLONE="$HOME/Library/Developer/XCTestDevices"
if [ -d "$KLONE" ]; then
	xcrun simctl --set "$KLONE" shutdown all >/dev/null 2>&1 || true
	xcrun simctl --set "$KLONE" delete all   >/dev/null 2>&1 || true
fi

# Wer misst, während die Maschine etwas anderes tut, misst die Maschine — und
# unter Last fallen Journeys mit „Timed out while synthesizing event" um, also
# gar nicht an einer Zusicherung. Dieselbe Warnung wie in `tools/perf.sh`.
noisy="$(ps -Ao pcpu,comm -r | awk 'NR>1 && $1>15 {print "    " $0}' | head -5)"
if [ -n "$noisy" ]; then
	echo "⚠ Diese Prozesse nehmen gerade über 15 % CPU:"
	echo "$noisy"
	echo "  Parallele Klone auf einer belegten Maschine wackeln. --workers 2 hilft."
fi

start=$SECONDS
echo "▸ Bauen ($DERIVED)"
xcodebuild build-for-testing \
	-project "$IOS/LeChariot.xcodeproj" -scheme LeChariot \
	-destination "$DESTINATION" -derivedDataPath "$DERIVED" -quiet

xctestrun="$(ls -t "$DERIVED"/Build/Products/*.xctestrun | head -1)"

protokoll="$(mktemp)"
trap 'rm -f "$protokoll"' EXIT

# Die Testnamen aus einem Protokoll ziehen — beide Schreibweisen: parallel
# meldet „Test case 'Klasse.test()' passed on 'Clone N …'", seriell
# „Test Case '-[Ziel.Klasse test]' passed".
namen_mit_ausgang() {   # $1 = Protokoll, $2 = passed|failed
	grep -oE "Test case '[A-Za-z0-9_]+\.[A-Za-z0-9_]+\(\)' $2|Test Case '-\[[A-Za-z0-9_.]+ [A-Za-z0-9_]+\]' $2" "$1" 2>/dev/null \
		| sed -E "s/Test [Cc]ase '(-\[)?//; s/(\]|\(\))?' $2\$//; s/ /./" | sort -u
}

# Gefallen **und** nicht danach doch noch durchgekommen.
namen_endgueltig_rot() {
	comm -23 <(namen_mit_ausgang "$1" failed) <(namen_mit_ausgang "$1" passed)
}

# Gefallen, aber im zweiten Anlauf grün — die Wackelkandidaten.
namen_wackelig() {
	comm -12 <(namen_mit_ausgang "$1" failed) <(namen_mit_ausgang "$1" passed)
}

# **Ein roter Lauf ist nicht dasselbe wie ein roter Test.** `xcodebuild` meldet
# auch dann Fehlschlag, wenn gar keine Zusicherung gefallen ist — ein Klon, der
# seinen Runner nicht starten konnte, reicht. Am 08.08. sind so zwei Läufe rot
# geworden, beide bei **null** roten Tests, und beide Male ist die erste Frage
# „was ist an der App kaputt?" die falsche gewesen.
#
# Deshalb sagt der Lauf hier selbst, welche der beiden Sorten er war.
lauf() {
	local titel="$1"; shift
	echo "▸ $titel"
	# **Ein hängender Test muss scheitern, nicht warten.** In der Nacht zum
	# 09.08. blieb `PerformanceJourneyTests` im seriellen Durchgang stehen und
	# drehte **7,2 Stunden** in „Wait for com.skoehler.lechariot to idle"
	# (`t = 25921s`) — die Maschine war wach, der Simulator war hin. Ohne Deckel
	# kostet so etwas eine Nacht und hinterlässt kein Ergebnis. Zehn Minuten
	# sind grosszügig: Der längste echte Test der Suite braucht 99 s.
	# **Ein wackelnder Test darf den Lauf nicht rot machen, aber er muss
	# auffallen.** Gemessen am 08./09.08.: In vier vollen Läufen fiel je genau
	# ein Test um, jedes Mal ein anderer — `AddFlowJourneyTests`,
	# `OfferHitsJourneyTests`, `ItemDetailJourneyTests` —, und jeder war allein
	# nachgestellt grün (`OfferHits` dreimal). **Auch der serielle Grundlauf
	# hatte einen.** Bei rund 790 Tests je Lauf ist „zweimal hintereinander
	# null Rot" damit reine Würfelei, mit Klonen wie ohne.
	#
	# `-retry-tests-on-failure` lässt genau die gefallenen Tests noch einmal
	# laufen. Das ist **kein** Wegsehen: Wer beim zweiten Versuch durchkommt,
	# steht am Ende des Laufs namentlich in der Zusammenfassung, und wer
	# zweimal fällt, bleibt rot. Ein Test, der regelmässig in dieser Liste
	# steht, gehört repariert — die Liste ist der Auftrag dazu.
	# Wo dieser Durchgang im Protokoll anfängt — der Freispruch unten darf nur
	# das beurteilen, was **hier** gelaufen ist.
	local ab
	ab=$(( $(wc -l < "$protokoll") + 1 ))

	local bundle=()
	# Je Durchgang ein eigener Pfad: Zwei Durchgänge auf dasselbe Bündel
	# schreiben lassen bricht den zweiten ab („already exists").
	[ -n "$RESULT" ] && bundle=(-resultBundlePath "$RESULT")
	# `${a[@]+"${a[@]}"}` und nicht `"${a[@]}"`: Unter `set -u` hält die Bash 3.2
	# dieses Macs eine **leere** Array-Entfaltung für eine unbelegte Variable und
	# bricht ab — also genau im Normalfall ohne `--result`.

	xcodebuild test-without-building \
		-test-timeouts-enabled YES \
		-maximum-test-execution-time-allowance 600 \
		-retry-tests-on-failure -test-iterations 2 \
		${bundle[@]+"${bundle[@]}"} \
		-xctestrun "$xctestrun" -destination "$DESTINATION" "$@" 2>&1 | tee -a "$protokoll"
	local code=${PIPESTATUS[0]}
	if [ "$code" -ne 0 ]; then
		# **Erst die Frage, ob überhaupt etwas gelaufen ist.** Ein Durchgang, der
		# gar nicht erst startet, hat null gefallene Tests — und wäre nach der
		# Regel darunter „grün". Am 09.08. genau so passiert: Der serielle
		# Durchgang scheiterte am Gerät (`Invalid connectionUUID`), keine der
		# drei Klassen lief, und der Lauf meldete grün. Null gelaufene Tests
		# sind kein Freispruch, sondern der eindeutigste Fehlschlag von allen.
		local gelaufen_hier
		gelaufen_hier=$(sed -n "${ab},\$p" "$protokoll" \
			| grep -cE "Test case '.*' (passed|failed) on |^Test Case .*(passed|failed) \(" || true)
		if [ "$gelaufen_hier" -eq 0 ]; then
			echo "✗ In diesem Durchgang ist **kein einziger Test gelaufen**."
			echo "  Das ist kein Simulator-Rauschen, das ist ein Ausfall."
			return 1
		fi
		# **„Einmal gefallen" ist nicht „rot".** Seit `-retry-tests-on-failure`
		# läuft ein gefallener Test noch einmal; kommt er durch, steht im
		# Protokoll beides — eine `failed`- und eine `passed`-Zeile für
		# denselben Namen. Wer nur die `failed`-Zeilen zählt, meldet einen
		# grünen Lauf als rot (am 09.08. genau einmal passiert).
		#
		# Endgültig rot ist also: gefallen **und** nicht danach durchgekommen.
		local rote
		rote=$(namen_endgueltig_rot "$protokoll" | wc -l | tr -d ' ')
		if [ "$rote" -eq 0 ]; then
			# **Der Rückgabewert von `xcodebuild` taugt hier nicht als Urteil.**
			# Gemessen am 09.08.: Ein Durchgang lief alle 139 Journeys durch,
			# null gefallen — und meldete trotzdem Fehlschlag, weil *ein*
			# Test-Runner beim Klon-Start stolperte. Wiederholt lief er noch
			# einmal alle 139 durch, null gefallen, und meldete wieder
			# Fehlschlag. Der Wiederholungslauf hat zwanzig Minuten gekostet
			# und nichts geklärt; deshalb wird hier **nicht** mehr wiederholt.
			#
			# Geurteilt wird nach dem, was nachweislich stimmt: **Ist ein Test
			# gefallen?** Der Rest ist Simulator-Rauschen und wird gemeldet,
			# nicht bestraft. Die Gegenprobe dazu — „sind auch alle Tests
			# gelaufen?" — steht am Ende des Skripts.
			echo "⚠ Durchgang rot gemeldet, aber **kein einziger Test** ist"
			echo "  gefallen — das ist der Simulator, nicht die App."
			echo "  Siehe docs/TESTS.md. Der Lauf zählt trotzdem als grün,"
			echo "  sofern unten die Zahl der gelaufenen Tests stimmt."
			return 0
		fi
	fi
	return "$code"
}

fehler=0

if [ ${#only[@]} -gt 0 ]; then
	# Beim Arbeiten: was genannt wurde, sonst nichts. Parallel, weil auch drei
	# Klassen auf drei Klonen schneller fertig sind als hintereinander.
	args=(-parallel-testing-enabled YES -parallel-testing-worker-count "$WORKERS")
	for t in "${only[@]}"; do args+=(-only-testing:"$t"); done
	lauf "Ausgewählt: ${only[*]}" "${args[@]}" || fehler=1
else
	args=(-parallel-testing-enabled YES -parallel-testing-worker-count "$WORKERS")
	[ "$unit_only" -eq 1 ] && args+=(-only-testing:LeChariotTests)
	for t in "${SERIELL[@]}"; do args+=(-skip-testing:"$t"); done
	lauf "Parallel ($WORKERS Klone)" "${args[@]}" || fehler=1

	if [ "$unit_only" -eq 0 ]; then
		args=(-parallel-testing-enabled NO)
		for t in "${SERIELL[@]}"; do args+=(-only-testing:"$t"); done
		lauf "Seriell, ruhige Maschine (${#SERIELL[@]} Klasse)" "${args[@]}" || fehler=1
	fi
fi

# **Die Gegenprobe zum Freispruch oben: sind auch alle Tests gelaufen?**
#
# Ein Durchgang, der rot meldet und keinen roten Test hat, ist harmlos — solange
# nicht in Wahrheit ein Arbeiter samt seiner Klassen ausgefallen ist. Genau das
# ist am 08.08. einmal passiert (138 statt 139 Journeys, stillschweigend).
#
# Verglichen wird gegen den letzten Lauf auf dieser Maschine. Kein Sollwert im
# Repo: Der veraltet beim ersten neuen Test und wäre dann ein Wächter, dem
# niemand mehr glaubt. Ein Rückgang ist ein Befund, ein Zuwachs ist der
# Normalfall.
# **Namen zählen, nicht Zeilen.** Mit `-retry-tests-on-failure` schreibt ein
# wackliger Test zwei Zeilen, und dann meldete dieser Wächter beim nächsten,
# ruhigeren Lauf „ein Test fehlt" — am 09.08. genau so passiert: 824 gegen 823
# bei zweimal denselben 823 Journeys.
gelaufen=$(grep -oE "Test case '[A-Za-z0-9_]+\.[A-Za-z0-9_]+\(\)'|Test Case '-\[[A-Za-z0-9_.]+ [A-Za-z0-9_]+\]'" \
	"$protokoll" | sort -u | wc -l | tr -d ' ')
merker="$DERIVED/.letzte-testzahl"
vorher=$(cat "$merker" 2>/dev/null || echo 0)
if [ "$vorher" -gt 0 ] && [ "$gelaufen" -lt "$vorher" ]; then
	echo "✗ Es sind $gelaufen Tests gelaufen, beim letzten Mal $vorher."
	echo "  Ein Arbeiter ist vermutlich ausgefallen — das ist KEIN grüner Lauf."
	fehler=1
fi
# Als `if` und nicht als `[ … ] && echo …`, weil hier der Normalfall „gleich
# viele Tests wie beim letzten Mal" ist und die Absicht dann sofort lesbar sein
# soll. (Nachgeprüft: Unter `set -e` bricht auch die Kurzform nicht ab — eine
# fehlschlagende Bedingung in einer `&&`-Kette ist davon ausgenommen.)
if [ "$gelaufen" -gt "$vorher" ]; then
	echo "$gelaufen" > "$merker"
fi

dauer=$((SECONDS - start))
printf '\n%s  %d Tests, %d:%02d min gesamt\n' \
	"$([ $fehler -eq 0 ] && echo '✓ grün' || echo '✗ rot')" "$gelaufen" \
	$((dauer / 60)) $((dauer % 60))

# **Wer nur im zweiten Anlauf durchkam, wird genannt.** Ein stiller
# Wiederholungslauf wäre schlimmer als gar keiner: Die Suite sähe jahrelang
# grün aus, während dieselben drei Journeys jedes Mal wackeln. Diese Liste ist
# der Auftrag, sie zu reparieren.
# Erkannt wird das an einer Schreibweise, die nachweislich im Protokoll steht:
# Ein Test, für den eine „failed"-Zeile existiert, während der Lauf am Ende
# grün ist, ist beim ersten Versuch gefallen und beim zweiten durchgekommen.
# (Nach dem Muster „passed … on retry" zu suchen wäre geraten — die Schreibweise
# hängt an der Xcode-Fassung, diese hier nicht.)
wackler=$(namen_wackelig "$protokoll" || true)
if [ -n "$wackler" ]; then
	echo
	echo "↻ Erst im zweiten Anlauf grün — diese Journeys wackeln:"
	echo "$wackler" | sed 's/^/    /'
	echo "  Wer hier öfter auftaucht, gehört repariert. Siehe docs/TESTS.md."
fi
exit $fehler
