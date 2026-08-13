import CoreLocation
import Foundation

/// **Ortsname → PLZ, ausschließlich über Apples Geocoder.**
///
/// Dieselbe Zusage wie in `PlaceNameStore` und `PLZLocator`: Der getippte Name
/// geht an `CLGeocoder` und sonst nirgendwohin. **An unseren Server geht die
/// PLZ, nie der Name und nie eine Position.** Wer hier eine zweite Abfrage
/// einbaut, bricht das.
///
/// **Warum zwei Abfragen statt einer — am 03.08. gemessen, nicht vermutet:**
/// Der Vorwärts-Geocoder liefert auf einen blanken Ortsnamen **keine
/// `postalCode`**. Neun Namen probiert, neunmal `nil`; die PLZ steckt nur in
/// der *Rückwärts*-Antwort. Also: Name → Koordinate → PLZ. Wer den Weg
/// abkürzen will, bekommt `nil` und merkt es erst am Gerät.
enum CityLookup {
    enum Result: Equatable {
        /// Apple hat den Namen verstanden, und die Antwort passt zur Frage.
        case verstanden(PlaceCandidate)
        /// Mehrere Orte heißen so — oder die einzige Antwort hieß anders als
        /// die Frage. Beides ist derselbe Fall: Der Mensch muss wählen.
        case meintestDu([PlaceCandidate])
        /// Apple kennt den Namen nicht.
        case unbekannt
    }

    /// Die sechzehn Länder sind der einzige Weg, an mehr als einen Treffer zu
    /// kommen. **Gemessen:** Auf „Neustadt" antwortet Apple mit genau *einem*
    /// Ort — MapKit mit einem anderen als CoreLocation. Eine Liste gibt keine
    /// der beiden Schnittstellen her. Hängt man das Land an die Frage, kommen
    /// sie einzeln heraus: sieben echte Neustädte, in 3,9 s.
    ///
    /// Die Liste steht in `PlaceQuery`, weil der Fächer sie **anhängt** und der
    /// Zerleger sie **wiedererkennen** muss — siehe dort.
    private static var laender: [String] { PlaceQuery.laender }

    /// Der normale Weg: einmal fragen, und nur wenn die Antwort nicht zur Frage
    /// passt, den Fächer aufmachen.
    ///
    /// `gemeint` ist der Text, den der Mensch **selbst getippt** hat, wenn
    /// `name` aus einem angetippten Vorschlag stammt. Beides auseinanderhalten
    /// ist der Kern von #143: Gefragt wird mit dem Vorschlag, gemessen wird an
    /// dem, was der Mensch wollte.
    static func look(up name: String, gemeint: String? = nil) async -> Result {
        if let stubbed = stubbedResult(for: name) { return stubbed }

        let frage = PlaceQuery.parse(name)
        let mass = gemeint.map(PlaceQuery.parse)

        if let hit = await resolveOnce(frage, mass: mass ?? frage), hit.answersQuery {
            // **Ein angetippter Vorschlag ist eine Wahl, keine Bestätigung.**
            // Wer „Stuttgart" tippt und die Stuttgarter Straße in seiner
            // eigenen Stadt angeboten bekommt, tippt sie an, ohne den Ort dahinter
            // zu lesen — und hatte danach kommentarlos die PLZ von nebenan. Wenn
            // der getippte Name selbst ein Ort ist und ein anderer als der
            // getroffene, entscheidet das der Mensch.
            if let mass, let anderer = await widersprechenderOrt(mass, gegen: hit.candidate) {
                return .meintestDu([hit.candidate, anderer])
            }
            return .verstanden(hit.candidate)
        }
        // Gefächert wird über das, was der Mensch getippt hat — der Vorschlag
        // hat sich als Frage ja gerade nicht bewährt.
        let fächer = await alternatives(for: (mass ?? frage).name)
        return fächer.isEmpty ? .unbekannt : .meintestDu(fächer)
    }

    /// Der Fächer über die Bundesländer — hinter „Anderer Ort …", und
    /// automatisch, wenn die erste Antwort anders hieß als die Frage.
    ///
    /// Nacheinander, nicht nebeneinander: Sechzehn gleichzeitige Abfragen sind
    /// der schnellste Weg in Apples Drosselung, und gemessen reichen 3,9 s.
    static func alternatives(for name: String) async -> [PlaceCandidate] {
        if let stubbed = stubbedAlternatives() { return stubbed }
        guard !AppRepositories.usesMockData else { return [] }

        // Ohne den Zerleger fragt der Fächer „Stuttgart, Baden-Württemberg,
        // Deutschland, Bayern, Deutschland" — sechzehnmal Unsinn.
        let frage = PlaceQuery.parse(name)
        var found: [PlaceCandidate] = []
        for land in laender {
            guard let hit = await resolveOnce(frage.im(land), mass: frage), hit.answersQuery
            else { continue }
            found.append(hit.candidate)
        }
        return PlaceMatch.usable(found)
    }

    // MARK: - Fünf Ziffern sind noch kein deutsches Gebiet

    /// **Was hinter einer getippten Postleitzahl steckt** (#148).
    enum PLZErgebnis: Equatable {
        /// Apple verortet die Ziffern in Deutschland, und zwar unter genau
        /// diesen Ziffern.
        case deutsch(PlaceCandidate)
        /// Sie liegen in einem anderen Land — mit dessen Namen, wo Apple ihn
        /// nennt.
        case ausland(land: String?)
        /// Deutschland, aber eine andere PLZ: Diese Zahl ist keine.
        case unbekannt
        /// Gar keine Antwort. **Nicht dasselbe wie „gibt es nicht"** — daraus
        /// folgt kein Urteil, nur ein zweiter Versuch.
        case keineAntwort
    }

    /// **Fünf Ziffern sind fünf Ziffern — überall auf der Welt.**
    ///
    /// Bis zum 12.08. ging eine PLZ ohne jede Rückfrage in den Speicher:
    /// `RegionQuery` sagte „fünf Ziffern, also PLZ", und damit war sie eine.
    /// Zwei Installationen an der US-Westküste liefen so durch das Onboarding
    /// und landeten in einer App ohne Märkte und ohne Erklärung — es gibt
    /// keinen deutschen Anker, an dem eine Gebiets-Anforderung hängen könnte.
    ///
    /// Der Ortsname-Weg hatte das Loch nie: `resolveOnce` verlangt seit jeher
    /// `isoCountryCode == "DE"`. Nur an den Ziffern kam niemand vorbei, weil
    /// sie gar nicht erst gefragt haben.
    ///
    /// **Am 12.08. gemessen** (dieselbe Frage, die `PlaceQuery` ohnehin stellt,
    /// also mit „, Deutschland" dahinter):
    ///
    ///     95070, Deutschland → iso MX, Texhuacán, postalCode 95070
    ///     95070             → nichts
    ///     10001, Deutschland → iso DE, Annaberg-Buchholz, rückwärts 09456
    ///     10115 / 01219 / 70173, Deutschland → iso DE, ebendiese PLZ
    ///
    /// Zwei Dinge stehen darin. Erstens ignoriert Apple das angehängte Land und
    /// antwortet trotzdem aus Mexiko — der Anhang schadet also nicht, und
    /// **ohne** ihn kommt gar nichts zurück. Zweitens reicht die Landesprüfung
    /// allein nicht: Auf eine erfundene deutsche PLZ antwortet Apple mit einem
    /// beliebigen deutschen Ort, der eine **andere** PLZ trägt. Deshalb gilt
    /// hier dieselbe Regel wie seit #143 beim Ortsnamen — **das Getippte ist
    /// das Maß**: Es zählt nur, was unter genau diesen Ziffern zurückkommt.
    static func pruefe(plz: String) async -> PLZErgebnis {
        if let stubbed = stubbedPLZ(for: plz) { return stubbed }
        // Mock-Läufe sprechen nie mit Apple. Eine PLZ gilt dort als deutsch —
        // sonst käme keine Journey mehr durch den Assistenten, und geprüft
        // würde nicht die Entscheidung, sondern das Netz.
        guard !AppRepositories.usesMockData else {
            return .deutsch(PlaceCandidate(plz: plz, ort: plz, land: nil))
        }
        let frage = PlaceQuery(name: plz, land: nil)
        guard let forward = try? await CLGeocoder().geocodeAddressString(frage.geocoderString).first
        else { return .keineAntwort }

        let vorwärts = antwort(forward)
        // Die Rückwärtsrunde nur, wo die Ziffern vorwärts nicht schon
        // dastanden — bei einer echten PLZ tun sie das (gemessen), und dann
        // wäre sie eine Abfrage für nichts.
        var rückwärts: Antwort?
        if vorwärts.postalCode != plz, let location = forward.location,
           let back = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            rückwärts = antwort(back)
        }
        return entscheidePLZ(plz, vorwärts: vorwärts, rückwärts: rückwärts)
    }

    /// **Was die App aus den Antworten auf fünf Ziffern macht** — reine
    /// Rechnung, ohne Netz, damit sie prüfbar ist. Wie `entscheide`.
    static func entscheidePLZ(_ plz: String, vorwärts: Antwort, rückwärts: Antwort?) -> PLZErgebnis {
        let antworten = [vorwärts, rückwärts].compactMap { $0 }

        // Die getippten Ziffern, aus Deutschland: der einzige Fall, der
        // durchgeht. Er steht **vor** der Landesprüfung, damit ein Ort dicht an
        // der Grenze nicht daran scheitert, dass die Rückwärtsrunde jenseits
        // davon landet.
        if let treffer = antworten.first(where: { $0.postalCode == plz && $0.isoCountryCode == "DE" }) {
            // Ort und Bundesland kommen aus **der** Antwort, die die Ziffern
            // trug — nicht aus der anderen: An der Grenze nennt die
            // Rückwärtsrunde sonst einen Ort im Nachbarland.
            let ort = treffer.locality ?? vorwärts.locality ?? plz
            return .deutsch(PlaceCandidate(plz: plz, ort: ort, land: treffer.administrativeArea))
        }
        if let fremd = antworten.first(where: {
            $0.isoCountryCode != nil && $0.isoCountryCode != "DE"
        }) {
            return .ausland(land: fremd.country)
        }
        return .unbekannt
    }

    private static func antwort(_ placemark: CLPlacemark) -> Antwort {
        Antwort(
            locality: placemark.locality,
            subLocality: placemark.subLocality,
            thoroughfare: placemark.thoroughfare,
            administrativeArea: placemark.administrativeArea,
            postalCode: placemark.postalCode,
            name: placemark.name,
            isoCountryCode: placemark.isoCountryCode,
            country: placemark.country
        )
    }

    /// Der Ort, der dem getippten Namen entspricht — wenn es ihn gibt und er
    /// ein anderer ist als der Treffer.
    ///
    /// Kostet genau eine Abfrage, und nur in dem einen Fall, in dem der Treffer
    /// nicht so heißt wie die Frage. Ergibt der getippte Name selbst keinen Ort
    /// (wer „Karl" tippt und die Karl-Laux-Straße wählt, meint die Straße),
    /// bleibt es bei der Bestätigung.
    private static func widersprechenderOrt(
        _ mass: PlaceQuery, gegen treffer: PlaceCandidate
    ) async -> PlaceCandidate? {
        guard !PlaceMatch.answers(mass.name, ort: treffer.ort, ortsteil: nil) else { return nil }
        guard let stadt = await resolveOnce(PlaceQuery(name: mass.name, land: nil), mass: mass),
              stadt.answersQuery,
              stadt.candidate.plz != treffer.plz else { return nil }
        return stadt.candidate
    }

    // MARK: - Eine Abfrage

    struct Hit: Equatable {
        let candidate: PlaceCandidate
        /// Hieß der Ort auch so, wie gefragt wurde?
        let answersQuery: Bool
    }

    /// Die Felder einer Geocoder-Antwort, die die Entscheidung liest — und
    /// sonst nichts.
    ///
    /// Damit lässt sich die Entscheidung **ohne Netz** prüfen. Die Werte in den
    /// Tests sind nicht ausgedacht, sondern die am 03./06./11.08. an Apples
    /// Geocoder gemessenen.
    struct Antwort: Equatable {
        var locality: String?
        var subLocality: String?
        var thoroughfare: String?
        var administrativeArea: String?
        var postalCode: String?
        var name: String?
        /// Das Land der Antwort, als Kürzel — der Prüfstein aus #148.
        var isoCountryCode: String?
        /// Dasselbe Land, ausgeschrieben, damit die Meldung es nennen kann.
        var country: String?

        init(
            locality: String? = nil,
            subLocality: String? = nil,
            thoroughfare: String? = nil,
            administrativeArea: String? = nil,
            postalCode: String? = nil,
            name: String? = nil,
            isoCountryCode: String? = nil,
            country: String? = nil
        ) {
            self.locality = locality
            self.subLocality = subLocality
            self.thoroughfare = thoroughfare
            self.administrativeArea = administrativeArea
            self.postalCode = postalCode
            self.name = name
            self.isoCountryCode = isoCountryCode
            self.country = country
        }
    }

    /// `frage` geht an Apple, `mass` entscheidet, ob die Antwort zählt. Meist
    /// sind beide dasselbe; auseinander gehen sie, wenn ein Vorschlag angetippt
    /// wurde.
    private static func resolveOnce(_ frage: PlaceQuery, mass: PlaceQuery) async -> Hit? {
        guard !AppRepositories.usesMockData else { return nil }
        let name = mass.name
        guard let forward = try? await CLGeocoder().geocodeAddressString(frage.geocoderString).first,
              forward.isoCountryCode == "DE",
              let location = forward.location else { return nil }
        // Ein Land, das mitgefragt wurde, muss auch herauskommen — sonst hat
        // Apple die Einschränkung schlicht ignoriert und antwortet zum
        // zweiten Mal mit demselben Ort.
        if let land = frage.land, forward.administrativeArea != land { return nil }

        let vorwärts = antwort(forward)
        // Die Rückwärtsrunde nur, wo sie gebraucht wird — siehe unten.
        var rückwärts: Antwort?
        if !(vorwärts.thoroughfare != nil && PLZValidator.isValid(vorwärts.postalCode ?? "")),
           let back = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            rückwärts = antwort(back)
        }
        return entscheide(vorwärts: vorwärts, rückwärts: rückwärts, mass: mass)
    }

    /// **Was die App aus einer Geocoder-Antwort macht** — reine Rechnung, ohne
    /// Netz, damit sie prüfbar ist.
    static func entscheide(vorwärts: Antwort, rückwärts: Antwort?, mass: PlaceQuery) -> Hit? {
        let name = mass.name

        // **Eine Straße beantwortet sich selbst** (06.08.). Wer „Dresden
        // Karl-Laux-Straße 6" tippt, bekam bis dahin „kennt Apple nicht" —
        // nicht weil Apple die Adresse nicht kennt, sondern weil `PlaceMatch`
        // verlangt, dass der **ganze getippte Text** im Ortsnamen steckt, und
        // „Dresden Karl-Laux-Straße 6" steckt nicht in „Dresden".
        //
        // Gemessen am 06.08. an Apples Geocoder:
        //
        //     Dresden Karl-Laux-Straße 6  → locality Dresden, subLocality
        //     Prohlis, thoroughfare Karl-Laux-Straße, **postalCode 01219**
        //
        // Zwei Dinge stehen darin, die vorher anders in den Notizen standen:
        // Eine Adresse ist **eindeutig** — an ihr ist nichts zu wählen, also
        // gibt es auch nichts zu prüfen. Und der **Vorwärts**-Geocoder liefert
        // hier sehr wohl eine PLZ; der Befund vom 03.08. („neunmal nil") galt
        // für blanke *Ortsnamen*, nicht für Adressen. Wo sie schon dasteht,
        // spart das die Rückwärts-Abfrage.
        let istAdresse = vorwärts.thoroughfare != nil

        if istAdresse, let plz = vorwärts.postalCode, PLZValidator.isValid(plz) {
            let ort = vorwärts.locality ?? vorwärts.name ?? plz
            return Hit(
                candidate: PlaceCandidate(plz: plz, ort: ort, land: vorwärts.administrativeArea),
                answersQuery: true
            )
        }

        guard let rückwärts, let plz = rückwärts.postalCode, PLZValidator.isValid(plz)
        else { return nil }

        let ort = rückwärts.locality ?? vorwärts.locality ?? vorwärts.name ?? plz
        let candidate = PlaceCandidate(plz: plz, ort: ort, land: rückwärts.administrativeArea)
        let matches = istAdresse
            || PlaceMatch.answers(name, ort: rückwärts.locality, ortsteil: rückwärts.subLocality)
            || PlaceMatch.answers(name, ort: vorwärts.locality, ortsteil: vorwärts.subLocality)
            || PlaceMatch.answers(name, ort: vorwärts.name, ortsteil: nil)
        return Hit(candidate: candidate, answersQuery: matches)
    }

    // MARK: - Testnaht

    /// Wie `uiTestingLocatedPLZ` beim Ortungs-Knopf: Die Journeys prüfen nicht
    /// Apples Geocoder, sondern was die App **mit seiner Antwort macht**. Ein
    /// Test, der am Netz hängt, wird rot, ohne dass etwas kaputt ist.
    ///
    /// Format `Ort|PLZ|Land`, mehrere mit `;` getrennt; `NICHTS` für „kennt
    /// Apple nicht".
    ///
    /// **Ein Eintrag darf seine Frage mitbringen** (`Frage>Ort|PLZ|Land`) und
    /// gilt dann nur für sie. Gebraucht seit #143: Ein angetippter Vorschlag
    /// schickt eine *andere* Zeichenkette los als die, die getippt wurde
    /// („Stuttgart" → „Stuttgart,Baden-Württemberg,Deutschland"), und genau
    /// dieser Unterschied ist der Fehler gewesen. Eine Vorgabe, die für jede
    /// Frage dasselbe antwortet, kann ihn nicht abbilden.
    ///
    /// Einträge ohne Frage gelten wie bisher für alles — die bestehenden
    /// Journeys ändern sich nicht.
    private static func stubbedResult(for name: String) -> Result? {
        guard let raw = UserDefaults.standard.string(forKey: "uiTestingCityLookup") else { return nil }
        if raw == "NICHTS" { return .unbekannt }

        var passend: [PlaceCandidate] = []
        var allgemein: [PlaceCandidate] = []
        for eintrag in raw.split(separator: ";").map(String.init) {
            let teile = eintrag.split(separator: ">", maxSplits: 1).map(String.init)
            if teile.count == 2 {
                // Ohne Leerzeichen verglichen: Die Vorgabe kommt über
                // `launchArguments` und trägt deshalb keine (siehe
                // `AddressSuggestionJourneyTests`), die Frage aus dem
                // Vorschlag dagegen schon — „Stuttgart, Baden-Württemberg".
                guard ohneLeerzeichen(teile[0]) == ohneLeerzeichen(name) else { continue }
                passend += parse(teile[1])
            } else {
                allgemein += parse(eintrag)
            }
        }
        let candidates = passend.isEmpty ? allgemein : passend
        guard let first = candidates.first else { return .unbekannt }
        return candidates.count == 1 ? .verstanden(first) : .meintestDu(candidates)
    }

    /// Dieselbe Naht für die PLZ-Prüfung: `uiTestingPLZPruefung`, Einträge mit
    /// `;` getrennt, jeder wahlweise mit seiner Frage davor (`95070>…`).
    ///
    /// Werte: `AUSLAND|Mexiko`, `UNBEKANNT`, `NICHTS` — oder ein Ort in der
    /// Schreibweise von oben (`Dresden|01219|Sachsen`) für „geht durch".
    /// Eine PLZ, zu der nichts dasteht, bleibt beim Mock-Verhalten und geht
    /// durch; so braucht eine Journey nur den Fall zu setzen, den sie meint.
    private static func stubbedPLZ(for plz: String) -> PLZErgebnis? {
        guard let raw = UserDefaults.standard.string(forKey: "uiTestingPLZPruefung") else { return nil }
        for eintrag in raw.split(separator: ";").map(String.init) {
            let teile = eintrag.split(separator: ">", maxSplits: 1).map(String.init)
            if teile.count == 2, ohneLeerzeichen(teile[0]) != ohneLeerzeichen(plz) { continue }
            let wert = teile.count == 2 ? teile[1] : teile[0]
            let felder = wert.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            switch felder[0].uppercased() {
            case "AUSLAND": return .ausland(land: felder.count > 1 && !felder[1].isEmpty ? felder[1] : nil)
            case "UNBEKANNT": return .unbekannt
            case "NICHTS": return .keineAntwort
            default: if let ort = parse(wert).first { return .deutsch(ort) }
            }
        }
        return nil
    }

    private static func ohneLeerzeichen(_ value: String) -> String {
        value.filter { !$0.isWhitespace }.lowercased()
    }

    private static func stubbedAlternatives() -> [PlaceCandidate]? {
        guard let raw = UserDefaults.standard.string(forKey: "uiTestingCityAlternatives") else { return nil }
        return parse(raw)
    }

    private static func parse(_ raw: String) -> [PlaceCandidate] {
        raw.split(separator: ";").compactMap { entry in
            let parts = entry.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, PLZValidator.isValid(parts[1]) else { return nil }
            let land = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
            return PlaceCandidate(plz: parts[1], ort: parts[0], land: land)
        }
    }
}
