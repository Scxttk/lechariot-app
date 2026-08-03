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

## Der Weg zum Werkzeug am Gerät

**Langer Druck (0,6 s) auf die Zeile „Version" in den Einstellungen** — die
Zeile dunkelt dabei ab, ein Klopfen bestätigt, danach steht dort „Diagnose".
Ausgeschaltet läuft nichts; „Diagnose verstecken" nimmt beides wieder weg.
(Bis zum 03.08. war die Frist 1,0 s **ohne jede Rückmeldung**: gemessen ging
sie bei 0,6 s und 0,8 s gar nicht auf, und wer früher losließ, hielt die Geste
für nicht vorhanden.) Unter „Produktbilder" stehen dort auch die Zähler des
Bildercaches — Speicher, Platte, Netz.

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

> [!warning] **Diese Grundwerte sind auf einer belegten Maschine entstanden.**
> Am 02.08. lief während der ganzen Messung Côte d'OS als Debug-Build mit
> ~30 % CPU, dazu WindowServer mit ~31 %; die Lastmittel lagen bei 8. Wie sehr
> das die Zahlen hebt, ist **nicht gemessen** — es ist also unbekannt, nicht
> „wahrscheinlich wenig".
>
> **Was trotzdem gilt:** die A/B-Vergleiche weiter unten. Sie sind in einer
> Sitzung unter derselben Last gefahren, und genau dafür ist der Messstand
> gebaut. **Was nicht gilt:** jede Aussage über einen Absolutwert.
>
> **Vor dem nächsten Vergleich `tools/perf.sh --record` auf einer ruhigen
> Maschine neu fahren** (`ps -Ao pcpu,comm -r | head` vorher ansehen), sonst
> meldet der Wächter beim ersten sauberen Lauf eine „Verbesserung", die keine
> ist.

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
