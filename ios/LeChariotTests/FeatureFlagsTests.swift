import XCTest
@testable import LeChariot

final class FeatureFlagsTests: XCTestCase {
    /// **Voreinstellung AUS.** Ohne diese Zusage darf der Zweig nicht gemergt
    /// werden: Er brächte einen Weg in die App, den heute nur zwei von neun
    /// Ketten füllen können.
    ///
    /// Die **Trennung** von laufender Woche und Folgewoche hängt ausdrücklich
    /// nicht am Schalter — sie ist ein Fehlerfix und liegt in
    /// `WeekBoundaryTests`.
    func testTheNextWeekPreviewIsOffByDefault() {
        XCTAssertFalse(FeatureFlags.nextWeekPreview)
    }
}
