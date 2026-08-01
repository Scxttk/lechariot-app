import XCTest
@testable import LeChariot

final class FeatureFlagsTests: XCTestCase {
    /// **Voreinstellung AN seit 2026-08-01.** Die Bedingung für das Umlegen war
    /// nicht „fertig gebaut", sondern „genug Ketten liefern": Vorher füllten nur
    /// Penny und NORMA die Vorschau, jetzt zusätzlich Kaufland, Lidl und
    /// ALDI Nord. Wo eine gewählte Kette nichts hat, nennt `NextWeekView` den
    /// Grund — eine leere Zusage entsteht dadurch nicht.
    ///
    /// Die **Trennung** von laufender Woche und Folgewoche hängt ausdrücklich
    /// nicht am Schalter — sie ist ein Fehlerfix und liegt in
    /// `WeekBoundaryTests`.
    func testTheNextWeekPreviewIsOnByDefault() {
        XCTAssertTrue(FeatureFlags.nextWeekPreview)
    }
}
