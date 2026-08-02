#!/usr/bin/env bash
#
# Das Messgeschirr laufen lassen und gegen die Grundwerte halten.
#
#   tools/perf.sh                 # messen und vergleichen
#   tools/perf.sh --record        # die gemessenen Werte als neue Grundwerte
#   tools/perf.sh --bulk 1200     # mit anderer Prospektlänge (Steigung messen)
#   tools/perf.sh --only testAngeboteScrolling
#
# **Warum ein Skript und nicht XCTests eigene `.xcbaseline`.** Der Weg wurde
# gebaut und dann verworfen, weil er nachweislich nichts tut: Ein von Hand
# geschriebenes `xcbaselines/<Ziel>.xcbaseline` wird von `xcodebuild` nicht
# gefunden — im Protokoll steht weiter `baselineName: ""`, der Grundwert wird
# also nie herangezogen. Xcode vergibt für das Laufziel eine eigene UUID, die
# von aussen nicht zu erraten ist, und akzeptieren lässt sich ein Grundwert nur
# im Fenster, nicht auf der Kommandozeile. Eine Datei, die wie ein Wächter
# aussieht und keiner ist, ist schlimmer als keine.
#
# Also: Die Zahlen stehen in `tools/perf-baseline.json`, lesbar und im Repo,
# und der Vergleich passiert hier.
#
# **Was die Zahlen NICHT sind.** Absolutwerte vom Simulator sagen nichts über
# ein iPhone. Sie taugen für genau eine Frage: „Ist es seit dem letzten Mal
# teurer geworden?" — und die auch nur, wenn beide Läufe auf derselben Maschine
# in derselben Sitzung entstanden sind.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS="$REPO/ios"
BASELINE="$REPO/tools/perf-baseline.json"
DESTINATION="${LECHARIOT_PERF_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"

# Ab wie viel Prozent Verschlechterung es rot wird. Grosszügig mit Absicht:
# Die gemessene relative Standardabweichung lag bei 0,2–5 %, ein Deckel bei
# 10 % wäre ein Wackelkontakt. 50 % fängt, was ein Mensch merkt.
TOLERANCE="${LECHARIOT_PERF_TOLERANCE:-50}"

record=0
bulk="${LECHARIOT_PERF_BULK:-400}"
only=""
while [ $# -gt 0 ]; do
	case "$1" in
		--record) record=1; shift ;;
		--bulk) bulk="$2"; shift 2 ;;
		--only) only="$2"; shift 2 ;;
		*) echo "Unbekanntes Argument: $1" >&2; exit 2 ;;
	esac
done

target="LeChariotUITests/PerformanceJourneyTests"
[ -n "$only" ] && target="$target/$only"

echo "▸ Messgeschirr — $bulk Zeilen je Kette, Ziel: $DESTINATION"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# `|| true`, weil ein roter Testlauf hier trotzdem Messwerte hinterlässt und
# die Auswertung unten die eigentliche Aussage trifft.
LECHARIOT_PERF_BULK="$bulk" xcodebuild test \
	-project "$IOS/LeChariot.xcodeproj" \
	-scheme LeChariot \
	-destination "$DESTINATION" \
	-only-testing:"$target" > "$log" 2>&1 || true

if ! grep -q "measured \[" "$log"; then
	echo "✗ Kein einziger Messwert im Protokoll — der Lauf ist gescheitert:" >&2
	grep -E "error:|failed" "$log" | head -20 >&2
	exit 1
fi

python3 - "$log" "$BASELINE" "$record" "$TOLERANCE" "$bulk" <<'PYEOF'
import json, os, re, sys

log_path, baseline_path, record, tolerance, bulk = sys.argv[1:6]
record, tolerance = int(record) == 1, float(tolerance)

# "Test Case '-[... testAngeboteScrolling]' measured [CPU Time (lechariot), s] average: 1.261, ..."
pattern = re.compile(
    r"Test Case '-\[\S+ (\w+)\]' measured \[([^\]]+)\] average: ([0-9.eE+-]+)"
)

measured = {}
for line in open(log_path, errors="replace"):
    m = pattern.search(line)
    if m:
        measured.setdefault(m.group(1), {})[m.group(2)] = float(m.group(3))

# Die zwei Deltas ("Memory Physical", die Differenz) sind Rauschen — sie
# schwankten im Messlauf um bis zu 250 % relative Standardabweichung, weil sie
# eine Differenz nahe null sind. Ein Wächter darauf wäre ein Zufallsgenerator.
NOISY = ("Memory Physical (",)

if record:
    payload = {
        "hinweis": "Gemessen mit tools/perf.sh --record. Nur gegen Werte derselben "
                   "Maschine und desselben Simulators vergleichbar.",
        "bulkProKette": int(bulk),
        "werte": measured,
    }
    with open(baseline_path, "w") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print(f"▸ {sum(len(v) for v in measured.values())} Werte aus "
          f"{len(measured)} Strecken als Grundwerte geschrieben.")
    sys.exit(0)

if not os.path.exists(baseline_path):
    print("✗ Keine Grundwerte. Einmal `tools/perf.sh --record` fahren.", file=sys.stderr)
    sys.exit(1)

baseline = json.load(open(baseline_path))
if baseline.get("bulkProKette") != int(bulk):
    print(f"⚠ Grundwerte stammen von {baseline.get('bulkProKette')} Zeilen je Kette, "
          f"gemessen wurde mit {bulk}. Nur die Zahlen unten sind gültig, der "
          f"Vergleich nicht.")

worse, compared = [], 0
for test, metrics in sorted(measured.items()):
    print(f"\n  {test}")
    for name, value in sorted(metrics.items()):
        if any(name.startswith(n) for n in NOISY):
            print(f"    {name:52s} {value:>14.1f}   (Rauschen, kein Wächter)")
            continue
        before = baseline.get("werte", {}).get(test, {}).get(name)
        if before is None:
            print(f"    {name:52s} {value:>14.1f}   (neu)")
            continue
        compared += 1
        delta = (value - before) / before * 100 if before else 0.0
        flag = ""
        if delta > tolerance:
            flag = "  ✗ SCHLECHTER"
            worse.append((test, name, before, value, delta))
        print(f"    {name:52s} {value:>14.1f}   {delta:+6.1f}% gegen {before:.1f}{flag}")

print()
if worse:
    print(f"✗ {len(worse)} Wert(e) mehr als {tolerance:.0f} % schlechter als der Grundwert.")
    print("  Vor jeder Optimierung: denselben Lauf noch einmal fahren. Ein einzelner")
    print("  Ausreisser ist keine Regression, und die Maschine hat auch anderes zu tun.")
    sys.exit(1)

print(f"✓ {compared} Werte verglichen, keiner mehr als {tolerance:.0f} % schlechter.")
PYEOF
