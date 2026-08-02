# Messgeschirr

Was die vier Kern-Bildschirme kosten, in Zahlen. Gebaut am 2026-08-02, ausgelöst
von „einige Stellen ruckeln" aus Build `2026.0801.1951` — eine Meldung ohne Ort
und ohne Messung.

```bash
tools/perf.sh                      # messen und gegen tools/perf-baseline.json halten
tools/perf.sh --record             # die gemessenen Werte als neue Grundwerte
tools/perf.sh --bulk 1200          # andere Prospektlänge (Steigung messen)
tools/perf.sh --only testAngeboteScrolling
```

Die Strecken liegen in `ios/LeChariotUITests/PerformanceJourneyTests.swift` und
laufen mit der UI-Suite mit. **Nicht in CI** — Simulator-Zeiten auf geteilten
Runnern sind Rauschen.

## Was die Zahlen sind, und was nicht

Absolutwerte vom Simulator sagen nichts über ein iPhone. Sie taugen für genau
eine Frage: *Ist es seit dem letzten Mal teurer geworden?* — und die auch nur,
wenn beide Läufe auf derselben Maschine in derselben Sitzung entstanden sind.

Der Vorrat ist ein Prospekt in echter Größe: `-uiTestingBulkOffers 400` legt 400
Zeilen je Kette an, also 1 200 für die laufende Woche und 600 für die Vorschau.
Zum Vergleich: Eine Penny-Filiale trug am 01.08. in der Produktion 1 125 Zeilen.
Mit den sieben Fixture-Zeilen ruckelt nichts, und eine Messung darauf wäre eine
Zahl über nichts.

`Memory Physical` (die Differenz, nicht der Absolutwert) ist vom Wächter
ausgenommen: Sie schwankte um bis zu 250 % relative Standardabweichung, weil sie
eine Differenz nahe null ist.

## Grundwerte

iPhone 17 Pro (Simulator), 400 Zeilen je Kette, 5 Durchläufe je Strecke,
2026-08-02. Vollständig in `tools/perf-baseline.json`.

| Strecke | CPU-Zeit | Instructions | Speicher (Spitze) |
|---|---:|---:|---:|
| Liste | 0,87 s | 3,48 Mrd | 85,2 MB |
| Angebote | 1,26 s | 4,35 Mrd | 89,0 MB |
| Vorschau | 1,31 s | 4,42 Mrd | 92,5 MB |
| Rundgang | 3,17 s | 21,36 Mrd | 97,1 MB |

Die drei Scroll-Strecken messen denselben Block (zwei schnelle Wischer hinunter,
einer hinauf) und sind untereinander vergleichbar. **Der Rundgang nicht:** Sein
Block enthält den Tab-Wechsel, das Scrollen in den Einstellungen und sieben
Rahmen. Die 3,17 s sind ein Grundwert für sich selbst, kein Beleg dafür, dass
der Rundgang dreimal so teuer ist wie eine Liste.

## Was die erste Messung ergeben hat

**Zwei naheliegende Ursachen sind widerlegt, keine bestätigt.**

1. **Die Prospektlänge ist es nicht.** Angebote-Scrollen bei 300 / 1 200 / 3 600
   Zeilen: 1,250 s · 1,263 s · 1,262 s CPU-Zeit, Instructions 4,30 / 4,35 / 4,23
   Mrd. Flach über den Faktor zwölf — die Liste ist faul, wie sie soll.
2. **Die Rundgang-Maske ist es nicht.** `ContentView` legt
   `overlayPreferenceValue(TutorialAnchorKey.self)` über die ganze `TabView`;
   der Verdacht war, dass die Anker-Sammlung auf jedem Bildschirm mitläuft.
   Ohne den Block gemessen: 1,218 s gegen 1,263 s, Instructions 4,306 gegen
   4,347 Mrd — innerhalb des Rauschbands der drei Läufe oben.

Damit steht der Ruckel-Befund als **gemessen, nicht behoben**. Der nächste
Schritt ist nicht Optimieren, sondern der Ort: Scott notiert beim nächsten
Durchlauf, *welcher* Bildschirm oder Übergang ruckelt.
