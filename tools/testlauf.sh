#!/usr/bin/env bash
#
# Was über einen Testlauf gewusst wird — an *einer* Stelle.
#
# Diese Datei wird von `tools/tests.sh` (lokal) und von
# `.github/workflows/suite.yml` (CI) benutzt. Beide brauchen dieselben vier
# Dinge, und beim ersten Anlauf hatte CI sie nachgebaut statt geerbt:
#
#   1. **Welche Klassen nicht nebeneinander laufen dürfen** (`SERIELL`).
#   2. **Wie ein Klassenname zu seinem Ziel kommt** (`ziel_fuer_klasse`).
#   3. **Wie ein Protokoll zu urteilen ist** (`namen_endgueltig_rot` und
#      Nachbarn) — die Regel „rot ist ein Lauf, in dem ein *Test* gefallen
#      ist", nicht der Rückgabewert von `xcodebuild`.
#   4. **In welchem Gebietsschema gemessen wird** (`GEBIETSSCHEMA`).
#
# Zwei Fassungen dieser drei Dinge wären genau die Sorte Doppelung, die still
# auseinanderläuft: Wer eine Klasse in `SERIELL` einträgt und CI nicht
# nachzieht, hat einen grünen lokalen Lauf und eine wackelnde Suite auf dem
# Runner — und keinen Hinweis darauf, dass beides zusammengehört.
#
# Sourcen, nicht ausführen:
#
#     . "$(dirname "$0")/testlauf.sh"
#
# Direkt aufgerufen ist es ein kleines Werkzeug für den Workflow:
#
#     tools/testlauf.sh scherben 4        # die Klassen auf 4 Scherben verteilen
#     tools/testlauf.sh seriell           # die Klassen des seriellen Durchgangs
#     tools/testlauf.sh soll              # was in einem CI-Lauf gelaufen sein muss
#     tools/testlauf.sh ziel FooTests     # in welchem Ziel die Klasse liegt
#     tools/testlauf.sh gewichte          # Klassen nach Zahl der Testmethoden
#     tools/testlauf.sh auswertung x.log  # Urteil über ein Protokoll
#     tools/testlauf.sh gebietsschema     # Gebietsschema und Sprachen des Laufs
#     tools/testlauf.sh gebietsschema-setzen UDID   # sie auf ein Gerät schreiben

TESTLAUF_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Die Klassen, die **allein auf einer ruhigen Maschine** laufen müssen.
#
# `TermGridJourneyTests.testNothingMovesUnderTheThumbWhileTyping` zählt je
# Buchstabe alle Knöpfe mit `buttons.matching(…).count`. `.count` muss jeden
# Treffer wirklich holen, also den ganzen Barrierefreiheits-Baum über die
# Prozessgrenze — fünfmal, bei stehender Tastatur. Allein gemessen 9,4 s, neben
# zwei Klonen **552,5 s**. Die beiden Nachbartests derselben Klasse auf
# demselben Klon blieben bei 11 s und 12 s; es ist also die Abfrage und nicht
# der Klon.
#
# `TileGestureJourneyTests.testATapChecksTheItemWithoutWaitingForALongPress`
# trug denselben Befund aus der anderen Richtung: Er sicherte eine **Frist
# zwischen zwei Gesten** zu. Auf drei Klonen fiel er am 09.08. zweimal von zwei
# Versuchen, allein ist er grün. Wer eine Gestendauer zusichert, misst unter
# Last die Last.
#
# **Allein zu laufen hat trotzdem nicht gereicht** (17.08.): Auch im seriellen
# Durchgang riss der Median die Schranke in 9 von 14 Läufen — der geliehene
# Runner ist nicht der Mac, auf dem die 1,0 s kalibriert wurden. Die Schranke
# ist deshalb weg; geurteilt wird über die Zahl in `TippLatenzProbe`. Die Klasse
# bleibt hier, damit der Median im Protokoll unter Last nicht zu Unsinn wird —
# wer die Wanduhr des seriellen Durchgangs braucht, kann sie herausnehmen, ohne
# eine Zusicherung zu verlieren.
#
# `PerformanceJourneyTests` misst CPU und Speicher gegen Grundwerte aus
# `tools/perf-baseline.json` — aufgenommen auf Scotts Mac im Leerlauf. Neben
# zwei weiteren Simulatoren gemessen wären sie eine Aussage über die Auslastung
# und über nichts sonst. Deshalb steht die Klasse hier **und** in `OHNE_CI`.
#
# Wer hier etwas einträgt, sagt damit „das kostet Wanduhr, seriell" — die Liste
# ist absichtlich kurz zu halten.
SERIELL=(
	LeChariotUITests/PerformanceJourneyTests
	LeChariotUITests/TermGridJourneyTests
	LeChariotUITests/TileGestureJourneyTests
	LeChariotUITests/TippLatenzProbe
)

# ---------------------------------------------------------------------------
# Das Gebietsschema, in dem gemessen wird.
#
# **Die App rechnet Preise mit `Locale.current`.** `.currency(code: "EUR")` steht
# an acht Stellen ohne eigenes Gebietsschema, und der Simulator erbt seins vom
# Rechner: auf Scotts Mac `de_DE` → `0,79 €`, auf dem geliehenen Runner `en_US`
# → `€0.79`. Dieselbe Zeile, zwei Schreibweisen.
#
# Das hat eine Woche lang gekostet, ohne dass es jemand sah (17.08.):
# `NextWeekJourneyTests.testTheSameProductInBothWeeksShowsThePreviewPriceInThePreview`
# sucht `0,79` und war in **8 von 8** untersuchten Läufen rot, lokal immer grün.
# Schlimmer ist die andere Hälfte desselben Tests: Die Zusicherung, dass der
# *heutige* Preis `0,99` nicht in die Vorschau leckt — die Regression aus #53 —
# ging in CI durch, weil `0,99` in US-Schreibweise ebenfalls nirgends steht. Ein
# Wächter, der aus Versehen immer zustimmt, ist schlimmer als keiner.
#
# Gemessen wird deshalb in der Sprache, in der die App ausgeliefert wird. Sie ist
# einsprachig deutsch; ein Lauf in `en_US` prüft einen Zustand, den kein Nutzer
# sieht.
#
# **Und zwar am Gerät, nicht über `-testLanguage`/`-testRegion`.** Der nahe
# liegende Weg wirkt hier nicht: Mit beiden Flaggen auf `en`/`US` blieb derselbe
# Test auf diesem Mac grün (17.08. nachgemessen). Die Journeys setzen
# `app.launchArguments` selbst, und diese Zuweisung überschreibt das
# `-AppleLocale`, das XCTest dem Start sonst mitgäbe. Was wirkt, ist das
# Gebietsschema des Simulators: auf `en_US` gestellt fiel derselbe Test auf
# diesem Mac mit derselben Meldung und demselben Etikett wie in CI
# (`'Bio Vollmilch, €0.79, bei Lidl, …'`), zurück auf `de_DE` war er wieder grün.
GEBIETSSCHEMA_LOCALE=de_DE
GEBIETSSCHEMA_SPRACHEN=(de-DE en-DE)

# Das Gebietsschema auf ein Gerät schreiben. Läuft vor dem Testlauf; `xcodebuild`
# bootet danach selbst.
#
# Geschrieben wird im Bootzustand über `simctl spawn` und nicht in die Plist im
# Datenverzeichnis: Ein frisch angelegtes Gerät hat das Verzeichnis noch gar
# nicht, und `cfprefsd` schriebe eine von Hand angelegte Datei beim Abschalten
# wieder platt. Danach abschalten, damit der nächste Start die Werte liest.
gebietsschema_setzen() {
	local udid="$1"
	xcrun simctl bootstatus "$udid" -b >&2
	xcrun simctl spawn "$udid" defaults write -g AppleLocale -string "$GEBIETSSCHEMA_LOCALE"
	xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "${GEBIETSSCHEMA_SPRACHEN[@]}"
	xcrun simctl shutdown "$udid" >&2
}

# Was auf einem geteilten Runner **gar nicht** laufen darf.
#
# `PerformanceJourneyTests` vergleicht gegen Grundwerte einer bestimmten
# Maschine im Leerlauf. Auf drei geliehenen Kernen ist jede dieser Zahlen eine
# Aussage über den Nachbarn im Rechenzentrum. Die Klasse sagt das seit dem
# 01.08. selbst in ihrem Kopfkommentar: „Läuft lokal, nicht in CI. … wenn einer
# kommt, gehört diese Klasse ausgeschlossen."
#
# Ausgeschlossen statt stillschweigend geduldet: Ein Messstand, dem niemand
# glaubt, wird abgeschaltet statt gelesen — und ein roter Messstand in jedem
# zweiten PR erzieht dazu, rote Läufe zu überblättern.
#
# `MarktwahlProbe` steht aus demselben Grund hier (10.08., #124). Sie misst die
# Tippdauer über drei Verzeichnisgrößen, und der Befund ist eine *Steigung*
# zwischen zwei Größen — auf geliehenen Kernen wäre auch die eine Aussage über
# den Nachbarn. Dazu startet sie die App dreimal und kostet damit rund
# anderthalb Minuten in einer Scherbe, für eine Zusicherung, die nur sagt, dass
# überhaupt gemessen wurde. Sie gehört an den Mac, an dem jemand die Zahlen
# liest, nicht in jeden PR.
# `TippLatenzProbe` gehoert aus denselben zwei Gruenden dazu (11.08., #138):
# Sie misst Tippdauern, und der Befund ist ein *Unterschied* zwischen zwei
# Laeufen — auf geliehenen Kernen waere er eine Aussage ueber den Nachbarn.
# Nachgemessen am 11.08.: Dieselbe Sonde meldete fuer denselben Griff 662 ms auf
# ruhiger Maschine und 735 ms, waehrend eine zweite Sitzung baute. 11 % Rauschen
# sind mehr, als eine Regression dieser Art gross ist. Dazu startet sie die App
# sechsmal.
OHNE_CI=(
	LeChariotUITests/PerformanceJourneyTests
	LeChariotUITests/MarktwahlProbe
	LeChariotUITests/TippLatenzProbe
)

# Ein blosser Klassenname reicht; das Ziel davor kommt aus dem Quellbaum.
#
# **Nachgeschlagen und nicht mehr geraten.** Geraten wurde am Namen
# (`*Journey*|*Audit*|*Shots*` heisst UI, alles andere Unit), und das hat schon
# einmal einen Lauf gekostet: `tools/tests.sh FeldtestShots` landete als
# `LeChariotTests/FeldtestShots` im UI-losen Ziel, führte **null** Tests aus und
# meldete Erfolg. Ein grüner Lauf ohne einen einzigen gelaufenen Test ist die
# teuerste Sorte Grün.
#
# Die Regel danach — „`*Shots*` ist UI" — stimmt für drei der vier Bilderbögen
# und für den vierten nicht: `ListDirectionShots` liegt in `LeChariotTests`.
# Dieselbe Falle, nur andersherum, und niemand hätte sie bemerkt.
#
# Wer die Klasse im Baum sucht, kann sich nicht irren. Nur wenn sie dort nicht
# steht (Tippfehler, noch nicht angelegt), bleibt es beim alten Raten — dann
# meldet `xcodebuild` wenigstens einen Namen, der gemeint war.
ziel_fuer_klasse() {
	case "$1" in
		*/*) echo "$1"; return ;;
	esac
	local ziel
	for ziel in LeChariotUITests LeChariotTests; do
		if grep -qlrE "^(final )?class $1: *XCTestCase" "$TESTLAUF_REPO/ios/$ziel" 2>/dev/null; then
			echo "$ziel/$1"; return
		fi
	done
	case "$1" in
		*Journey*|*Audit*|*Shots*) echo "LeChariotUITests/$1" ;;
		*) echo "LeChariotTests/$1" ;;
	esac
}

# ---------------------------------------------------------------------------
# Die UI-Klassen und ihr Gewicht.
#
# Gezählt wird aus dem Quellbaum, nicht aus einer Liste im Repo: Eine Liste
# veraltet bei der ersten neuen Journey, und dann verteilt der Workflow eine
# Klasse auf keine Scherbe und niemand merkt es. Der Wächter im Workflow
# („hat jede zugeteilte Klasse auch Tests gemeldet?") hängt daran.
#
# **Das Gewicht ist die Zahl der Testmethoden, nicht ihre gemessene Dauer.**
# Eine Kostentabelle wäre genauer — `AccessibilityAuditTests` kostet je Test
# 43 s, `OnboardingJourneyTests` 25 s (gemessen 08.08., siehe `docs/TESTS.md`) —
# und stünde ein halbes Jahr später falsch im Repo. Die Zahl der Methoden ist
# grob und stimmt immer. Wenn eine Scherbe dauerhaft aus der Reihe läuft, sagt
# das der Workflow selbst (er druckt je Scherbe die Wanduhr), und die Antwort
# darauf steht in `docs/TESTS.md`: eine Klasse, die allein sechs Minuten läuft,
# gehört geteilt.
klassen_mit_gewicht() {   # $1 = LeChariotUITests | LeChariotTests
	local ziel="$1" f klasse gewicht
	for f in "$TESTLAUF_REPO/ios/$ziel"/*.swift; do
		[ -e "$f" ] || continue
		klasse=$(sed -nE 's/^(final )?class ([A-Za-z0-9_]+): *XCTestCase.*/\2/p' "$f" | head -1)
		[ -n "$klasse" ] || continue
		gewicht=$(grep -cE '^[[:space:]]*func test' "$f" | tr -d ' ')
		[ "$gewicht" -gt 0 ] || continue
		echo "$gewicht $ziel/$klasse"
	done
}

ui_klassen_mit_gewicht() { klassen_mit_gewicht LeChariotUITests; }

# Alles, was in einem CI-Lauf **gelaufen sein muss** — der Sollwert des
# Wächters im Workflow. Ohne die Klassen, die dort ausdrücklich nicht laufen.
klassen_fuer_ci() {
	local k
	{ klassen_mit_gewicht LeChariotUITests; klassen_mit_gewicht LeChariotTests; } \
		| awk '{print $2}' | while read -r k; do
			_verboten "$k" || echo "$k"
		done | sort
}

# Ist die Klasse aus dem parallelen Durchgang heraus (seriell oder gar nicht)?
_ausgenommen() {
	local k="$1" s
	for s in "${SERIELL[@]}" "${OHNE_CI[@]}"; do
		[ "$s" = "$k" ] && return 0
	done
	return 1
}

# Darf die Klasse in CI überhaupt nicht laufen?
_verboten() {
	local k="$1" s
	for s in "${OHNE_CI[@]}"; do
		[ "$s" = "$k" ] && return 0
	done
	return 1
}

# Die Klassen des seriellen Durchgangs, wie er in CI läuft — also ohne die,
# die dort gar nicht laufen dürfen.
seriell_fuer_ci() {
	local s d weg
	for s in "${SERIELL[@]}"; do
		weg=0
		for d in "${OHNE_CI[@]}"; do [ "$d" = "$s" ] && weg=1; done
		[ "$weg" -eq 0 ] && echo "$s"
	done
}

# Die parallelen Klassen auf `n` Scherben verteilen, eine Zeile je Scherbe.
#
# **Grösste zuerst auf die leerste Scherbe** (LPT). Die Untergrenze eines Laufs
# bleibt die längste einzelne Klasse — verteilt wird je Klasse, nicht je Test —,
# und LPT holt aus dieser Grenze heraus, was zu holen ist. Reihum zu verteilen
# wäre eine Zeile kürzer und legte die beiden grössten Klassen mit einiger
# Wahrscheinlichkeit auf dieselbe.
#
# Scherbe 1 trägt zusätzlich den seriellen Durchgang; ihr Gewicht startet
# deshalb nicht bei null. Sonst bekäme sie genauso viel parallele Arbeit wie
# die anderen und wäre am Ende die langsamste.
#
# Deterministisch: bei gleichem Gewicht entscheidet der Name.
scherben() {
	local n="${1:-3}" vorlast=0 k g
	while read -r g k; do
		_ausgenommen "$k" && continue
		echo "$g $k"
	done < <(ui_klassen_mit_gewicht) | sort -k1,1nr -k2,2 | {
		# Der serielle Durchgang als Vorlast auf Scherbe 1.
		for k in $(seriell_fuer_ci); do
			g=$(ui_klassen_mit_gewicht | awk -v k="$k" '$2==k {print $1}')
			vorlast=$((vorlast + ${g:-0}))
		done
		awk -v n="$n" -v vorlast="$vorlast" '
			BEGIN { last[1] = vorlast }
			{
				best = 1
				for (i = 2; i <= n; i++) if (last[i] < last[best]) best = i
				last[best] += $1
				scherbe[best] = scherbe[best] (scherbe[best] ? " " : "") $2
			}
			END { for (i = 1; i <= n; i++) print scherbe[i] }'
	}
}

# ---------------------------------------------------------------------------
# Das Protokoll lesen.
#
# Die Testnamen aus einem Protokoll ziehen — beide Schreibweisen: parallel
# meldet „Test case 'Klasse.test()' passed on 'Clone N …'", seriell
# „Test Case '-[Ziel.Klasse test]' passed".
namen_mit_ausgang() {   # $1 = Protokoll, $2 = passed|failed
	grep -oE "Test case '[A-Za-z0-9_]+\.[A-Za-z0-9_]+\(\)' $2|Test Case '-\[[A-Za-z0-9_.]+ [A-Za-z0-9_]+\]' $2" "$1" 2>/dev/null \
		| sed -E "s/Test [Cc]ase '(-\[)?//; s/(\]|\(\))?' $2\$//; s/ /./" \
		| sed -E 's/^[A-Za-z0-9_]+\.([A-Za-z0-9_]+\.[A-Za-z0-9_]+)$/\1/' | sort -u
}

# Gefallen **und** nicht danach doch noch durchgekommen.
namen_endgueltig_rot() {
	comm -23 <(namen_mit_ausgang "$1" failed) <(namen_mit_ausgang "$1" passed)
}

# Gefallen, aber im zweiten Anlauf grün — die Wackelkandidaten.
namen_wackelig() {
	comm -12 <(namen_mit_ausgang "$1" failed) <(namen_mit_ausgang "$1" passed)
}

# Alle Namen, die überhaupt gelaufen sind.
#
# **Der Anker ist `ase '`, nicht `Test case '`.** Mehrere Klone schreiben in
# dasselbe Protokoll, und gelegentlich zerreisst eine Zeile: In `suite2.log`
# stand `st case 'AreaRequestStoreTests.testTwoAreasAreBothRequested()' passed`
# — die ersten zwei Zeichen sind unterwegs verlorengegangen. Der Test war
# gelaufen und grün, nur sein Name zählte nicht mehr mit. Nachgerechnet über
# beide Protokolle: mit `Test case '` kommen 833 und 832 heraus, mit `ase '`
# **833 und 833**.
#
# **Und beide Schreibweisen ergeben denselben Namen.** Parallel meldet
# `Klasse.test`, seriell `Ziel.Klasse.test` — derselbe Test unter zwei Namen.
# Solange kein Durchgang eine Klasse teilt, fällt das nicht auf; Scherbe 1
# schreibt aber ihren parallelen **und** ihren seriellen Durchgang in dasselbe
# Protokoll. Das Ziel wird deshalb abgeschnitten, bevor irgendetwas verglichen
# wird.
namen_gelaufen() {
	grep -oE "ase '[A-Za-z0-9_]+\.[A-Za-z0-9_]+\(\)'|ase '-\[[A-Za-z0-9_.]+ [A-Za-z0-9_]+\]'" "$1" 2>/dev/null \
		| sed -E "s/^ase '(-\[)?//; s/(\]|\(\))?'\$//; s/ /./" \
		| sed -E 's/^[A-Za-z0-9_]+\.([A-Za-z0-9_]+\.[A-Za-z0-9_]+)$/\1/' | sort -u
}

# Die Klassen, von denen mindestens ein Test gelaufen ist.
klassen_gelaufen() {
	namen_gelaufen "$1" | sed -E 's/^([A-Za-z0-9_]+\.)?([A-Za-z0-9_]+)\.[A-Za-z0-9_]+$/\2/' | sort -u
}

# Das Urteil über ein Protokoll, in Zeilen, die eine Maschine lesen kann.
auswertung() {
	local log="$1"
	echo "gelaufen=$(namen_gelaufen "$log" | wc -l | tr -d ' ')"
	echo "rot=$(namen_endgueltig_rot "$log" | tr '\n' ' ' | sed 's/ *$//')"
	echo "wackelig=$(namen_wackelig "$log" | tr '\n' ' ' | sed 's/ *$//')"
	echo "klassen=$(klassen_gelaufen "$log" | tr '\n' ' ' | sed 's/ *$//')"
}

# ---------------------------------------------------------------------------
# Direkt aufgerufen: das kleine Werkzeug für den Workflow.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	set -euo pipefail
	case "${1:-}" in
		scherben)    scherben "${2:-3}" ;;
		seriell)     seriell_fuer_ci ;;
		gebietsschema) echo "$GEBIETSSCHEMA_LOCALE ${GEBIETSSCHEMA_SPRACHEN[*]}" ;;
		gebietsschema-setzen) gebietsschema_setzen "$2" ;;
		klassen)     ui_klassen_mit_gewicht | awk '{print $2}' | sort ;;
		soll)        klassen_fuer_ci ;;
		gewichte)    ui_klassen_mit_gewicht | sort -k1,1nr -k2,2 ;;
		ziel)        ziel_fuer_klasse "$2" ;;
		auswertung)  auswertung "$2" ;;
		*) sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
	esac
fi
