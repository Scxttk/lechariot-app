import Foundation

/// Gericht → Zutaten und Liste → Gerichte, über die Edge Function `gerichte`
/// (Backend `supabase/functions/gerichte`). Die Funktion fragt Claude Haiku;
/// der Schlüssel dazu liegt nur dort.
///
/// Mitgeschickt wird, was die Antwort braucht, und nichts sonst: der Text des
/// Gerichts oder die Einträge der Liste, Angebots-Begriffe ohne Filiale, und
/// die Installations-ID fürs Tageskontingent (der Server speichert davon nur
/// einen Hash). Kein Vorname, keine Postleitzahl, keine Notizen.
protocol GerichteRepositoryProtocol {
    func zutaten(fuer gericht: String, installId: UUID) async throws -> Gericht
    func vorschlaege(liste: [String], angebote: [String], installId: UUID) async throws -> [Gericht]
}

struct LiveGerichteRepository: GerichteRepositoryProtocol {
    let client: SupabaseClient

    private struct ZutatenAntwort: Decodable { let gericht: Gericht }
    private struct VorschlagsAntwort: Decodable { let gerichte: [Gericht] }
    private struct Fehlerkoerper: Decodable {
        let fehler: String
        let grenze: Int?
    }

    func zutaten(fuer gericht: String, installId: UUID) async throws -> Gericht {
        let body: [String: String] = [
            "art": "zutaten", "gericht": gericht, "install_id": installId.uuidString.lowercased(),
        ]
        return try await frage(body, als: ZutatenAntwort.self).gericht
    }

    func vorschlaege(liste: [String], angebote: [String], installId: UUID) async throws -> [Gericht] {
        struct Body: Encodable {
            let art = "vorschlaege"
            let liste: [String]
            let angebote: [String]
            let install_id: String
        }
        let body = Body(liste: liste, angebote: angebote, install_id: installId.uuidString.lowercased())
        return try await frage(body, als: VorschlagsAntwort.self).gerichte
    }

    private func frage<B: Encodable, A: Decodable>(_ body: B, als: A.Type) async throws -> A {
        let status: Int
        let data: Data
        do {
            (status, data) = try await client.invokeFunction("gerichte", body: body)
        } catch {
            throw GerichteFehler.netz
        }
        switch status {
        case 200:
            return try JSONDecoder().decode(A.self, from: data)
        case 429:
            let f = try? JSONDecoder().decode(Fehlerkoerper.self, from: data)
            throw f?.fehler == "gesamt" ? GerichteFehler.gesamt : .kontingent(grenze: f?.grenze ?? 20)
        case 422:
            throw GerichteFehler.keinGericht
        default:
            throw GerichteFehler.nichtErreichbar
        }
    }
}

/// Feste Antworten für UI-Läufe, Vorschauen und Builds ohne Backend — die
/// Journeys sollen nicht davon abhängen, was Haiku heute über Lasagne denkt.
///
/// Die Zutaten stehen so da, wie die Funktion sie liefert: Begriff aus dem
/// Wörterbuch, Name als eines seiner Synonyme.
final class MockGerichteRepository: GerichteRepositoryProtocol {
    var fehler: GerichteFehler?
    var verzoegerung: Duration = .milliseconds(300)
    private(set) var letzteListe: [String] = []
    private(set) var letzteAngebote: [String] = []

    init(fehler: GerichteFehler? = nil) {
        self.fehler = fehler
    }

    static let lasagne = Gericht(name: "Lasagne", portionen: 4, zutaten: [
        Zutat(begriff: "lasagneblätter", name: "Lasagneplatten", menge: "250 g"),
        Zutat(begriff: "hackfleisch", name: "Hackfleisch", menge: "500 g"),
        Zutat(begriff: "dosentomaten", name: "Passierte Tomaten", menge: "500 g"),
        Zutat(begriff: "zwiebeln", name: "Zwiebeln", menge: "1 Stück"),
        Zutat(begriff: "knoblauch", name: "Knoblauch", menge: "2 Zehen"),
        Zutat(begriff: "milch", name: "Milch", menge: "500 ml"),
        Zutat(begriff: "butter", name: "Butter", menge: "50 g"),
        Zutat(begriff: "mehl", name: "Mehl", menge: "40 g"),
        Zutat(begriff: "reibekäse", name: "Reibekäse", menge: "150 g"),
    ])

    static let vorschlaege: [Gericht] = [
        Gericht(name: "Spaghetti Bolognese", portionen: 2, zutaten: [
            Zutat(begriff: "nudeln", name: "Spaghetti", menge: "250 g"),
            Zutat(begriff: "hackfleisch", name: "Hackfleisch", menge: "300 g"),
            Zutat(begriff: "tomaten", name: "Tomaten", menge: "4 Stück"),
            Zutat(begriff: "zwiebeln", name: "Zwiebeln", menge: "1 Stück"),
        ]),
        Gericht(name: "Zucchini-Nudelpfanne", portionen: 2, zutaten: [
            Zutat(begriff: "nudeln", name: "Nudeln", menge: "250 g"),
            Zutat(begriff: "zucchini", name: "Zucchini", menge: "2 Stück"),
            Zutat(begriff: "tomaten", name: "Tomaten", menge: "2 Stück"),
            Zutat(begriff: "sahne", name: "Sahne", menge: "200 ml"),
        ]),
        Gericht(name: "Tomatensuppe", portionen: 2, zutaten: [
            Zutat(begriff: "tomaten", name: "Tomaten", menge: "6 Stück"),
            Zutat(begriff: "zwiebeln", name: "Zwiebeln", menge: "1 Stück"),
            Zutat(begriff: "sahne", name: "Sahne", menge: "100 ml"),
        ]),
    ]

    func zutaten(fuer gericht: String, installId: UUID) async throws -> Gericht {
        try await Task.sleep(for: verzoegerung)
        if let fehler { throw fehler }
        return Self.lasagne
    }

    func vorschlaege(liste: [String], angebote: [String], installId: UUID) async throws -> [Gericht] {
        letzteListe = liste
        letzteAngebote = angebote
        try await Task.sleep(for: verzoegerung)
        if let fehler { throw fehler }
        return Self.vorschlaege
    }
}
