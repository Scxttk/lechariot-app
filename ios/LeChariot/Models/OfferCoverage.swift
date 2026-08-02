import Foundation

/// **Welche gewählte Filiale wirklich ohne Angebote dasteht.**
///
/// Reine Rechnung, damit die Antwort prüfbar ist, ohne eine Ansicht zu bauen —
/// und weil an ihr der Satz hängt, der zweimal falsch war
/// (`NoOffersReason.text`).
enum OfferCoverage {
    /// Eine Filiale ist versorgt, wenn Zeilen **ihre** `market_id` tragen —
    /// oder wenn ihre Kette bundesweit veröffentlicht.
    ///
    /// **Der zweite Fall ist der Fund vom 02.08.** ALDI Nord und NORMA liefern
    /// einen Prospekt für ganz Deutschland; ihre Zeilen tragen die
    /// synthetische `ALDI_NORD_DE`, nie die ID der Filiale. Wer in Anklam den
    /// ALDI wählt, bekam ihn deshalb unter „Ohne Angebote" gelistet — mit dem
    /// Satz „Dieser Markt veröffentlicht seinen Prospekt nicht online",
    /// während seine 477 Angebote zwei Zentimeter höher auf demselben
    /// Bildschirm standen.
    ///
    /// `Market.isNationwide` fängt das nicht ab: Das prüft die Endung `_DE`,
    /// und eine Filiale aus dem Verzeichnis heißt `ALDI_NORD_DE029038`. Die
    /// Kette ist hier die richtige Frage, nicht die ID.
    /// Ab wann der Prospekt dieser Filiale gilt, wenn er **schon da ist, aber
    /// erst später anfängt**.
    ///
    /// **Scotts Ahlbeck-Probe am Sonntag, 02.08.** REWE und Netto standen dort
    /// mit „Dieser Markt veröffentlicht seinen Prospekt nicht online" — in der
    /// Produktion lagen zur selben Zeit 254 bzw. 253 Zeilen für die Filiale.
    /// Alle mit `valid_from = 03.08.`, also ab Montag. Der Sync hat die alte
    /// Woche beim Neuschreiben geleert, die neue hatte noch nicht begonnen,
    /// und dazwischen ist die laufende Woche schlicht leer.
    ///
    /// Das ist **kein Sonderfall, sondern jeder Sonntagabend** — und der
    /// vierte Fall, in dem derselbe Satz etwas über den Markt behauptet, was
    /// wir gar nicht wissen. Hier wissen wir sogar das Gegenteil: Der Prospekt
    /// liegt vor uns, wir kennen sein Anfangsdatum.
    ///
    /// Bundesweite Ketten zählen über den Kettennamen, aus demselben Grund wie
    /// unten: Ihre Zeilen tragen nie die ID der Filiale.
    static func upcomingStart(for market: Market, in upcoming: [Offer]) -> Date? {
        upcoming
            .filter { $0.marketId == market.marketId || ($0.isNationwide && $0.market == market.chain) }
            .map(\.validFrom)
            .min()
    }

    static func branchesWithoutOffers(favorites: [Market], offers: [Offer]) -> [Market] {
        let coveredBranches = Set(offers.compactMap(\.marketId))
        let nationwideChains = Set(offers.filter(\.isNationwide).map(\.market))
        return favorites
            .filter {
                !$0.isNationwide
                    && !coveredBranches.contains($0.marketId)
                    && !nationwideChains.contains($0.chain)
            }
            .sorted { ($0.chain, $0.branchName) < ($1.chain, $1.branchName) }
    }
}
