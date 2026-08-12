#!/usr/bin/env python3
"""SVG-Pfade → `Pen`-Aufrufe für `ItemGlyphs.swift`.

Übersetzt fremde oder zugelieferte SVG-Zeichnungen in Rezeptzeilen. Das
Übersetzen von Hand ist genau die Stelle, an der sich Zahlen verlesen — und
ein verlesener Kontrollpunkt sieht hinterher aus wie eine Designfrage.

Gerechnet wird über `svgpathtools`, nicht mit einem eigenen Parser: Fremde
Dateien bringen relative Befehle, Bögen (`A`/`a`) und Kurzformen mit, und ein
selbstgeschriebener Parser deckt davon immer genau das nicht ab, was in der
nächsten Datei steht. Jeder Teilpfad wird abgetastet und über Catmull-Rom als
kubische Bézier ausgegeben — damit ist jede Segmentart erschlagen.

Die `viewBox` wird gelesen und auf das Einheitsquadrat normiert; ein Satz auf
24 × 24 und einer auf 72 × 72 kommen beide richtig an.

    build/venv/bin/python tools/svg2pen.py datei.svg [--dicht 1.4]
"""
import re
import sys

from svgpathtools import parse_path


def catmull_rom(punkte, geschlossen):
    n = len(punkte)
    aus = []
    for i in range(n if geschlossen else n - 1):
        p0 = punkte[(i - 1) % n]
        p1 = punkte[i % n]
        p2 = punkte[(i + 1) % n]
        p3 = punkte[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        aus.append((c1, c2, p2))
    return aus


def teilpfade(pfad):
    """Zusammenhängende Stücke — ein `d` kann mehrere enthalten."""
    stuecke, lauf = [], []
    for seg in pfad:
        if lauf and abs(lauf[-1].end - seg.start) > 1e-6:
            stuecke.append(lauf)
            lauf = []
        lauf.append(seg)
    if lauf:
        stuecke.append(lauf)
    return stuecke


def als_pen(d, seite, fein=False, dichte=1.4, einzug="            "):
    zeilen = []
    for segmente in teilpfade(parse_path(d)):
        laenge = sum(s.length(error=1e-3) for s in segmente)
        if laenge <= 0:
            continue
        # Ein Stützpunkt je `dichte` Einheiten der viewBox, mindestens 8.
        n = max(8, min(64, int(laenge / dichte)))
        pkt = []
        for i in range(n):
            z = segmente[0].start if n == 1 else None
            t = i / n
            # über die Gesamtlänge parametrisieren
            rest, z = t * laenge, None
            for s in segmente:
                sl = s.length(error=1e-3)
                if rest <= sl or s is segmente[-1]:
                    z = s.point(s.ilength(min(rest, sl), s_tol=1e-4))
                    break
                rest -= sl
            pkt.append((z.real / seite, z.imag / seite))
        start = abs(segmente[-1].end - segmente[0].start) < 1e-6
        seg = catmull_rom(pkt, start)
        if fein:
            jetzt = pkt[0]
            for c1, c2, ende in seg:
                zeilen.append(f"{einzug}p.feinBogen(p.at({jetzt[0]:.3f}, {jetzt[1]:.3f}), "
                              f"p.at({ende[0]:.3f}, {ende[1]:.3f}), "
                              f"p.at({c1[0]:.3f}, {c1[1]:.3f}), p.at({c2[0]:.3f}, {c2[1]:.3f}))")
                jetzt = ende
        else:
            zeilen.append(f"{einzug}p.begin(p.at({pkt[0][0]:.3f}, {pkt[0][1]:.3f}))")
            for c1, c2, ende in seg:
                zeilen.append(f"{einzug}p.bow(p.at({ende[0]:.3f}, {ende[1]:.3f}), "
                              f"p.at({c1[0]:.3f}, {c1[1]:.3f}), p.at({c2[0]:.3f}, {c2[1]:.3f}))")
            if start:
                zeilen.append(f"{einzug}p.close()")
    return zeilen


def uebersetze(svg, dichte=1.4):
    vb = re.search(r'viewBox="[\d.\-]+\s+[\d.\-]+\s+([\d.]+)', svg)
    seite = float(vb.group(1)) if vb else 100.0
    aus = []
    for tag in re.findall(r'<path\b[^>]*>', svg, re.S):
        d = re.search(r'\sd="([^"]+)"', tag)
        if not d:
            continue
        klasse = re.search(r'class="([^"]*)"', tag)
        fein = bool(klasse and 'fein' in klasse.group(1))
        aus += als_pen(d.group(1), seite, fein=fein, dichte=dichte)
    return aus


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dichte = 1.4
    for a in sys.argv[1:]:
        if a.startswith('--dicht'):
            dichte = float(a.split('=')[1]) if '=' in a else dichte
    svg = open(args[0]).read() if args else sys.stdin.read()
    print("\n".join(uebersetze(svg, dichte)))
