# Die Tests laufen lassen

```sh
tools/tests.sh                       # alles
tools/tests.sh AddFlowJourneyTests   # nur diese Klasse(n)
tools/tests.sh --unit                # nur die Unit-Tests (~25 s)
tools/tests.sh --workers 2           # weniger Klone, wenn der Mac zu tun hat
tools/tests.sh RundgangShots --result /tmp/bogen.xcresult   # mit Bildern
```

**Zwei Wege, ein Regelwerk.** Lokal läuft die Suite über `tools/tests.sh`, in
CI über `.github/workflows/suite.yml`. Was beide wissen müssen — welche Klassen
seriell laufen, wie ein Klassenname zu seinem Ziel kommt, wie ein Protokoll zu
urteilen ist — steht **einmal** in `tools/testlauf.sh`; das Skript sourcet es,
der Workflow ruft es auf. Wer eine Klasse in `SERIELL` einträgt, hat damit
beide Wege umgestellt. Welcher Weg wann dran ist, steht unter
[Die Politik](#die-politik).

**Die Bilderbögen brauchen `--result`.** `RundgangShots` und `BedienrundeShots`
hängen ihre PNGs (und den Barrierefreiheits-Baum dazu) ans Ergebnisbündel; ohne
Pfad gibt es keins, und die Bilder sind weg. Herausholen:

```sh
xcrun xcresulttool export attachments --path /tmp/bogen.xcresult --output-path /tmp/bogen
```

Hell und Dunkel kommen vom Simulator, nicht von einem Startschalter — die App
steht auf „System":

```sh
xcrun simctl ui booted appearance dark
```

Nicht `xcodebuild test` von Hand. Das Skript ist die einzige Stelle, an der
steht, was parallel darf und was nicht — von Hand aufgerufen läuft alles
seriell durch **einen** Simulator.

**Was das kostet, gemessen am 08./09.08. auf diesem Mac** (M1, 8 Kerne, 16 GB),
identische Suite, identisches Ziel:

| | Wanduhr |
|---|---|
| seriell, ein Simulator (vorher) | **50:07** |
| `tools/tests.sh`, drei Klone | **27–35 min** |

Die Spanne ist ehrlich und nicht gerundet: Der beste Lauf lag bei 27:10, die
langsameren bei 32 und 35 Minuten — je nachdem, was der Mac sonst noch tat und
ob ein Klon-Wettlauf einen Durchgang wiederholen liess. **Rund die Hälfte, nicht
ein Drittel.** Woran das hängt und was nichts gebracht hat, steht weiter unten.

## Die Politik

**Beim Arbeiten: nur die betroffenen Journeys.** `tools/tests.sh
OfferFilterJourneyTests OfferHitsJourneyTests` — eine Minute statt zwanzig, und
die Antwort auf die Frage, die gerade offen ist.

**Vor dem PR: die volle Suite genau einmal.** Nicht dreimal „zur Sicherheit".
Wer die volle Suite als Zwischenschritt benutzt, verbrennt pro Runde eine
Viertelstunde Wanduhr — genau der Verbrauch, den das Skript abstellen sollte.

**Ein Lauf ist ein Nachweis, wenn er zweimal hintereinander null Rot zeigt.**
Ein einzelnes Grün ist eine Momentaufnahme.

**Wer eine rote Journey sieht, lässt sie zuerst allein laufen.** Erst wenn sie
das auch tut, ist sie ein Befund. Zwei bekannte Wackelkandidaten, beide
nachgemessen:

| Journey | Beobachtung |
|---|---|
| `AddFlowJourneyTests` (ganze Klasse) | Tastaturfokus. Im seriellen Grundlauf vom 08.08. fiel `testAnOlderTileTakesThePanelBackAndTypingGoesOn` mit „Neither element nor any descendant has keyboard focus" — auf einer **völlig unbelasteten** Maschine. |
| `OfferHitsJourneyTests.testTheRowLeadsToTheMatchesOfThisList` | Fiel am 09.08. in einem parallelen Lauf, **allein danach dreimal grün**. Derselbe Test hatte schon die grösste Verlangsamung unter Last (14,0 s → 20,1 s). |

**Die Suite wackelt also mit und ohne Klone.** Der Grundlauf hatte einen roten
Test, ein paralleler Lauf hatte einen — das ist dieselbe Grössenordnung und
kein Argument gegen die Verteilung. Es ist ein Argument dafür, ein einzelnes
Grün nicht für einen Beweis zu halten.

## Warum es schnell ist — und was nachweislich nichts gebracht hat

**Der ganze Hebel sind parallele Klone.** `-parallel-testing-enabled YES`
verteilt die Testklassen auf mehrere Simulator-Klone. Die Suite ist ein Rudel
unabhängiger App-Starts, und ein einzelner Simulator lastet diesen Mac (M1,
8 Kerne) nicht aus.

**Die Untergrenze ist die längste Klasse, nicht die Summe** — verteilt wird je
Klasse, nicht je Test. Gemessen am 08.08. im seriellen Grundlauf:

| Klasse | Testzeit | Tests |
|---|---|---|
| `OnboardingJourneyTests` | 399 s | 16 |
| `TutorialJourneyTests` | 384 s | 16 |
| `AccessibilityAuditTests` | 303 s | 7 |
| `PerformanceJourneyTests` | 243 s | 4 |
| alle übrigen | je 20–162 s | |
| **Summe UI** | **2 950 s** | **146** |

Wer eine neue Klasse anlegt, die allein sechs Minuten läuft, hebt damit die
Untergrenze des ganzen Laufs. Lieber zwei Klassen.

### Warum drei Klone und nicht vier

Naheliegend wäre, bei acht Kernen vier Klone zu fahren. Gemessen am 08.08. auf
diesem Mac (M1, 8 Kerne, 16 GB) ist das **schlechter**, und zwar dreifach:

| | 3 Klone | 4 Klone |
|---|---|---|
| UI-Tests je Minute | **8,8** | 7,3 |
| Auslagerung (`vm.swapusage`) | unauffällig | **3,5 GB von 4 GB belegt** |
| „Failed to launch …xctrunner" | **0** | 1 |

Der vierte Klon macht die anderen drei langsamer, statt etwas dazuzulegen — die
Maschine lagert aus, und die Zeit geht in die Auslagerung statt in Tests. Der
Lauf mit vier Klonen war zwar auf dem Papier schneller (25:03), meldete sich
aber **rot**, ohne dass ein einziger Test etwas dagegen hatte: Ein
Test-Runner ließ sich unter dem Speicherdruck nicht starten, und der Durchgang
endete mit `** TEST EXECUTE FAILED **` bei null roten Tests.

Auf einer Maschine mit mehr Speicher ist die Zahl anzuheben — mit einer Messung,
nicht mit der Kernzahl.

**Und eine Falle beim Nachmessen:** Bei vier gleichzeitigen Schreibern
zerschneiden sich die Protokollzeilen gegenseitig —

    Test case 'ContextTipJourneyTests.testTheNextWeek2026-08-08 23:52:47.786 xcodebuild[…]

Wer Tests im Protokoll *zählt*, hält so einen zerhackten Treffer für einen nicht
gelaufenen Test. Der Test war gelaufen. Im Zweifel das `.xcresult` lesen und
nicht das Protokoll.

### Was gemessen und verworfen wurde

Zwei naheliegende Hebel sind ausprobiert und **wieder ausgebaut** worden. Beide
stehen hier, damit sie nicht in einem halben Jahr noch einmal gebaut werden.

**Bewegung im Zeitraffer — bringt nichts.** Die Vermutung war: XCUITest hält
nach jeder Geste an, bis die App still steht, also kostet jeder 0,3-s-Übergang
0,3 s Testzeit, ein paar tausend Mal. Zwei Fassungen, beide an
`OnboardingJourneyTests` gemessen (der übergangsreichsten Klasse der Suite,
16 Tests, seriell, gleiches Ziel):

| Fassung | Testzeit |
|---|---|
| unverändert | 398,9 s |
| `CALayer.speed = 8` am Fenster | 387,8 s |
| SwiftUI-Animationen **ganz aus** (`disablesAnimations`) | 389,9 s |

**Knapp 2 % — Rauschen.** Und der dritte Fall ist der entscheidende: Selbst bei
komplett abgeschalteter Bewegung ändert sich nichts. Die Zeit steckt also nicht
in Animationen, sondern im App-Start, im Zustellen der Gesten und im Abfragen
des Barrierefreiheits-Baums. Ein Testpfad, der 2 % kauft und dafür eine zweite
Bewegungswirklichkeit in die App einbaut, ist ein schlechtes Geschäft.

**Fristen kürzen — bringt fast nichts und kostet Verlässlichkeit.** 174-mal
steht `timeout: 15` im Bestand, das sieht nach viel aus. Eine Frist kostet aber
nur Zeit, wenn sie **ausläuft**, und dann ist der Test rot und die Frist hat
ihre Arbeit getan. Wirklich verbrannt wird Zeit nur dort, wo eine Abwesenheit
geprüft wird — `XCTAssertFalse(x.waitForExistence(timeout: n))` wartet immer
voll:

| Posten | Vorkommen | Wanduhr je vollem Lauf |
|---|---|---|
| Abwesenheitsprüfungen | 20 | 86 s |
| `Thread.sleep` (Schonfristen des Rundgangs) | 10 | 12 s |

Rund 1,6 Minuten von 50, also **3 %**. Dafür jede dieser Zahlen anzufassen
hieße, Sekunden mit Wackelkontakt zu kaufen. Die Wartelogik in
`KeyboardWait.swift` (`tapAndAwaitKeyboard`, `tippe` mit `isHittable`) ist
unverändert geblieben: Die steht dort, weil sie einen echten Fehlschlag
verhindert, und ist Korrektheit, nicht Langsamkeit.

**Merksatz aus beidem: Was großzügig aussieht, ist nicht dasselbe wie was teuer
ist.** Beide Hebel klangen plausibel, beide waren in einer Viertelstunde
widerlegt — und beide hätten ohne Messung echten Code hinterlassen.

## Die drei Klassen, die allein laufen

`tools/tests.sh` fährt dafür einen zweiten, seriellen Durchgang.

**`PerformanceJourneyTests`** — das Messgeschirr vergleicht CPU- und
Speicherzahlen gegen Grundwerte aus `tools/perf-baseline.json`, aufgenommen auf
diesem Mac im Leerlauf. Neben zwei weiteren Simulatoren gemessen wären sie eine
Aussage über die Auslastung und über nichts sonst.

**`TermGridJourneyTests`** — die wird unter Last nicht langsamer, sie kippt um.
`testNothingMovesUnderTheThumbWhileTyping` zählt je Buchstabe alle Knöpfe mit
`buttons.matching(…).count`:

| | Testzeit |
|---|---|
| allein | 9,4 s |
| neben zwei Klonen | **552,5 s** |

**Die beiden Nachbartests derselben Klasse liefen auf demselben Klon in 11 s
und 12 s** — es liegt also an der Abfrage, nicht am Klon. `.firstMatch` darf
abbrechen, sobald es etwas gefunden hat; `.count` muss jeden Treffer wirklich
holen, und das heißt den ganzen Barrierefreiheits-Baum über die Prozessgrenze,
fünfmal, bei stehender Tastatur. Jede andere Stelle im Bestand benutzt
`.firstMatch`.

Serialisiert und nicht umgeschrieben: Die Zählung ist dort der Beweis, dass die
Probe überhaupt etwas beweist („die Trefferzahl muss sich unterwegs geändert
haben"). Wer sie billiger macht, muss erst zeigen, dass sie dasselbe prüft.

**Merksatz für neue Journeys: `.count` auf einer Prädikat-Abfrage ist auf einer
belegten Maschine kein billiger Handgriff.** Wenn es geht, `.firstMatch` oder
eine Abfrage über den Bezeichner.

**`TileGestureJourneyTests`** — derselbe Befund aus der anderen Richtung.
`testATapChecksTheItemWithoutWaitingForALongPress` prüft, dass ein **kurzer**
Tipp abhakt, ohne auf den langen Druck zu warten: eine Zusicherung über die
Frist zwischen zwei Gesten. Auf drei Klonen fiel er am 09.08. **zweimal von
zwei** Versuchen, allein auf einem Simulator ist er grün.

**Merksatz: Wer eine Gestendauer zusichert, misst unter Last die Last.** Solche
Journeys gehören in den seriellen Durchgang — oder ihre Zusicherung gehört so
umgeschrieben, dass sie nicht an der Wanduhr hängt.

Der Rundgang (`TutorialJourneyTests`, `TourTargetJourneyTests`) gehört
ausdrücklich **nicht** dorthin: Er misst Geometrie — wo das wandernde Loch nach
dem Einschwingen liegt —, und die hängt nicht an der Auslastung. Seine
Schonfristen sind `Thread.sleep`, also Wanduhr, und die läuft auf einem Klon
genauso.

Die Liste steht in `tools/tests.sh` (`SERIELL`) und ist absichtlich kurz zu
halten: Jeder Eintrag wandert aus dem parallelen Durchgang in einen zweiten,
seriellen und kostet damit volle Wanduhr.

## Das Gerät ist Teil des Ergebnisses

Am 09.08. waren zwei Journeys auf `main` rot, und zwar hartnäckig: auch seriell,
auch auf einem einzigen Simulator. Die Ursache war **kein** Code — es war das
Gerät. Dieselbe Binärdatei, vier Simulatoren:

| Gerät | `testAWholeTileRow…` | `testTheReviewNote…` |
|---|---|---|
| iPhone 17 Pro, iOS 26.2 | ✅ | ✅ |
| iPhone 17 Pro, iOS **26.1** | ❌ | ❌ |
| iPhone 16e | ❌ | — |
| iPhone SE 3 | ❌ | — |

Die Tastatur unter iOS 26.1 ist **10 pt höher** als unter 26.2. Damit war der
Platz über dem Angaben-Block um 10 pt kleiner, und die Kachelreihe passte nicht
mehr darüber — auf dem 17 Pro/26.2 ging sie mit **1 pt** auf, auf dem SE fehlten
**81 pt**. Beide Journeys hingen daran; die Anmerkungs-Journey zusätzlich an
einem `swipeUp`, das seit dem hohen Panel in der Schicht beginnt statt auf der
Liste. Repariert in [#95](https://github.com/Scxttk/lechariot-app/pull/95):
Die Angaben-Schicht nimmt so viele Chipreihen, wie neben einer ganzen
Kachelreihe Platz haben.

**Was daraus für Journeys folgt:** Eine Zusicherung, die eine gemessene Zahl
festhält, gilt zunächst nur auf dem Gerät, auf dem gemessen wurde. Zwei stehen
noch so da und sind bewusst nicht angefasst worden, weil die Suite auf dem
17 Pro läuft:

- `testTheThreeZonesMatchTheReference` — die Anteile 20,5 / 44,8 / 34,7 % gelten
  für 874 pt Fenster und 233 pt Tastatur. Auf allem anderen überspringt der Test
  sich jetzt mit Begründung, statt eine falsche Zahl zu behaupten.
- `testAWholeTileRowStaysAboveTheBlock` prüft `minY >= 44` — die Statusleiste
  eines Geräts mit Dynamic Island. Auf einem iPhone SE sind es 20, und der Test
  fällt dort, obwohl die Kachel korrekt sitzt.

## Der Nachweis auf geliehenen Macs

`.github/workflows/suite.yml` fährt dieselbe Suite auf GitHubs macOS-Runnern.
Das Repo ist öffentlich, also kostet das nichts ausser Wartezeit — und die
Wartezeit ist nicht Scotts Mac. Der bleibt frei fürs Iterieren; genau das war
der Zweck.

**`tools/tests.sh` bleibt und bleibt unverändert.** Offline, ohne Warteschlange,
mit Bilderbögen und mit dem Messgeschirr. Der Workflow ersetzt nicht das
Arbeiten, sondern den einen vollen Lauf vor dem PR.

### Wie verteilt wird

Ein Job baut, drei laufen. Verteilt wird **je Klasse** — dieselbe Körnung wie
lokal, nur über Maschinen statt über Klone:

| Job | was er tut |
|---|---|
| `verteilen` | Ubuntu. Rechnet aus, welche Klasse auf welche Scherbe geht. |
| `bauen` | `build-for-testing` **einmal**, dann die Unit-Tests. Das Ergebnis geht als Tar an die Scherben. |
| `journeys` | Drei Runner, je ein Drittel der Journeys. Scherbe 1 hängt den seriellen Durchgang hinten dran. |
| `urteil` | Ubuntu. Liest die Befunde und fällt **ein** Urteil. |

Die Verteilung ist „grösste Klasse zuerst auf die leerste Scherbe" (LPT), und
das Gewicht einer Klasse ist die **Zahl ihrer Testmethoden**. Eine Kostentabelle
wäre genauer — `AccessibilityAuditTests` kostet je Test 43 s,
`OnboardingJourneyTests` 25 s — und stünde in einem halben Jahr falsch im Repo.
Die Zahl der Methoden ist grob und stimmt immer. Ob die Grobheit reicht, sagt
der Lauf selbst: `urteil` druckt je Scherbe die Wanduhr.

Die Untergrenze bleibt dieselbe wie lokal: **die längste einzelne Klasse.** Wer
eine anlegt, die allein sechs Minuten läuft, hebt damit die Untergrenze — lieber
zwei Klassen.

### `PerformanceJourneyTests` läuft dort nicht

Als einzige Klasse ist sie ausgeschlossen (`OHNE_CI` in `tools/testlauf.sh`).
Sie vergleicht CPU- und Speicherzahlen gegen `tools/perf-baseline.json` —
Grundwerte von Scotts Mac im Leerlauf. Auf drei geliehenen Kernen wäre jede
dieser Zahlen eine Aussage über den Nachbarn im Rechenzentrum. Die Klasse sagt
das seit dem 01.08. selbst in ihrem Kopfkommentar.

Ausgeschlossen und nicht stillschweigend geduldet: Ein Messstand, dem niemand
glaubt, wird abgeschaltet statt gelesen — und eine Ampel, die in jedem zweiten
PR grundlos rot ist, erzieht dazu, rote Ampeln zu überblättern.

### Gerät und Fassung sind genagelt

| | Scotts Mac | Runner |
|---|---|---|
| Xcode | 26.3 | Vorgabe **26.6**, genagelt auf 26.3 |
| iOS-Laufzeiten | 26.1, 26.2 | 26.2, 26.4, **26.5** |
| Ziel | `iPhone 17 Pro, OS=latest` → 26.2 | `OS=latest` wäre **26.5**, genagelt auf 26.2 |

`OS=latest` heisst auf dem Runner etwas anderes als hier. Das ist keine
Kleinigkeit, sondern genau der Befund vom 09.08.: Die Tastatur unter iOS 26.1
ist 10 pt höher als unter 26.2, und daran hingen zwei rote Journeys auf `main`
(siehe [Das Gerät ist Teil des Ergebnisses](#das-gerät-ist-teil-des-ergebnisses)).
Zwei Zusicherungen der Suite halten ausserdem Zahlen fest, die für dieses Gerät
gelten. Der Workflow sagt deshalb, was er meint.

### Geurteilt wird nach Tests, nicht nach Ampeln

Dieselbe Regel wie lokal, und auf einem geliehenen Mac eher noch wichtiger.
Jede Scherbe schreibt ihren Befund in eine Datei; `.github/urteil.sh` liest die
Dateien. **Rot** ist ein Lauf nur, wenn eines davon zutrifft:

1. Ein Test ist gefallen und im zweiten Anlauf nicht wieder aufgestanden
   (`-retry-tests-on-failure -test-iterations 2`, wie lokal).
2. Eine Klasse aus dem Quellbaum hat **keinen einzigen Test gemeldet**.

Der zweite Punkt ist die Gegenprobe zum Freispruch im ersten. Lokal vergleicht
`tools/tests.sh` dafür die Testzahl mit dem letzten Lauf *dieser Maschine*; auf
einem Runner gibt es kein „letztes Mal". Der Sollwert kommt deshalb aus
`tools/testlauf.sh soll`, also aus demselben Quellbaum wie die Tests — und er
fängt beides: den ausgefallenen Arbeiter und die ganze Scherbe, deren Job
gestorben ist. (Bewusst nicht aus den Befunden: Ein fehlender Befund prüfte
sich sonst selbst.)

Alles andere — ein Runner, der beim Klon-Start stolpert, ein Durchgang, der
Fehlschlag meldet, ohne dass eine Zusicherung gefallen ist — wird gemeldet und
nicht bestraft. Wer nur im zweiten Anlauf grün wurde, steht namentlich in der
Zusammenfassung.

## Wenn etwas kaputt aussieht

**„Timed out while loading Accessibility"** ist ein kaputter Simulator, kein
kaputter Test. Das Gerät neu anlegen:

```sh
xcrun simctl delete "iPhone 17 Pro" && xcrun simctl create "iPhone 17 Pro" "iPhone 17 Pro"
```

**„Timed out while synthesizing event"** heißt fast immer, dass die Maschine
belegt ist. Das Skript warnt beim Start, wenn ein Prozess über 15 % CPU nimmt.
Dann `--workers 2` oder warten. Am 02.08. lief Côte d'OS mit ~30 % CPU durch
eine Messung, und die Suite brauchte 7,5 Stunden statt einer halben.

**Mehrere Sitzungen teilen sich diesen Mac.** Das Skript weigert sich von
selbst, wenn schon ein Testlauf läuft, und räumt vorher Klone eines
abgebrochenen Laufs weg (nur Xcodes eigenes Klon-Verzeichnis
`~/Library/Developer/XCTestDevices` — die Simulatoren im Simulator.app gehören
dem Menschen).

Ohne diese Vorprüfung sah es am 08.08. so aus: Ein Lauf startete, während die
Klone des vorigen noch heruntergefahren wurden, bekam

    Simulator device failed to launch …xctrunner
    … denied … for reason: Busy ("Application failed preflight checks")

verlor damit einen ganzen Arbeiter samt seiner Klassen und meldete sich nach
34:23 rot — **bei null roten Tests**. Zwei volle Suiten gleichzeitig sind nicht
nur langsamer als zwei nacheinander, sie sind unbrauchbar.

**Merksatz: Ein roter Lauf ist nicht dasselbe wie ein roter Test.** Das Skript
sagt es beim Fehlschlag von selbst:

    ⚠ Durchgang rot, aber **kein einziger Test** ist gefallen —
      das ist der Simulator, nicht die App.

Wer diese Zeile sieht, sucht nicht in der App.

**Der häufigste Grund dafür ist ein Wettlauf beim Klon-Start.** Xcode legt die
Klone an und spielt die Runner-App auf; greift der Start zu früh, kommt

    Failed to launch …xctrunner
    NotFound ("Unknown application display identifier …xctrunner")

Der Lauf am 09.08. hatte **790 grüne Tests, null rote** — und meldete sich
trotzdem rot, weil dieser eine Start misslang.

**Wie oft das vorkommt, ist gezählt und nicht geschätzt:** in vier von sechs
Läufen am 08./09.08. genau einmal je Lauf. Meistens fängt Xcode ihn selbst ab
und der Lauf endet trotzdem grün; manchmal reisst er den Durchgang mit. Es gibt
ihn in zwei Geschmacksrichtungen — `NotFound` („Unknown application display
identifier") und `Busy` („Application failed preflight checks") —, beide
derselbe Wettlauf beim Klon-Start.

Woran es genau liegt, ist **nicht** geklärt; eine naheliegende Vermutung
(frisch gelöschtes Zielgerät) ist am nächsten Lauf gescheitert, der dasselbe auf
einem warmen Gerät tat.

**Wiederholt wird deshalb nicht — es wurde ausprobiert und war Verschwendung.**
Am 09.08. lief ein Durchgang alle 139 Journeys durch, null gefallen, und meldete
Fehlschlag. Wiederholt lief er noch einmal alle 139 durch, null gefallen, und
meldete wieder Fehlschlag. Zwanzig Minuten für nichts.

**Also wird nach dem geurteilt, was stimmt.** Der Rückgabewert von `xcodebuild`
ist auf dieser Maschine unter Klonen unzuverlässig, die Testergebnisse sind es
nicht:

> **Rot ist ein Lauf, in dem ein Test gefallen ist.** Alles andere ist
> Simulator-Rauschen und wird gemeldet, nicht bestraft.

Damit das kein Freibrief ist, zählt das Skript am Ende, **wie viele Tests
gelaufen sind**, und vergleicht mit dem letzten Lauf auf dieser Maschine. Sinkt
die Zahl, ist ein Arbeiter samt seiner Klassen ausgefallen — das ist dann sehr
wohl rot. Genau dieser Fall trat am 08.08. einmal ein (138 statt 139 Journeys,
stillschweigend) und wäre sonst als grün durchgegangen. Ein Sollwert im Repo
stünde hier nicht: Der veraltet beim ersten neuen Test und wäre dann ein
Wächter, dem niemand mehr glaubt.

**Ein hängender Test kann nicht mehr eine Nacht kosten.** Der Lauf trägt
`-test-timeouts-enabled YES` mit zehn Minuten je Test — der längste echte Test
der Suite braucht 99 s. In der Nacht zum 09.08. stand `PerformanceJourneyTests`
**7,2 Stunden** in „Wait for com.skoehler.lechariot to idle" (`t = 25921s`),
bei wacher Maschine und hinüberem Simulator. Auf einem frisch angelegten Gerät
lief derselbe Test danach in 66 s durch.

**Und eine Falle beim Zusehen:** Das Protokoll wird in 16-KB-Blöcken
geschrieben. Ein Lauf, der „seit zehn Minuten keinen Test mehr meldet", ist fast
immer nur gepuffert. Ob wirklich etwas hängt, verrät der `t = …s`-Zähler in der
Aktivitätszeile — der zählt weiter, auch wenn nichts vorangeht.
