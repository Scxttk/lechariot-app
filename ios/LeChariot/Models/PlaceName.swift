import Foundation

/// **Wie ein Ort heißt, wenn man ihn nicht als fünfstellige Zahl schreibt.**
///
/// Scotts Fund vom 02.08.: Die App zeigte „17389". Das ist die Zahl, mit der
/// wir suchen — aber niemand steht in einer Postleitzahl, man steht in Anklam,
/// und wenn es genauer geht, in der Friedländer Straße.
///
/// Reine Rechnung über Zeichenketten, nicht über `CLPlacemark`: So ist jede
/// Regel prüfbar, ohne einen Geocoder zu befragen. Die Felder kommen aus
/// `CLPlacemark`, die Entscheidung fällt hier.
enum PlaceName {
    /// Der Name einer **Region** — also einer PLZ, die für eine ganze Stadt
    /// steht. Straßen haben hier nichts zu suchen: Die Region ist nicht die
    /// Straße, in der jemand gerade steht.
    ///
    /// Stadtteil nur, wenn er die Stadt nicht wiederholt — Apple liefert für
    /// Anklam `locality` **und** `subLocality` als „Anklam", und „Anklam
    /// Anklam" ist keine Verbesserung gegenüber der Zahl.
    static func region(locality: String?, subLocality: String?, plz: String) -> String {
        guard let city = clean(locality) else { return plz }
        if let quarter = clean(subLocality), quarter != city {
            return "\(city) \(quarter)"
        }
        return city
    }

    /// Der Name eines **Punktes** — was unter dem Gerät liegt. Hier ist die
    /// Straße das Genaueste, was der Geocoder hergibt, und genau das hat Scott
    /// sich gewünscht („Südstraße 7").
    ///
    /// Reihenfolge: Straße (mit Hausnummer, wenn vorhanden) → Stadtteil →
    /// Stadt → PLZ. Jede Stufe nennt die Stadt mit, sonst steht da eine Straße
    /// ohne Ort — in einer App, die mehrere Gegenden kennt, ist das eine
    /// Fangfrage.
    static func position(
        locality: String?,
        subLocality: String?,
        thoroughfare: String?,
        subThoroughfare: String?,
        plz: String
    ) -> String {
        let city = clean(locality)
        if let street = clean(thoroughfare) {
            let number = clean(subThoroughfare)
            let address = number.map { "\(street) \($0)" } ?? street
            return city.map { "\($0), \(address)" } ?? address
        }
        if let quarter = clean(subLocality), let city, quarter != city {
            return "\(city) \(quarter)"
        }
        return city ?? plz
    }

    /// Leere und aus Leerzeichen bestehende Antworten des Geocoders zählen
    /// nicht — sie kommen vor und lesen sich sonst als „ , ".
    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
