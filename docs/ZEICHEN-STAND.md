# Artikelzeichen: Stand und Übergabe (2026-08-11)

Diese Notiz ist die Übergabe an die nächste Sitzung. Sie sagt, **was jetzt
gilt**, **was schon gescheitert ist** und **was offen liegt**. Der Hintergrund
mit den Messwerten steht daneben in `ZEICHEN-RECHERCHE.md`, der Arbeitsvorrat
in `ARTIKELZEICHEN.md`.

## Wo der Code steht

Branch `artikelzeichen-farbe`, abgezweigt von `main`. **Nichts committet.**
HEAD des Branches ist noch `7688daa` („Artikelzeichen, Tranche 2").

| Datei | |
|---|---|
| `ios/LeChariot/DesignSystem/CategoryGlyphs.swift` | geändert — Ebenenmodell, `Feder`, `Pen.rund`, `Pen.oval` |
| `ios/LeChariot/DesignSystem/ItemGlyphs.swift` | geändert — eigene Strichstärken, Federprofil, 10 Rezepte neu |
| `tools/zeichensatz.swift` | geändert — Erscheinungsbild wird gesetzt statt geerbt |
| `docs/ZEICHEN-RECHERCHE.md` | neu — die Messungen |
| `tools/umriss.py` | neu — shapely-Vereinigung → Pen |
| `tools/svg2pen.py` | neu — SVG → Pen |
| `NOTICE` | neu — Lucide-Lizenzhinweis |
| `tools/__pycache__/` | Müll, gehört in `.gitignore` oder gelöscht |

## Das Ebenenmodell

`CategoryGlyph.Drawing` trägt fünf Pfade, von hinten nach vorn:

| Ebene | Deckkraft | wofür |
|---|---:|---|
| `koerper` | 0,14 | der ausgefüllte Umriss |
| `schatten` | 0,34 | abgewandte Flächen — Seitenwand, Unterseite |
| `fill` | 1,0 | volle Punkte: Kerne, Augen |
| `fein` | Strich 0,036 | Innenzeichnung: Rillen, Falze, Etiketten |
| `stroke` | Feder | die Kontur |

**Eine Farbe, mehrere Dichten.** Keine Ebene holt sich eine eigene Farbe, alles
erbt `foregroundStyle` von außen — deshalb wird eine abgehakte Kachel ganz grau,
ohne dass die Aufrufstelle etwas tun muss.

**Ein farbiger Entwurf wurde verworfen.** Am Vormittag gab es fünf Töne (rote
Tomate, warme Banane, cremefarbene Milch). Scott: „no i hate, i want like bring
… if more then 1 color just shaded." Und die Referenzaufnahme gab ihm recht:
Bring! ist **weiß auf mintgrüner Kachel**, eine einzige Farbe. Die Wertigkeit
dort kommt aus Tiefe durch Ton, mehr Gegenstand je Zeichnung und Textur — nicht
aus Farbe. Nicht wieder aufmachen.

## Strichstärken

```
CategoryGlyph.lineWidthRatio      0,095   für 13 pt (Abschnittszeile)
ItemGlyph.lineWidthRatio          0,065   für 40 pt (Raster) — Bezug für Tests
ItemGlyph.feinLineWidthRatio      0,036
ItemGlyph.feder  breite 0,072 · neigung −32° · schmal 0,46 · spitze 0,18
```

Die Trennung ist der Grund, warum überhaupt Zeichnung möglich wurde: Bei 0,095
auf 40 pt ist der Strich 3,8 pt breit, und **zwei Kanten näher beieinander als
die Strichstärke sind eine Kante**. Daran sind drei Bananen (ein Klotz), zwei
Möhren (ein „W") und die Körnung im Brokkolikopf (zwei Augen) gescheitert.

Referenz: OpenMoji liegt bei 0,0278, Lucide und Tabler bei 0,0833.

## Die Feder

`Feder.kontur(_:seite:profil:)` rechnet aus einer Mittellinie eine **gefüllte**
Kontur mit wechselnder Breite — breit quer zur Federhaltung, schmal längs dazu.
Das ist Scotts Beobachtung an Bring!: „like u use a pencil in reallife".

Zwei Fallen, beide schon hineingetreten:

- `Path.addLines` setzt ein eigenes `move` und beginnt einen **neuen**
  Teilpfad. Die Rückseite eines offenen Zuges wurde dadurch eine zweite Fläche,
  und unter Nonzero löschten sich die beiden stellenweise aus — die Bananen
  waren hohl. Jetzt `move` + `addLine` von Hand.
- Die Verjüngung an offenen Enden darf **nicht** über einen Anteil der Länge
  laufen: Kurze Striche bestehen nur aus Enden. Möhrenkraut und Tomatenkelch
  waren Splitter. Jetzt greift sie erst ab vier Federbreiten Länge.

`CartGlyph` bleibt bei der echten gestrichenen Linie — die wird mit `.trim`
aufgezogen, und eine ausgezogene Kontur ist eine Fläche, die das nicht kann.

## Was zehn Anläufe am Brokkoli gelehrt haben

Diese Regeln gelten für den ganzen Satz, nicht nur für Gemüse:

1. **Die Achse entscheidet, was ein Ding ist — vor jedem Detail.** Runder Kopf
   über senkrechtem, mittigem Stiel ist ein **Pilz**, egal wie tief die
   Oberkante gebuchtet wird. Sieben Anläufe lang habe ich am Kopf gearbeitet.
   Aus demselben Grund musste `käse` aufhören, ein gleichschenkliges Dreieck zu
   sein (das war `pizza`), und `möhren` aufhören, gerade Dreiecke zu sein (das
   waren Pfeile).
2. **Was ich hinzufüge, wird ein Körperteil.** Drei Punkte wurden ein Gesicht,
   zwei Seitenröschen wurden Ohren, ein schmaler Stiel wurde ein Hals. Die
   Rettung ist fast immer Weglassen.
3. **Der Abstand macht die Buchtung.** Kuppen, deren Mitten dichter liegen als
   ihr Radius, ergeben eine fast konvexe Hülle — einen Klecks mit Kräuselung.
4. **Hülle zeichnen, nicht Teile.** Fünf gezeichnete überlappende Kreise sind
   fünf Ringe; zu sehen ist nur ihre Außenkante.
5. **Gerade Strecken gibt es nicht.** `lineJoin: .round` rundet nur die
   Außenseite eines Knicks, der Pfad knickt weiter scharf. Ecken über
   `Pen.rund`, und jede „gerade" Flanke bekommt 0,015–0,02 Auslenkung — sonst
   sieht gezeichnetes Zeug gefräst aus („so kantig", Scott).

Die ältere Fallenliste aus fünf früheren Runden steht in `ARTIKELZEICHEN.md`
und gilt weiter.

## Werkzeuge

**Die schnelle Runde** (zwei Sekunden, kein Simulator) — nach **jeder** Änderung:

```sh
swiftc -O tools/zeichensatz.swift \
  ios/LeChariot/DesignSystem/CategoryGlyphs.swift \
  ios/LeChariot/DesignSystem/ItemGlyphs.swift -o /tmp/zs
/tmp/zs /tmp/b.png artikel "brokkoli,pilze,salat"
# → /tmp/b-1-hell.png und /tmp/b-1-dunkel.png, je 65,6 / 40 / 22 pt
```

Beurteilt wird bei **40 pt** (Rastergröße), nicht bei 13.

**Python-Werkzeuge.** Brauchen ein venv, das **nicht im Repo liegt**
(`build/` ist gitignored):

```sh
python3 -m venv build/venv
build/venv/bin/pip install shapely pillow numpy svgpathtools
```

(Homebrew-Python ist externally-managed, `pip3 install` schlägt direkt fehl.)

- `build/venv/bin/python tools/svg2pen.py datei.svg` — SVG → Pen-Aufrufe. Über
  svgpathtools, verkraftet also Bogenbefehle und relative Koordinaten; liest die
  `viewBox` und normiert auf das Einheitsquadrat. `class="fein"` landet in der
  Innenzeichnung.
- `build/venv/bin/python tools/umriss.py brokkoli` — Kreise und Bänder mit
  shapely vereinigen, Außenkante über Catmull-Rom als Bézier. **Für einen
  einzelnen Gegenstand zu viel**: 32 gerechnete Stützpunkte kann man nicht mehr
  nachbessern, neun Bögen kann man verschieben. Sinnvoll für Hüllen, die man von
  Hand nicht trifft.

## Tests

```sh
tools/tests.sh ItemGlyphTests CategorySymbolTests AppGlyphTests --workers 1
```

25 Tests, alle grün. **Der Läufer meldet trotzdem „✗ rot".** Das ist seine
Zählheuristik: Er vergleicht gegen die zuletzt gesehene Zahl (815, aus einem
Voll-Lauf mit UI-Tests). Ein Teillauf ist immer kleiner. Es zählt nur, ob eine
Zeile `Test case … failed` auftaucht.

`ItemGlyphTests.testEveryDictionaryTermIsDrawnOrNamedAsAnException` hält hart
fest, dass das Wörterbuch **337** Begriffe hat. Beim Resync (siehe unten) fällt
dieser Test zuerst — das ist Absicht, kein Defekt.

## Lucide und die Lizenz

`brokkoli` stammt aus **Lucide** (ISC), mit `svg2pen.py` übersetzt und in unsere
Ebenen umgezogen. Zehn eigene Anläufe waren jeweils eine andere Fehllesung.

**Der Hinweis ist trotzdem fällig.** ISC erlaubt ausdrücklich „use, copy,
modify" und knüpft seine Bedingung an genau diese Handlungen — nicht der Stil
entscheidet, sondern dass die Geometrie aus ihrer Datei stammt. `NOTICE` liegt
im Wurzelverzeichnis.

**Offen und wichtig:** Der Hinweis muss **in der App** ankommen, nicht nur im
Baum. Eine Zeile in den Einstellungen („Danksagungen"). Solange die fehlt, ist
die Bedingung halb erfüllt, und die App geht Richtung Vertrieb.

OpenMoji (CC BY-SA) wurde **nur gemessen**, nie übernommen — Share-alike färbt
ab.

Nicht konvertiert, aber verfügbar und geholt: Lucide hat `apple`, `banana`,
`carrot`, `citrus`, `egg`, `milk`, `wheat`. Kein `cheese`, kein `bread`.

## Was offen liegt

1. **322 Zeichen tragen die neue Feder und den dünneren Strich, aber die alten
   Anteile.** Sie sehen dadurch besser aus als gestern, sind aber nicht nach den
   Regeln oben gebaut. Das ist die eigentliche Arbeit. Vorgehen wie bisher:
   Tranchen von ~20, Prüfbogen nach jeder Runde, Fehllesungen am Rezept
   festhalten.
2. ~~**Die App-Kopie des Wörterbuchs ist sieben Begriffe hinter dem
   Backend.**~~ **Erledigt am 13.08.** Beide Kopien stehen wieder Byte für
   Byte gleich (344 Begriffe), die sieben Neuen sind gezeichnet (`beeren`
   heißt jetzt nur noch die Mischung und hat ein eigenes Zeichen bekommen,
   die Erdbeere ist unter ihren richtigen Namen gezogen), und der harte Test
   steht auf 344.
3. **`ItemGlyphTerm` kennt keine Plural- und keine ß-Toleranz.** `Limette`,
   `Nektarine`, `Aprikose`, `Brezeln`, `Klossteig`, `Rote Beete`, `Soße` lösen
   auf **nichts** auf und zeigen ein Fragezeichen, obwohl die Zeichnung da ist.
   `tools/artikelzeichen-stand.py` meldet deshalb fälschlich 100 % — es rät
   Varianten, die die App nicht rät.
4. **Bekannte Fehllesungen im Restbestand**, an denen die Achsen-Regel hängt:
   `hundefutter` ist ein Smiley, `nudeln` ist eine Fliege.
5. **Die Kachel selbst** ist der größte ungenutzte Hebel. Bei Bring! trägt die
   **Kachel** die Farbe und die Zeichnung ist einfarbig darauf. Das ist eine
   Änderung an `ShoppingGridTile`, nicht am Zeichensatz — und Scotts
   Entscheidung, weil es die ganze Liste umstellt.
6. **Leistung ungemessen.** `Feder.kontur` tastet bei jedem Zeichnen ab
   (14 Punkte je Kurve) und läuft in `path(in:)`, also bei jedem Layout. Im
   Raster stehen ~30 Kacheln. Das ist **nicht nachgemessen** — vor dem Merge
   gehört ein Blick darauf, im Zweifel mit `XCTCPUMetric` wie bei den
   XCUITest-Latenzen.

## Die zehn, die fertig sind

`äpfel` · `bananen` · `zitronen` · `tomaten` · `möhren` · `brokkoli` · `käse` ·
`milch` · `brot` · `eier`

Jedes trägt seine Fehllesungen als Kommentar am Rezept. Das ist die
Hauskonvention und der eigentliche Wert der Datei — der nächste, der die Form
anfasst, soll nicht dieselbe Runde noch einmal drehen.
