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

    /// **Was von einer Kette zu sagen ist, die gerade nichts Gültiges hat.**
    ///
    /// Zwei Daten und sonst nichts: wann ihre letzte Woche geendet hat und wann
    /// die nächste anfängt. Beide dürfen fehlen — eine Kette, von der wir keins
    /// von beidem wissen, bekommt keinen Chip (siehe `restingChains`), weil ein
    /// Chip ohne Grund dahinter genau die Sackgasse wäre, gegen die
    /// `OfferBrowser.chipChains` seit dem 31.07. gebaut ist.
    struct ChainOfferWindow: Equatable {
        var endedOn: Date?
        var startsOn: Date?

        var isKnown: Bool { endedOn != nil || startsOn != nil }
    }

    /// Je Kette das Fenster aus abgelaufenen und kommenden Zeilen.
    ///
    /// **Der Sonntag ist der Fall, für den es das gibt** (Scotts Feldtest
    /// 09.08.): Prospektwochen laufen Montag bis Samstag, der Sonntag ist das
    /// Loch dazwischen. Für die sieben Filialen in 01219 galten an diesem Tag
    /// 68 von 3 038 Zeilen — Netto, Penny, ALDI Nord und NORMA fingen alle am
    /// Montag an. Die App filterte das korrekt und **sagte es nicht**.
    static func windows(ended: [Offer], upcoming: [Offer]) -> [String: ChainOfferWindow] {
        var result: [String: ChainOfferWindow] = [:]
        for offer in ended {
            let bisher = result[offer.market]?.endedOn
            if bisher == nil || offer.validUntil > bisher! {
                result[offer.market, default: ChainOfferWindow()].endedOn = offer.validUntil
            }
        }
        for offer in upcoming {
            let bisher = result[offer.market]?.startsOn
            if bisher == nil || offer.validFrom < bisher! {
                result[offer.market, default: ChainOfferWindow()].startsOn = offer.validFrom
            }
        }
        return result
    }

    /// Die Ketten, die einen Chip behalten, **obwohl** heute keine Zeile von
    /// ihnen gilt: gewählt, ohne gültige Angebote, und mit einem Fenster, das
    /// den Grund nennen kann.
    ///
    /// Gerechnet über die Ketten der gewählten Filialen und nicht über alle
    /// Fenster: Wer Netto nie gewählt hat, will auch sonntags keinen
    /// Netto-Chip.
    static func restingChains(
        favorites: [Market],
        current: [Offer],
        windows: [String: ChainOfferWindow]
    ) -> Set<String> {
        let versorgt = Set(current.map(\.market))
        return Set(
            favorites
                .map(\.chain)
                .filter { !versorgt.contains($0) && windows[$0]?.isKnown == true }
        )
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
