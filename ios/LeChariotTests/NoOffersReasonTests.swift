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
