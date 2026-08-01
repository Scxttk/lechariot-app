import Foundation

/// Die Wahl, die ein Mensch für einen Listeneintrag getroffen hat.
///
/// Bis hierher wählte die App je Eintrag das billigste Angebot, und das
/// Treffer-Blatt bot Alternativen an, **ohne** dass man eine davon nehmen
/// konnte — das ✕ ist Rückmeldung („weglegen"), keine Auswahl. Gemeldet am
/// 2026-07-31 von einem Tester: Bei „Käse" steht der Speck-Käse-Twister für
/// 0,69 € oben, er will aber den GRÜNLÄNDER Schnittkäse für 0,99 €, und zwar
/// dauerhaft auf der Liste. „Dann kann ich mir meine Einkaufsliste gleich
/// modifizieren."
///
/// **Geheftet wird an `market_id` + `product`, niemals an die Zeilen-ID.**
/// Angebote rotieren donnerstags; am 2026-07-31 um 22:00 wurden beim Neuaufbau
/// **alle 38 413 Zeilen gelöscht und neu geschrieben** — jede `offers.id` war
/// danach eine andere. Eine Wahl an der Zeilen-ID hätte spätestens nach einer
/// Woche stumm nicht mehr existiert. `market_id` + `product` ist dieselbe
/// Identität, auf die auch der Upsert-Schlüssel des Backends hört.
///
/// Und aus demselben Grund taugt `Offer.id` nicht als Schlüssel: Es trägt
/// `valid_from` mit, also genau den Teil, der sich jede Woche ändert. Der
/// Unterschied zwischen den beiden ist der ganze Trick — `MatchRejectionStore`
/// benutzt `Offer.id` **absichtlich**, weil eine Ablehnung mit der Woche
/// verfallen soll. Eine Heftung soll das Gegenteil.
struct PinnedOffer: Codable, Equatable, Hashable {
    /// `Offer.marketId`, ersatzweise die Kette — dieselbe Hälfte, aus der auch
    /// `Offer.id` seinen Markt-Teil bildet. Optional ist `marketId` nur, damit
    /// Zeilen von vor Migration v13 dekodieren; jede lebende Zeile hat ihn.
    let marketKey: String
    /// Die Kette im Klartext. Sie steckt nicht immer in `marketKey`, und die
    /// Zeile muss auch dann sagen können, wo die Wahl herkam, wenn es das
    /// Angebot diese Woche gar nicht gibt.
    let market: String
    let product: String

    /// Woran wiedererkannt wird: Markt und Produkt, ohne Woche.
    var key: String { "\(marketKey)|\(product)" }

    /// Der Satz für den Fall, dass es die Wahl diese Woche nicht gibt.
    ///
    /// Er steht hier und nicht in der Ansicht, weil er eine **Zusage** ist:
    /// Ein stiller Rückfall aufs billigste wäre genau die unsichtbare
    /// Ableitung, gegen die am 2026-07-31 entschieden wurde („Was die App aus
    /// dem Standort ableitet, bekommt der Mensch zu sehen").
    var absenceLine: String { "\(product) ist diese Woche nicht im Angebot" }
}

extension Offer {
    /// Die Identität, die die Wochenrotation überlebt — `Offer.id` ohne
    /// `valid_from`.
    var pinKey: String { "\(marketId ?? market)|\(product)" }

    /// Dieses Angebot als heftbare Wahl.
    var asPin: PinnedOffer {
        PinnedOffer(marketKey: marketId ?? market, market: market, product: product)
    }

    /// Ob dieses Angebot die geheftete Wahl ist.
    func matches(_ pin: PinnedOffer) -> Bool { pinKey == pin.key }
}
