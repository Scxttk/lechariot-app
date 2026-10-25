import Foundation
import Observation

/// **Ob Kochen Listeneinträge an Anthropic schicken darf.**
///
/// Kochen ist die einzige Stelle der App, an der Text von der Liste das Gerät
/// verlässt — und zwar zu einem Dritten, nicht nur zu unserem Server. Apples
/// Regeln für KI-Anbieter (Lizenzvereinbarung, Okt. 2026) verlangen dafür eine
/// Einwilligung, die den Empfänger nennt, bevor das erste Mal etwas rausgeht. Ohne sie
/// bleibt Kochen aus; alles andere in der App läuft unverändert.
///
/// Gespeichert wird der Zeitpunkt, nicht nur ein Ja: Ändert sich, was
/// übertragen wird, lässt sich eine ältere Einwilligung daran erkennen.
struct GerichteEinwilligung {
    static let key = "gerichte.einwilligung"

    let defaults: UserDefaults

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        #if DEBUG
        if UITestSupport.gerichteErlaubt, defaults.object(forKey: Self.key) == nil {
            defaults.set(Date(), forKey: Self.key)
        }
        #endif
    }

    var erteilt: Bool { defaults.object(forKey: Self.key) is Date }

    func erteilen(_ jetzt: Date = .now) { defaults.set(jetzt, forKey: Self.key) }

    func widerrufen() { defaults.removeObject(forKey: Self.key) }
}

/// Zustand des Kochen-Blatts: die Frage nach einem Gericht und die
/// Vorschläge aus der Liste, jede mit eigenem Ladezustand.
@MainActor
@Observable
final class GerichteStore {
    enum Zustand<Wert: Equatable>: Equatable {
        case leer
        case laedt
        case fertig(Wert)
        case fehler(GerichteFehler)
    }

    private(set) var zutaten: Zustand<Gericht> = .leer
    private(set) var vorschlaege: Zustand<[Gericht]> = .leer
    private(set) var einwilligungErteilt: Bool

    private let repository: GerichteRepositoryProtocol
    private let einwilligung: GerichteEinwilligung

    init(
        repository: GerichteRepositoryProtocol = AppRepositories.gerichte(),
        einwilligung: GerichteEinwilligung = GerichteEinwilligung()
    ) {
        self.repository = repository
        self.einwilligung = einwilligung
        self.einwilligungErteilt = einwilligung.erteilt
    }

    func einwilligen() {
        einwilligung.erteilen()
        einwilligungErteilt = true
    }

    /// Gericht → Zutaten. Ohne Einwilligung geht nichts raus — auch dann
    /// nicht, wenn eine Ansicht den Knopf versehentlich anbietet.
    func frageZutaten(fuer text: String, installId: UUID) async {
        let gericht = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard einwilligungErteilt, !gericht.isEmpty else { return }
        zutaten = .laedt
        do {
            zutaten = .fertig(try await repository.zutaten(
                fuer: String(gericht.prefix(80)), installId: installId
            ))
        } catch let fehler as GerichteFehler {
            zutaten = .fehler(fehler)
        } catch {
            zutaten = .fehler(.netz)
        }
    }

    /// Liste → Gerichte. Geschickt werden nur die Texte der Einträge —
    /// Notizen und Angaben bleiben auf dem Gerät, wie überall.
    func frageVorschlaege(items: [ShoppingItem], angebote: [String], installId: UUID) async {
        guard einwilligungErteilt else { return }
        let liste = Array(Self.listenTexte(items).prefix(60))
        guard !liste.isEmpty else { return }
        vorschlaege = .laedt
        do {
            vorschlaege = .fertig(try await repository.vorschlaege(
                liste: liste, angebote: angebote, installId: installId
            ))
        } catch let fehler as GerichteFehler {
            vorschlaege = .fehler(fehler)
        } catch {
            vorschlaege = .fehler(.netz)
        }
    }

    func zutatenZuruecksetzen() { zutaten = .leer }

    /// Die Texte, die rausgehen: getrimmt, ohne Doppelte, höchstens 40
    /// Zeichen je Eintrag (mehr nimmt der Server nicht an).
    static func listenTexte(_ items: [ShoppingItem]) -> [String] {
        var gesehen = Set<String>()
        return items.compactMap { item in
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 40, gesehen.insert(text.lowercased()).inserted else {
                return nil
            }
            return text
        }
    }
}
