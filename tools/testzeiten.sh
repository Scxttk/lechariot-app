#!/usr/bin/env bash
# Wie lange jede Testklasse in einem CI-Lauf wirklich gebraucht hat.
#
# **Wozu.** Die Scherben in `tools/testlauf.sh` werden nach der **Zahl der
# Testmethoden** verteilt. Der Kommentar dort nennt die Ungenauigkeit selbst und
# nennt auch, warum keine Kostentabelle im Repo steht: Sie veraltet still. Das
# ist richtig — aber es lässt die Frage „läuft eine Scherbe dauerhaft aus der
# Reihe?" unbeantwortbar, ausser jemand zählt Zeitstempel von Hand.
#
# Dieses Skript zählt sie. Es speichert nichts, es misst bei Bedarf, und es kann
# deshalb auch nicht veralten.
#
# **Beispiel.** Lauf 31422359776 (PR #117), Scherbe 4:
#
#     AccessibilityAuditTests   503 s
#     TourTargetJourneyTests    143 s
#     MatchFeedbackJourneyTests 129 s
#
# Die Scherbe lief 28:55, die kürzeste 21:36. 8:23 davon ist eine einzige
# Klasse — und `testlauf.sh` sagt selbst, was dann zu tun ist: „eine Klasse, die
# allein sechs Minuten läuft, gehört geteilt."
#
# Aufruf:
#     tools/testzeiten.sh                # letzter Suite-Lauf auf diesem Zweig
#     tools/testzeiten.sh 31422359776    # ein bestimmter Lauf
set -euo pipefail

lauf="${1:-}"
if [ -z "$lauf" ]; then
	lauf=$(gh run list --workflow Suite --limit 1 --json databaseId --jq '.[0].databaseId')
	[ -n "$lauf" ] || { echo "Kein Suite-Lauf gefunden." >&2; exit 1; }
fi
echo "Lauf $lauf"

# Je Scherbe einmal durchs Protokoll: Die Zeitstempel stehen an den Zeilen
# „Test Suite 'X' started at …" und „… passed at …".
gh run view "$lauf" --json jobs \
	--jq '.jobs[] | select(.name|startswith("journeys")) | "\(.databaseId)\t\(.name)"' \
| while IFS=$'\t' read -r id name; do
	echo
	echo "── ${name%%,*} ──"
	gh run view "$lauf" --log --job "$id" 2>/dev/null \
	| grep -oE "Test Suite '[A-Za-z0-9_]+' (started|passed|failed) at [0-9-]+ [0-9:]+" \
	| awk '{gsub(/'"'"'/,"",$3); print $3, $4, $6, $7}' \
	| python3 -c '
import sys, datetime
begonnen, zeilen = {}, []
for roh in sys.stdin:
    teil = roh.split()
    if len(teil) < 4:
        continue
    name, was, tag, uhr = teil[0], teil[1], teil[2], teil[3][:8]
    stempel = datetime.datetime.strptime(tag + " " + uhr, "%Y-%m-%d %H:%M:%S")
    if was == "started":
        begonnen[name] = stempel
    elif name in begonnen:
        zeilen.append(((stempel - begonnen.pop(name)).total_seconds(), name))
for dauer, name in sorted(zeilen, reverse=True):
    print(f"{dauer:8.0f} s  {name}")
gesamt = sum(d for d, _ in zeilen)
print(f"{gesamt:8.0f} s  = Summe der Klassen")
'
done
