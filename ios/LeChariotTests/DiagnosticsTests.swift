import XCTest
@testable import LeChariot

/// **Das Messwerkzeug vom 02.08. — der Teil, der ohne Gerät prüfbar ist.**
///
/// Die Rechnung hinter der Live-Anzeige, die Ablage der Tagesberichte und das
/// Tor davor. Was sich nur am Gerät zeigt (Apples Pakete, ein echter
/// `CADisplayLink`), steht hier bewusst nicht.
final class HitchMeterTests: XCTestCase {

    /// **Ein Ruckler ist die Zeit, die ein Bild zu spät kam** — nicht das Bild.
    func testHitchTimeIsTheLatenessNotTheFrame() {
        // 20 ms statt der erlaubten 8,3 → 11,7 ms zu spät.
        XCTAssertEqual(HitchMeter.hitchTime(duration: 0.020, expected: 0.0083), 0.0117, accuracy: 1e-6)
    }

    /// **Ein schnelles Bild gleicht kein Ruckeln aus.** Ohne diese Regel macht
    /// eine einzelne flotte Zeichnung aus einer ruckeligen Strecke eine glatte
    /// — und die Anzeige meldete Ruhe, wo Scott ein Stocken sieht.
    func testAFastFrameDoesNotPayBackAHitch() {
        XCTAssertEqual(HitchMeter.hitchTime(duration: 0.004, expected: 0.0083), 0)
    }

    func testAnEmptyMeterSaysNothingRatherThanZero() {
        let meter = HitchMeter()
        XCTAssertNil(meter.fps, "0 fps wäre eine Aussage; „noch nichts gemessen“ ist keine")
        XCTAssertNil(meter.hitchMillisecondsPerSecond)
    }

    /// Ein glatter 120-Hz-Lauf: 120 Bilder in einer Sekunde, keine Ruckelzeit.
    func testASmoothRunReportsItsRateAndNoHitching() {
        var meter = HitchMeter()
        for _ in 0..<120 { meter.record(duration: 1.0 / 120, expected: 1.0 / 120) }
        XCTAssertEqual(meter.fps ?? 0, 120, accuracy: 1.0)
        XCTAssertEqual(meter.hitchMillisecondsPerSecond ?? -1, 0, accuracy: 0.001)
        XCTAssertFalse(meter.isNoticeable)
    }

    /// Ein einzelnes 100-ms-Bild in einer Sekunde ist genau der Fall, den man
    /// als Stocken sieht — und er muss über Apples Schwelle liegen.
    func testOneLongFrameShowsUpAsNoticeableHitching() {
        var meter = HitchMeter()
        for _ in 0..<108 { meter.record(duration: 1.0 / 120, expected: 1.0 / 120) }
        meter.record(duration: 0.100, expected: 1.0 / 120)
        let hitch = meter.hitchMillisecondsPerSecond ?? 0
        XCTAssertGreaterThan(hitch, HitchMeter.noticeableHitchMsPerSecond)
        XCTAssertTrue(meter.isNoticeable)
    }

    /// Das Fenster ist eine Sekunde — was davor war, zählt nicht mehr, sonst
    /// klebt ein Ruckler von vorhin an einer Anzeige, die gerade ruhig ist.
    func testTheWindowForgetsWhatIsOlderThanASecond() {
        var meter = HitchMeter()
        meter.record(duration: 0.500, expected: 1.0 / 120)   // ein grober Ruckler
        for _ in 0..<120 { meter.record(duration: 1.0 / 120, expected: 1.0 / 120) }
        XCTAssertEqual(meter.hitchMillisecondsPerSecond ?? -1, 0, accuracy: 0.001,
                       "nach einer ruhigen Sekunde darf der alte Ruckler nicht mehr mitzählen")
    }
}

final class MetricsArchiveTests: XCTestCase {
    private func entry(_ day: Double, _ art: MetricsEntry.Art = .messwerte) -> MetricsEntry {
        MetricsEntry(bis: Date(timeIntervalSince1970: day * 86_400),
                     json: Data("{\"tag\":\(day)}".utf8), art: art)
    }

    /// **Apple liefert dasselbe Paket nach einem Neustart gern noch einmal.**
    /// Zwei gleiche Tage nebeneinander lesen sich wie zwei Tage.
    func testTheSamePayloadTwiceStaysOneEntry() {
        let merged = MetricsArchive.merge(existing: [entry(1)], new: [entry(1)])
        XCTAssertEqual(merged.count, 1)
    }

    /// Messwerte und Befunde vom selben Zeitpunkt sind **zwei** Berichte —
    /// Hänger stehen in einem anderen Paket als Bilder je Sekunde.
    func testMetricsAndDiagnosticsOfTheSameDayAreTwoEntries() {
        let merged = MetricsArchive.merge(existing: [], new: [entry(1, .messwerte), entry(1, .befunde)])
        XCTAssertEqual(merged.count, 2)
    }

    func testTheNewestReportComesFirst() {
        let merged = MetricsArchive.merge(existing: [entry(1)], new: [entry(3), entry(2)])
        XCTAssertEqual(merged.map(\.bis), [entry(3).bis, entry(2).bis, entry(1).bis])
    }

    /// Der Deckel greift von hinten: Was wegfällt, ist das Älteste.
    func testTheArchiveKeepsItsLimitAndDropsTheOldest() {
        let many = (1...80).map { entry(Double($0)) }
        let merged = MetricsArchive.merge(existing: [], new: many)
        XCTAssertEqual(merged.count, MetricsArchive.limit)
        XCTAssertEqual(merged.first?.bis, entry(80).bis)
        XCTAssertEqual(merged.last?.bis, entry(80 - Double(MetricsArchive.limit) + 1).bis)
    }

    /// **Apples JSON wird nicht neu verpackt.** Wer es in ein eigenes Format
    /// gießt, verliert die Felder, die Apple nächstes Jahr dazulegt.
    func testTheExportIsApplesOwnJSONInAnArray() {
        let data = MetricsArchive.export([entry(1), entry(2)])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("{\"tag\":1.0}"))
        XCTAssertTrue(text.contains("{\"tag\":2.0}"))
        // Und es ist gültiges JSON, nicht nur aneinandergeklebt.
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testAnEmptyExportIsStillValidJSON() {
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: MetricsArchive.export([])))
    }

    /// Über die Platte hin und zurück — die Ablage ist eine Datei, kein
    /// `UserDefaults`.
    func testWhatIsSavedComesBack() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("metrics-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let archive = MetricsArchive(url: url)

        XCTAssertTrue(archive.load().isEmpty)
        archive.append([entry(1), entry(2)])
        XCTAssertEqual(archive.load().count, 2)
        archive.clear()
        XCTAssertTrue(archive.load().isEmpty)
    }
}

@MainActor
final class DiagnosticsGateTests: XCTestCase {
    private func freshGate() -> (DiagnosticsGate, UserDefaults) {
        let name = "diagnostics-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (DiagnosticsGate(defaults: defaults), defaults)
    }

    /// **Der Prüfpunkt für „unsichtbar für Tester".** Ohne die Geste gibt es
    /// keinen Eintrag und keine Anzeige.
    func testEverythingIsOffUntilSomeoneKnowsTheGesture() {
        let (gate, _) = freshGate()
        XCTAssertFalse(gate.isRevealed)
        XCTAssertFalse(gate.isHUDVisible)
    }

    func testTheGestureRevealsItAndItSurvivesARestart() {
        let (gate, defaults) = freshGate()
        gate.reveal()
        XCTAssertTrue(gate.isRevealed)
        // Ein zweites Tor auf demselben Speicher ist der nächste App-Start.
        XCTAssertTrue(DiagnosticsGate(defaults: defaults).isRevealed,
                      "die Geste jedes Mal zu brauchen wäre Schikane für den Einzigen, der sie kennt")
    }

    /// Sichtbar heißt **nicht** an: Ein Overlay, das mit dem Bildschirm angeht,
    /// verdeckt genau das, was man ansehen wollte.
    func testRevealingDoesNotSwitchTheOverlayOn() {
        let (gate, _) = freshGate()
        gate.reveal()
        XCTAssertFalse(gate.isHUDVisible)
    }

    /// Wieder verstecken schaltet die Anzeige mit ab — sonst bliebe sie stehen,
    /// und ihr Schalter wäre nicht mehr erreichbar.
    func testHidingAlsoSwitchesTheOverlayOff() {
        let (gate, _) = freshGate()
        gate.reveal()
        gate.isHUDVisible = true
        gate.hide()
        XCTAssertFalse(gate.isRevealed)
        XCTAssertFalse(gate.isHUDVisible, "eine Anzeige ohne erreichbaren Schalter wäre eine Falle")
    }
}
