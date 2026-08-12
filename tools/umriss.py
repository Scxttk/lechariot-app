#!/usr/bin/env python3
"""Vereinigt Kreise und Bänder zu **einem** Umriss und schreibt ihn als
`Pen`-Aufrufe für `ItemGlyphs.swift`.

Warum es das gibt: Ein Kopf aus fünf überlappenden Kreisen ist gezeichnet fünf
Kreise — man sieht jeden Ring, und bei 22 pt ist das ein Gestrüpp. Was man
sehen will, ist die **Außenkante** der Vereinigung, eine gebuchtete Wolke. Von
Hand ist die kaum zu treffen (fünf Anläufe am Brokkoli, jeder eine andere
Fehllesung); ausgerechnet ist sie exakt.

Die Kurven kommen über Catmull-Rom als kubische Bézier heraus, nicht als
Streckenzug — ein Polygon mit dreißig Ecken wäre wieder kantig.

Aufruf:
    build/venv/bin/python tools/umriss.py brokkoli

Die Ausgabe wird von Hand ins Rezept übernommen. Absicht: `ItemGlyphs.swift`
bleibt die Quelle, in der jede Kurve eine Zeile ist, die man ändern kann — ein
erzeugter Block, den niemand mehr anfasst, wäre der Anfang vom Ende dieser
Datei.
"""
import sys
from shapely.geometry import Point, LineString
from shapely.ops import unary_union

# Die Figuren. Einheitsquadrat, y nach unten — wie im Zeichensatz.
FIGUREN = {
    # Kopf: Ring aus Kuppen, nach rechts oben versetzt. Strunk: schräges
    # Band mit stumpfem Schnitt, nach unten links. Die Achse ist das, was
    # den Brokkoli vom Pilz trennt.
    "brokkoli": {
        # **Wenige grosse Kuppen, nicht viele kleine.** Mit sechs Kreisen bei
        # r 0.15 und 0.006 Glaettung kamen 33 Stuetzpunkte heraus, und die
        # Aussenkante bekam eine feine Welligkeit — gelesen als Amoebe, nicht
        # als Roeschen. Fuenf Kreise bei r 0.175 lassen jede Kuppe ein gutes
        # Stueck vorstehen, und 0.014 Glaettung nimmt die Kraeuselung dazwischen.
        # **Der Abstand macht die Buchtung, nicht die Zahl der Kuppen.**
        # Fuenf Kreise mit r 0.175, deren Mitten nur 0.19 auseinander lagen,
        # ueberlappen fast vollstaendig — ihre Vereinigung ist annaehernd
        # konvex, also ein Klecks mit Kraeuselung. Damit eine Kuppe vorsteht,
        # muss der Mittenabstand ueber dem Radius liegen: Auf einem Ring von
        # 0.205 stehen die Nachbarn 0.241 auseinander, bei r 0.155 bleibt eine
        # Ueberlappung von 0.069 — genug, dass die Huelle zusammenhaengt, und
        # wenig genug, dass zwischen zwei Kuppen eine echte Bucht steht.
        "kreise": [(0.80, 0.37, 0.155), (0.66, 0.18, 0.155), (0.44, 0.25, 0.155),
                   (0.44, 0.49, 0.155), (0.66, 0.56, 0.155)],
        "baender": [((0.50, 0.52), (0.10, 0.90), 0.130)],
        "glaettung": 0.010,
    },
}


def catmull_rom(punkte, geschlossen=True):
    """Punktfolge → kubische Bézier-Segmente (start, c1, c2, ende)."""
    n = len(punkte)
    aus = []
    for i in range(n if geschlossen else n - 1):
        p0 = punkte[(i - 1) % n]
        p1 = punkte[i % n]
        p2 = punkte[(i + 1) % n]
        p3 = punkte[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        aus.append((p1, c1, c2, p2))
    return aus


def umriss(figur):
    teile = [Point(x, y).buffer(r, quad_segs=32) for x, y, r in figur.get("kreise", [])]
    for a, b, breite in figur.get("baender", []):
        # flache Kappe: ein Strunk ist abgeschnitten, nicht abgerundet
        teile.append(LineString([a, b]).buffer(breite, cap_style=2, quad_segs=32))
    ganz = unary_union(teile)
    if ganz.geom_type == "MultiPolygon":
        ganz = max(ganz.geoms, key=lambda g: g.area)
    rand = ganz.exterior.simplify(figur.get("glaettung", 0.006), preserve_topology=True)
    pts = list(rand.coords)[:-1]          # letzter Punkt == erster
    return pts


def als_swift(pts, einzug="            "):
    seg = catmull_rom(pts, geschlossen=True)
    zeilen = [f"{einzug}p.begin(p.at({seg[0][0][0]:.3f}, {seg[0][0][1]:.3f}))"]
    for _, c1, c2, ende in seg:
        zeilen.append(f"{einzug}p.bow(p.at({ende[0]:.3f}, {ende[1]:.3f}), "
                      f"p.at({c1[0]:.3f}, {c1[1]:.3f}), p.at({c2[0]:.3f}, {c2[1]:.3f}))")
    zeilen.append(f"{einzug}p.close()")
    return "\n".join(zeilen)


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "brokkoli"
    if name not in FIGUREN:
        sys.exit(f"kenne '{name}' nicht — bekannt: {', '.join(FIGUREN)}")
    pts = umriss(FIGUREN[name])
    print(f"// {len(pts)} Stützpunkte", file=sys.stderr)
    print(als_swift(pts))
