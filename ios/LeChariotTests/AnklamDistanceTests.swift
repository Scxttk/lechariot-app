import XCTest
@testable import LeChariot

/// **Der Verdacht war falsch, und das ist der Befund.**
///
/// Scott meldete am 02.08.: „Entfernungen zu groß — eine Stadt ist keine 10 km
/// groß", mit dem Verdacht, die App messe vom Gebiets-Anker statt vom echten
/// Standort. Nachgemessen mit Apples Geocoder am selben Tag:
///
/// - Mitte der PLZ 17389: **53,8468601 / 13,6948483**
/// - Penny Friedländer Straße (Scotts Standort): 53,85032 / 13,69157
/// - Abstand der beiden: **0,44 km**
///
/// Der Bezugspunkt kann eine Abweichung von 10 km also gar nicht erzeugen. Die
/// 10,5 km waren echt: Das Netto in Ducherow war an diesem Tag der
/// zweitnächste Markt, den das Verzeichnis überhaupt kannte — in Anklam selbst
/// stand nur der bundesweite Penny. Nicht die Rechnung war falsch, **die Liste
/// war leer**, und der Picker weitet auf bis zu 40 km, wenn zu wenig da ist.
///
/// Diese Zahlen stehen als Test, damit die widerlegte Vermutung nicht
/// wiederkommt: Wer die Entfernungsrechnung „repariert", muss hier erklären,
/// was er eigentlich behebt.
final class AnklamDistanceTests: XCTestCase {
    private let plzMitte17389 = (lat: 53.8468601, lon: 13.6948483)
    private let penny = (lat: 53.85032, lon: 13.69157)
    private let nettoDucherow = (lat: 53.7659278, lon: 13.7781329)

    func testThePostcodeCentreIsPracticallyWhereScottStood() {
        let delta = Geo.distanceKm(from: plzMitte17389, to: penny)
        XCTAssertEqual(delta, 0.44, accuracy: 0.05)
        XCTAssertLessThan(delta, 1.0, "der Anker kann keinen Kilometerfehler erklären")
    }

    /// Dieselbe Filiale, von beiden Punkten aus gemessen: Der Unterschied ist
    /// ein halber Kilometer, nicht zehn.
    func testTheAnchorChangesTheNumberByLessThanHalfAKilometre() {
        let fromCentre = Geo.distanceKm(from: plzMitte17389, to: nettoDucherow)
        let fromUser = Geo.distanceKm(from: penny, to: nettoDucherow)
        XCTAssertEqual(fromCentre, 10.54, accuracy: 0.1)
        XCTAssertEqual(fromUser, 10.99, accuracy: 0.1)
        XCTAssertLessThan(abs(fromCentre - fromUser), 0.5)
    }

    /// Und die Gegenprobe für das, was wirklich fehlte: Nach dem Gebietslauf
    /// vom 02.08. stehen acht Märkte in Anklam, alle unter 2 km. Die Zahlen
    /// stammen aus `branches` in der Produktion.
    func testAfterTheAreaRunEveryStoreIsWithinWalkingDistance() {
        let anklamStores = [
            ("Netto Anklam 7517", 53.8563, 13.6934),
            ("REWE Patzer", 53.8598, 13.6839),
            ("ALDI Nord Anklam", 53.8593, 13.6816),
            ("Lidl Anklam", 53.8637, 13.6812),
        ]
        for (name, lat, lon) in anklamStores {
            let distance = Geo.distanceKm(from: penny, to: (lat, lon))
            XCTAssertLessThan(distance, 2.0, "\(name) liegt in der Stadt, nicht im Nachbarort")
        }
    }
}
