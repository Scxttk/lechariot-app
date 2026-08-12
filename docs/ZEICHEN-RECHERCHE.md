# Artikelzeichen: woran sich der Satz messen lässt

Aufgenommen am 2026-08-11, nachdem Scott zum ersten farbigen Entwurf sagte: „so
kantig" und davor „i want like bring". Diese Notiz hält fest, **was gemessen
ist**, damit die nächste Runde nicht wieder mit einer Vermutung anfängt.

## 1. Bring! ist nicht bunt — das war die erste falsche Annahme

Quelle: Scotts eigene Bildschirmaufnahme, `_attachments/bring-referenz-2026-08-03.mp4`
im Vault, Bilder bei 0:45–2:30 herausgeschnitten.

Die Kachelzeichnungen bei Bring! sind **weiß auf einer mintgrünen Kachel**.
Eine einzige Farbe, kein zweiter Farbton, nirgends. Der erste Entwurf hier gab
jeder Ware einen eigenen Ton (rote Tomate, warme Banane, cremefarbene Milch) —
das war aus der Erinnerung gebaut und nicht aus der Aufnahme.

Woher der Eindruck von Wertigkeit dort kommt, sind drei andere Dinge:

1. **Tiefe durch Ton statt durch Farbe** — Schachteln stehen in
   Dreiviertelansicht mit abgesetzter Seitenwand.
2. **Mehr Gegenstand je Zeichnung** — eine Handvoll Himbeeren, ein Haufen
   Knödel, ein Beutel mit aufgedruckter Möhre. Nie ein einzelnes Exemplar.
3. **Textur statt Umriss** — Kerne, Rillen, Schraffur; feine Striche innerhalb
   der Kontur.

## 2. Die Strichstärke ist der eigentliche Hebel — und sie ist nachgemessen

Verglichen mit **OpenMoji** (CC BY-SA 4.0), dessen `black`-Variante genau
dieselbe Aufgabe löst: Lebensmittel als Strichzeichnung, professionell gebaut.
Die Dateien liegen offen, also lässt sich das Verhältnis ausrechnen statt
schätzen.

| Satz | Feld | Strich | Verhältnis |
|---|---|---:|---:|
| OpenMoji `black` (Apfel, Banane, Tomate, Möhre, Käse, Brot) | 72 × 72 | 2,0 | **0,0278** |
| Le Chariot, Kategoriesatz | 1 × 1 | — | 0,0950 |
| Le Chariot, Artikelsatz (bis 11.08.) | 1 × 1 | — | 0,0950 |
| Le Chariot, Artikelsatz (seit 11.08.) | 1 × 1 | — | 0,0650 |

**Unser Strich ist selbst nach der Verdünnung noch 2,3-mal so breit wie der
Referenzsatz.** Das ist die Ursache hinter fast allen Fehlschlägen dieser
Runde, und sie ist eine Rechnung, keine Meinung: Zwei Kanten, die näher
beieinander liegen als die Strichstärke, sind **eine** Kante. Bei 0,095 hieß
das:

- drei Bananen nebeneinander → ein Klotz
- zwei Möhren nebeneinander → ein „W"
- Körnung im Brokkolikopf → zwei Augen und eine Nase
- Löcher im Käse neben der Rindenlinie → Gekritzel

Nicht die Zeichnungen waren zu ehrgeizig, sondern der Strich zu breit für sie.

**Warum 0,095 trotzdem richtig war:** Der Wert ist für die **13 pt** der
Abschnittszeile erlaufen, und dort ist alles Dünnere unter einem Gerätepixel.
Der Artikelsatz steht aber im Raster bei **40 pt** und auf dem Chip bei 22 pt.
Deshalb tragen die beiden Sätze seit dem 11.08. verschiedene Stärken
(`ItemGlyph.lineWidthRatio` gegen `CategoryGlyph.lineWidthRatio`) — das ist
kein zweiter Zeichenstil, sondern derselbe Stil bei dreifacher Größe.

## 3. Kurvendichte: der zweite Grund für „kantig"

Ebenfalls aus den OpenMoji-Dateien ausgezählt (Anzahl der Kurvenbefehle je
Zeichnung, `[cCsSqQaA]`):

| Zeichen | Kurvensegmente | Pfade |
|---|---:|---:|
| Tomate | 15 | 2 |
| Brot | 15 | 2 |
| Möhre | 13 | 2 |
| Apfel | 10 | 3 |
| Käse | 4 | 2 |
| Banane | 3 | 2 |

Der Apfelkörper dort ist **ein** durchlaufender Pfad mit zehn Kurvenstücken und
einer feinen Delle unten. Unserer war ein Viereck aus vier symmetrischen Bögen.
Vier Bögen ergeben eine Form, zehn ergeben einen Gegenstand.

Dazu kam bei uns ein handfester Fehler: Schachtel, Keil und Karton waren
**Streckenzüge mit scharfen Ecken**. `lineJoin: .round` rundet nur die
Außenseite des Knicks, der Pfad selbst knickt weiter scharf — bei 0,065
Strichstärke sieht man das an jeder Ecke. Dafür gibt es seit dem 11.08.
`Pen.rund(punkte:radius:)`.

## 4. Sätze, an denen man sich orientieren kann

| Satz | Lizenz | Wofür |
|---|---|---|
| **OpenMoji** (`black`-Variante) | CC BY-SA 4.0 | Der direkte Vergleich: Lebensmittel als Strichzeichnung, 4449 Zeichen. Zum **Messen**, nicht zum Übernehmen — SA färbt ab. |
| **Microsoft Fluent Emoji** | MIT | Flache Variante, sehr gute Lebensmittelabdeckung. Lizenz erlaubt mehr als Ansehen. |
| **Phosphor** | MIT | Wie ein Satz mehrere Strichstärken ordnet (thin/regular/bold) — die Frage, die wir gerade beantwortet haben. |
| **Iconoir** | MIT | Rasterdisziplin auf 24 × 24. |
| **SF Symbols** | Apple, nur iOS | Das Ebenenmodell (hierarchical/palette), aus dem unsere vier Ebenen kommen. |
| **Streamline** | kommerziell | Der Maßstab für Lebensmittelillustration, wenn Geld keine Rolle spielt. |

Apps mit eigenem Warenzeichensatz, die dieselbe Aufgabe gelöst haben: **Bring!**
(die Messlatte), **Picnic**, **Oda**, **Jow**, **Too Good To Go**.

**Rechtlich:** Fremde Zeichnungen bleiben draußen. Gemessen wird an ihnen,
gezeichnet wird selbst — dieselbe Linie wie bei den Händlerlogos in
`ChainMark.swift` und beim Bring!-Katalog in `ARTIKELZEICHEN.md`.

## 5. Werkzeug: was auf dieser Maschine fehlt und was es brächte

Vorhanden: `rsvg-convert`, `node`, `npm`, `python3`, `swiftc`, `ffmpeg`.
Nicht vorhanden: `inkscape`, `potrace`, `svgo`, sowie **jede** Python-Bibliothek
für Geometrie oder Bilder (`shapely`, `svgpathtools`, `pillow`, `numpy`).

Der MCP-Verzeichnisdienst hat für „figma / design / svg / vector / icons /
image / graphics / drawing" **keine** Einträge — dort ist nichts zu holen.

Nach Nutzen sortiert:

| Werkzeug | Installation | Was es löst |
|---|---|---|
| **shapely** | `pip3 install shapely` | **Echte Verdeckung.** Heute wird eine hintere Frucht von Hand als Sichel gezeichnet, weil ein voller Umriss durch die vordere hindurchliefe. Mit Booleschen Operationen wird der verdeckte Teil *ausgerechnet* — das ist genau der Schritt, der „zwei Äpfel" von „ein Apfel mit einem Strich daneben" trennt. |
| **pillow + numpy** | `pip3 install pillow numpy` | Prüfbögen zusammensetzen (dafür steht gerade ein Swift-Skript da, weil PIL fehlt) und **automatisch messen**, ob eine Zeichnung bei 22 pt zuläuft: Tintendeckung zählen, verschmolzene Kanten finden. Heute sehe ich das nur mit dem Auge. |
| **svgpathtools / svgelements** | `pip3 install svgpathtools svgelements` | SVG-Pfade einlesen und in `Pen`-Aufrufe übersetzen. Damit könnte eine Referenzkurve als Zahlenreihe hereinkommen, statt dass ich sie nachschätze. |
| **Inkscape** | `brew install --cask inkscape` | Dasselbe wie shapely, plus Pfadvereinfachung und Konturversatz, über `--actions` ohne Fenster bedienbar. Schwerer als shapely, kann dafür mehr. |
| **potrace** | `brew install potrace` | Gezeichnetes vom Papier oder iPad in Vektoren — falls du selbst skizzieren willst und ich es in Code übersetze. |
| **Rough.js** | `npm i roughjs` | Der Excalidraw-Look: absichtlich zittrige Linien. **Würde ich nicht nehmen** — Bring! ist zeichnerisch, aber nicht wackelig, und in einer Preisvergleichs-App liest sich Gekritzel als unfertig. Hier notiert, damit die Frage einmal beantwortet ist. |

Die beiden ersten Zeilen sind die, die den Unterschied machen. Beide sind ein
`pip3 install` und brauchen kein Fenster.

## 6. Was daraus für die nächste Runde folgt

1. Strichstärke weiter herunter, in Richtung 0,05 — mit dem Prüfbogen bei 22 pt
   als Grenze, nicht mit einer Zahl aus dieser Tabelle.
2. Körper aus **mehr Kurvenstücken** bauen statt aus vier symmetrischen Bögen.
3. Ecken grundsätzlich über `Pen.rund` statt über `line`.
4. Verdeckung ausrechnen, sobald `shapely` da ist.
5. Die Kachel selbst ist der größte ungenutzte Hebel: Bei Bring! trägt sie die
   Farbe, und die Zeichnung ist einfarbig darauf. Das ist eine Änderung an
   `ShoppingGridTile`, nicht am Zeichensatz — und Scotts Entscheidung.
