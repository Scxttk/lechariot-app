#!/usr/bin/env bash
#
# **Was ein Übergang wirklich tut — Bild für Bild.**
#
#   tools/jank-probe.sh bursts   video.mp4
#   tools/jank-probe.sh motion   video.mp4 <start> <ende> [crop]
#   tools/jank-probe.sh helligkeit video.mp4 <start> <ende>
#   tools/jank-probe.sh blatt    video.mp4 <start> <ende> [ausgabe.png]
#
# `tools/perf.sh` misst, was ein Bildschirm **kostet**. Das hier misst, wie er
# **aussieht** — die zweite Hälfte, die am 02.08. gefehlt hat: Die CPU-Zahlen
# hatten zwei Ursachen widerlegt und keine gefunden, weil ein Ruckler kein
# Mittelwert ist, sondern ein einzelnes Bild an der falschen Stelle.
#
# Aufgenommen wird mit dem Simulator selbst:
#
#   xcrun simctl io <udid> recordVideo --codec h264 --force /tmp/probe.mp4 &
#   ... die Strecke antippen ...
#   kill -INT %1
#
# **Die Aufnahme ist variabel getaktet (VFR): Der Simulator schreibt nur ein
# Bild, wenn sich etwas geändert hat.** Das ist der ganze Trick — die Bilder
# *sind* die Bewegung, und eine Lücke im Zeitstempel ist Stillstand. Deshalb
# findet `bursts` die Übergänge, ohne dass jemand mitstoppen muss.
#
# **Nicht neu kodieren.** Der erste Anlauf am 06.08. hat das Stück auf 60 fps
# gezogen und dabei h264-Rauschen gemessen: Ein stehender Bildschirm kam auf
# 3,2 Graustufen mittlere Differenz und sah aus wie Dauerbewegung. Alle
# Auswertungen hier laufen direkt auf der Aufnahme.

set -euo pipefail

mode="${1:-}"
video="${2:-}"

if [ -z "$mode" ] || [ -z "$video" ]; then
	sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit 2
fi
[ -f "$video" ] || { echo "Keine Aufnahme: $video" >&2; exit 1; }

case "$mode" in

# Wo überhaupt etwas passiert ist. Eine Lücke von mehr als 0,4 s zwischen zwei
# Bildern trennt zwei Übergänge.
bursts)
	ffprobe -v error -select_streams v:0 -show_entries frame=pts_time \
		-of csv=p=0 "$video" | tr ',' '\n' | python3 -c "
import sys
ts = [float(l) for l in sys.stdin if l.strip()]
gruppen, lauf = [], [ts[0]]
for a, b in zip(ts, ts[1:]):
    if b - a > 0.4:
        gruppen.append(lauf)
        lauf = [b]
    else:
        lauf.append(b)
gruppen.append(lauf)
print('Start      Ende      Dauer   Bilder')
for g in gruppen:
    if len(g) > 4:
        print(f'{g[0]:8.3f}  {g[-1]:8.3f}  {g[-1]-g[0]:6.3f}s  {len(g):4d}')
"
	;;

# Wie lange sich in einem Ausschnitt etwas bewegt. `crop` ist ein
# ffmpeg-Ausdruck (B:H:X:Y) — ohne ihn das ganze Bild.
#
# Gemessen wird die mittlere absolute Differenz zum Vorbild. Die Schwelle 0,3
# liegt über dem Kompressionsrauschen der Aufnahme und unter jeder Bewegung,
# die ein Auge sieht.
motion)
	start="${3:?Startzeit fehlt}"; ende="${4:?Endzeit fehlt}"
	crop="${5:-}"
	kette="trim=${start}:${ende},setpts=PTS-STARTPTS"
	[ -n "$crop" ] && kette="${kette},crop=${crop}"
	kette="${kette},format=gray,tblend=all_mode=difference,signalstats,metadata=print:file=-"
	ffmpeg -v error -i "$video" -vf "$kette" -f null - 2>/dev/null | python3 -c "
import sys, re
t, werte = None, []
for zeile in sys.stdin:
    m = re.search(r'pts_time:([0-9.]+)', zeile)
    if m: t = float(m.group(1))
    m = re.search(r'YAVG=([0-9.]+)', zeile)
    if m and t is not None: werte.append((t, float(m.group(1))))
if not werte: sys.exit('Keine Bilder im Fenster')
bewegt = [t for t, v in werte if v > 0.3]
print(f'Bilder {len(werte)}   Spitze {max(v for _, v in werte):.2f} Graustufen')
if bewegt:
    print(f'Bewegung {bewegt[0]:.3f} .. {bewegt[-1]:.3f}  =  {bewegt[-1]-bewegt[0]:.3f} s')
    print()
    print('Zur Einordnung: Theme.Motion gibt einem Element 0,22 s und einem')
    print('Bildschirm 0,30 s. Alles ab 0,5 s fuehlt sich wie Warten an.')
else:
    print('Keine Bewegung ueber der Schwelle.')
"
	;;

# Mittlere Helligkeit je Bild, 0..1. Für Übergänge, die abdunkeln — der
# Rundgang-Tabwechsel war am 03.08. eine knappe halbe Sekunde bei 0,04.
helligkeit)
	start="${3:?Startzeit fehlt}"; ende="${4:?Endzeit fehlt}"
	ffmpeg -v error -i "$video" \
		-vf "trim=${start}:${ende},setpts=PTS-STARTPTS,format=gray,signalstats,metadata=print:file=-" \
		-f null - 2>/dev/null | python3 -c "
import sys, re
t, werte = None, []
for zeile in sys.stdin:
    m = re.search(r'pts_time:([0-9.]+)', zeile)
    if m: t = float(m.group(1))
    m = re.search(r'YAVG=([0-9.]+)', zeile)
    if m and t is not None: werte.append((t, float(m.group(1)) / 255))
if not werte: sys.exit('Keine Bilder im Fenster')
for t, v in werte:
    print(f'{t:6.3f}  {v:5.3f}  {\"#\" * int(v * 60)}')
print()
print(f'Dunkelster Punkt: {min(v for _, v in werte):.3f}')
dunkel = [t for t, v in werte if v < 0.15]
if dunkel:
    print(f'Unter 0,15 von {dunkel[0]:.3f} bis {dunkel[-1]:.3f} = {dunkel[-1]-dunkel[0]:.3f} s')
"
	;;

# Ein Kontaktabzug des Übergangs. Zehn Bilder, zum Ansehen — denn eine Zahl
# sagt *dass* sich etwas bewegt, nicht *was* dabei falsch aussieht. Die
# Geisterkacheln vom 06.08. standen in keiner Kennzahl, nur im Bild.
blatt)
	start="${3:?Startzeit fehlt}"; ende="${4:?Endzeit fehlt}"
	ziel="${5:-jank-blatt.png}"
	ffmpeg -v error -i "$video" \
		-vf "trim=${start}:${ende},setpts=PTS-STARTPTS,fps=12,scale=241:524,tile=5x2" \
		-frames:v 1 "$ziel" -y
	echo "▸ $ziel"
	;;

*)
	echo "Unbekannter Modus: $mode" >&2; exit 2 ;;
esac
