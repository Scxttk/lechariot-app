import XCTest
@testable import LeChariot

/// **Die Ahlbeck-Lektion, zum zweiten Mal bezahlt.**
///
/// Am 30.07. las eine Filiale, deren Sync nie mitgezogen worden war,
/// „veröffentlicht seinen Prospekt nicht online" — falsch, sie lieferte.
/// Am 02.08. las in Anklam der frisch angeforderte Penny Friedländer Straße
/// denselben Satz, weil `.failed(.timedOut)` im selben Zweig stand wie
/// `.ready`. Anderthalb Minuten später trug dieselbe Filiale 283 Angebote.
///
/// Der Satz ist eine Aussage über den *Markt*. Er darf nur fallen, wenn wir
/// wirklich etwas über den Markt wissen — und das tun wir genau dann, wenn ein
/// Sync durchgelaufen ist und nichts gebracht hat.
final class NoOffersReasonTests: XCTestCase {
    private let publishesNothing = "Dieser Markt veröffentlicht seinen Prospekt nicht online."

    /// Die Regression. Gegen den Stand vor dem 02.08. fällt dieser Test.
    func testATimeoutNeverClaimsTheMarketPublishesNothing() {
        let text = NoOffersReason.text(for: .failed(.timedOut))
        XCTAssertNotEqual(text, publishesNothing)
        XCTAssertTrue(text.contains("noch unterwegs"), "sagt, dass gewartet wird — nicht, dass es nichts gibt")
        XCTAssertTrue(text.contains("Nachtlauf"), "nennt, wann es spätestens kommt")
    }

    /// Die Gegenrichtung: Für EDEKA Böse in Ahlbeck stimmt der Satz, und er
    /// muss stehen bleiben. Ein Fix, der ihn überall abschafft, wäre kein Fix.
    func testAFinishedSyncWithoutOffersStillSaysSo() {
        XCTAssertEqual(NoOffersReason.text(for: .ready), publishesNothing)
    }

    func testTheOtherStatesKeepTheirSentence() {
        XCTAssertTrue(NoOffersReason.text(for: .requested).contains("gerade geholt"))
        XCTAssertTrue(NoOffersReason.text(for: .syncing).contains("gerade geholt"))
        XCTAssertTrue(NoOffersReason.text(for: .unknown).contains("gleich geholt"))
        XCTAssertTrue(NoOffersReason.text(for: .failed(.network)).contains("Verbindung"))
    }

    // MARK: Der Prospekt, der erst morgen anfängt

    /// **Scotts Ahlbeck-Probe am Sonntag, 02.08.** REWE und Netto standen dort
    /// beide mit „veröffentlicht seinen Prospekt nicht online" — und trugen zur
    /// selben Zeit 254 bzw. 253 Zeilen in der Produktion, alle mit
    /// `valid_from = 03.08.`. Der Sync leert die Tabelle vor jedem Lauf, die
    /// neue Woche hatte noch nicht begonnen, und dazwischen ist die laufende
    /// Woche leer.
    ///
    /// **Das ist jeder Sonntagabend, nicht ein Sonderfall** — und der vierte
    /// Fall desselben Satzes über einen Markt, über den wir nichts wissen.
    /// Hier wissen wir sogar das Gegenteil: Der Prospekt liegt vor uns.
    func testAProspectusThatStartsTomorrowIsNotAMarketThatPublishesNothing() {
        let montag = Date(timeIntervalSince1970: 1_785_628_800)  // 2026-08-03
        let text = NoOffersReason.text(for: .ready, upcomingFrom: montag)
        XCTAssertNotEqual(text, publishesNothing)
        XCTAssertTrue(text.contains("Der neue Prospekt gilt ab"), text)
        XCTAssertTrue(text.contains("August"), "das Datum gehört in den Satz: \(text)")
    }

    /// Das Datum schlägt auch die Wartezustände: Wer den Prospekt schon sieht,
    /// braucht nicht zu hören, dass noch geholt wird.
    func testTheDateWinsOverEveryOtherState() {
        let montag = Date(timeIntervalSince1970: 1_785_628_800)
        for state in [BranchSyncState.requested, .syncing, .unknown, .failed(.timedOut), .ready] {
            XCTAssertTrue(
                NoOffersReason.text(for: state, upcomingFrom: montag).contains("Der neue Prospekt"),
                "Zustand \(state) hat das Datum überschrieben"
            )
        }
    }

    /// Und ohne kommenden Prospekt bleibt alles, wie es war — sonst hätte der
    /// Fix den Fall von heute Mittag gleich mit weggeräumt.
    func testWithoutAProspectusTheOldSentencesStand() {
        XCTAssertEqual(NoOffersReason.text(for: .ready, upcomingFrom: nil), publishesNothing)
    }

    // MARK: Die Fußnote unter der Liste

    /// „Nicht jeder Markt stellt seinen Prospekt ins Netz" ist dieselbe
    /// Behauptung in klein. Über eine Filiale, auf die wir noch warten, ist sie
    /// eine Ausrede — und sie stand bis zum 02.08. immer da.
    func testTheFooterStaysAwayWhileWeAreStillWaiting() {
        XCTAssertFalse(NoOffersReason.footerApplies(to: [.failed(.timedOut)]))
        XCTAssertFalse(NoOffersReason.footerApplies(to: [.requested, .syncing]))
        XCTAssertFalse(NoOffersReason.footerApplies(to: []))
    }

    func testTheFooterAppearsAsSoonAsOneBranchIsReallyDone() {
        XCTAssertTrue(NoOffersReason.footerApplies(to: [.ready]))
        XCTAssertTrue(NoOffersReason.footerApplies(to: [.failed(.timedOut), .ready]))
    }
}
