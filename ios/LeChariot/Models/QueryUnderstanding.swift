import Foundation

/// **Was die App aus dem getippten Wort gemacht hat.**
///
/// Die Suche leitet an zwei Stellen still ab, und beide sieht heute niemand:
/// Die Tippfehler-Toleranz in `OfferMatcher.tokensMatch` zieht „Käes" auf
/// `käse`, und `MatchDictionary` macht aus „Hafermilch" ein `milch`. Wer
/// danach eine Trefferliste sieht, weiß nicht, wonach eigentlich gesucht
/// wurde — und wer **keine** sieht, weiß nicht, ob das Wort unbekannt ist oder
/// diese Woche nur nichts im Angebot war.
///
/// **Dieselbe Entscheidung wie beim Standort** ([[Le Chariot Entscheidungen]],
/// 2026-07-31): Jede Ableitung, die der Nutzer nicht zu sehen bekommt, ist
/// eine, die er nicht korrigieren kann — und sie wird still falsch, nicht
/// laut. Bei der PLZ stand ein Mensch daneben, hier steht er auch.
///
/// **Der Wert ist absichtlich aus dem gelesen, was der Matcher wirklich tut,
/// und nicht aus einer zweiten Ableitung.** Eine Korrektur gegen die 645
/// Wörterbuchwörter zu rechnen wäre einfacher und wäre falsch: `OfferMatcher`
/// korrigiert gegen **Titel- und Tag-Token dieser Woche**, nicht gegen das
/// Wörterbuch. Eine Anzeige, die eine andere Ableitung rechnet als die Suche,
/// widerspricht ihr früher oder später — und dann glaubt man der falschen.
struct QueryUnderstanding: Equatable {

    /// Was mit einem einzelnen Suchwort passiert ist.
    enum Reading: Equatable {
        /// Das Wörterbuch kennt das Wort unter seinem eigenen Namen — es ging
        /// unverändert in die Suche. Nichts abgeleitet, nichts zu zeigen.
        case asTyped
        /// Das Wörterbuch bildet das Wort auf einen **anderen** Begriff ab:
        /// „Hafermilch" → `milch`, „Zwetschgen" → `pfirsich`, „vegan" → `tofu`.
        case term(String)
        /// Das Wörterbuch kennt das Wort nicht, aber die Tippfehler-Toleranz
        /// hat es auf ein Wort gezogen, das diese Woche wirklich vorkommt:
        /// „Butetr" → `butter`.
        case corrected(String)
        /// Das Wörterbuch kennt das Wort nicht, und korrigiert wurde auch
        /// nichts. Gesucht wird es dann nur wörtlich im Angebotstitel.
        ///
        /// **Der Fall, an dem „vegan Schnitzel" vom 21.07. bis zum 31.07.
        /// hing:** Ohne diese Auskunft sieht „das Wort kennt niemand" genauso
        /// aus wie „diese Woche gibt es dazu nichts".
        case unknown

        /// Der Begriff, der aus diesem Wort in die Suche gegangen ist —
        /// `nil`, wenn nichts abgeleitet wurde.
        var derivedTerm: String? {
            switch self {
            case .term(let t), .corrected(let t): return t
            case .asTyped, .unknown: return nil
            }
        }
    }

    struct Word: Equatable {
        /// Das Wort, wie es (normalisiert) getippt wurde.
        let typed: String
        let reading: Reading
    }

    let words: [Word]

    /// Der Begriff, den die **ganze** Anfrage als Wendung meint — „crème
    /// fraîche" → `sahne`. Einzeln tokenisiert wäre „creme" nichts, deshalb
    /// führt `OfferMatcher` diesen Weg getrennt, und deshalb steht er hier
    /// getrennt.
    let phraseTerm: String?

    // MARK: Ableiten

    /// Liest die Anfrage so, wie `OfferMatcher` sie liest.
    ///
    /// `offers` ist der Vorrat dieser Woche und wird **nur** für die
    /// Tippfehler-Korrektur gebraucht: Ob das Wörterbuch ein Wort kennt, hängt
    /// nicht vom Prospekt ab, welches Wort eine Korrektur getroffen hat schon.
    static func of(query: String, in offers: [Offer]) -> QueryUnderstanding {
        let tokens = OfferMatcher.tokens(query)
        let phrase = MatchDictionary.terms(forPhrase: OfferMatcher.normalize(query))

        // Einmal für alle Wörter statt je Wort: die Wörter, gegen die der
        // Matcher überhaupt korrigieren kann.
        var vocabulary: Set<String> = []
        if tokens.contains(where: { MatchDictionary.terms(forToken: $0).isEmpty }) {
            for offer in offers {
                vocabulary.formUnion(OfferMatcher.tokens(offer.product))
                vocabulary.formUnion(offer.matchKeys)
            }
        }

        let words = tokens.map { token in
            Word(typed: token, reading: reading(of: token, vocabulary: vocabulary))
        }
        return QueryUnderstanding(words: words, phraseTerm: phrase.sorted().first)
    }

    private static func reading(of token: String, vocabulary: Set<String>) -> Reading {
        // Das Wörterbuch zuerst: Wenn es das Wort kennt, ist sein Begriff das,
        // was in die Suche geht — unabhängig davon, ob der Titel es auch trägt.
        let terms = MatchDictionary.terms(forToken: token)
        if let term = terms.sorted().first {
            return term == token ? .asTyped : .term(term)
        }
        // Steht das Wort wörtlich im Vorrat, hat die Suche nichts abgeleitet;
        // es bleibt trotzdem ein Wort ohne Wörterbucheintrag, und genau das
        // ist die Auskunft, die fehlte.
        if vocabulary.contains(token) { return .unknown }
        // Sonst: hat die Tippfehler-Toleranz gegriffen? Der kürzeste Abstand
        // gewinnt, bei Gleichstand das alphabetisch erste Wort — sonst hinge
        // die Anzeige an der Reihenfolge der Angebotszeilen.
        let candidates = vocabulary
            .filter { $0 != token && OfferMatcher.tokensMatch(token, $0) }
            .sorted()
        if let hit = candidates.first { return .corrected(hit) }
        return .unknown
    }

    // MARK: Was auf dem Bildschirm steht

    /// Die Wörter, aus denen etwas abgeleitet wurde.
    var derived: [Word] { words.filter { $0.reading.derivedTerm != nil } }

    /// Die Wörter, die das Wörterbuch nicht kennt.
    var unknownWords: [Word] { words.filter { $0.reading == .unknown } }

    /// Die Zeile über der Trefferliste — `nil`, wenn nichts abgeleitet wurde.
    ///
    /// **Bei einem Suchwort ohne Anführungszeichen.** Der Blatt-Titel trägt das
    /// getippte Wort schon („Treffer für ‚Käes'"); es hier zu wiederholen wäre
    /// dieselbe Zeile zweimal. Erst ab zwei Wörtern muss die Zeile sagen, von
    /// welchem sie redet.
    var headline: String? {
        if let phraseTerm, words.count > 1 {
            return "Verstanden als \(Self.display(phraseTerm))"
        }
        let derived = derived
        guard !derived.isEmpty else { return nil }
        if words.count == 1, let only = derived.first {
            return "Verstanden als \(Self.display(only.reading.derivedTerm ?? ""))"
        }
        return derived.map {
            "\u{201E}\(Self.display($0.typed))\u{201C} als \(Self.display($0.reading.derivedTerm ?? ""))"
        }.joined(separator: " · ")
    }

    /// Der Satz zu den Wörtern ohne Wörterbucheintrag — `nil`, wenn es keine
    /// gibt.
    ///
    /// Er steht **immer** getrennt von `headline`, auch wenn beides zugleich
    /// zutrifft: „vegan Schnitzel" leitet aus dem einen Wort etwas ab und kennt
    /// das andere nicht. Ein Satz, der beides zusammenfasst, verschweigt die
    /// Hälfte, auf die es ankommt.
    var unknownNote: String? {
        // Trägt die ganze Anfrage als Wendung einen Begriff, dann ist sie
        // bekannt — die einzelnen Wörter müssen es dann nicht sein
        // („crème fraîche").
        guard phraseTerm == nil else { return nil }
        let unknown = unknownWords
        guard !unknown.isEmpty else { return nil }
        let quoted = unknown.map { "\u{201E}\(Self.display($0.typed))\u{201C}" }
        let subject = Self.list(quoted)
        let verb = unknown.count == 1 ? "steht" : "stehen"
        return "\(subject) \(verb) nicht im Wörterbuch — gesucht "
            + (unknown.count == 1 ? "wird das Wort" : "werden die Wörter")
            + " genau so im Angebotstitel."
    }

    // MARK: Warum diese eine Zeile hier steht

    /// Die Begriffe, über die dieses Angebot die Anfrage erfüllt hat, **ohne**
    /// dass sein Titel das Wort trägt — je Suchwort einer.
    ///
    /// Das ist die einzige Auskunft, die je Zeile verschieden ausfällt: Der
    /// Kopf sagt, was aus der Anfrage wurde, die Zeile sagt, worüber *sie*
    /// gefunden wurde. Leer, wenn der Titel alles selbst trägt.
    static func tags(for query: String, of offer: Offer) -> [Word] {
        let tokens = OfferMatcher.tokens(query)
        let productTokens = OfferMatcher.tokens(offer.product)
        var result: [Word] = []
        for token in tokens {
            if productTokens.contains(where: { OfferMatcher.tokensMatch(token, $0) }) { continue }
            let terms = MatchDictionary.terms(forToken: token)
            let tag = offer.matchKeys
                .filter { OfferMatcher.tokensMatch(token, $0) || terms.contains($0) }
                .sorted()
                .first
            if let tag {
                result.append(Word(typed: token, reading: tag == token ? .asTyped : .term(tag)))
            }
        }
        return result
    }

    /// Die Zeile unter einem Treffer — `nil`, wenn sein Titel alles selbst
    /// trägt oder wenn es nichts zu unterscheiden gibt.
    ///
    /// `namesWords` steht nur bei mehrwortigen Anfragen: Bei einem Suchwort ist
    /// klar, um welches es geht, und „‚vegan' über Tofu" wäre dasselbe Wort
    /// dreimal auf einem Bildschirm.
    static func rowNote(for query: String, of offer: Offer, namesWords: Bool) -> String? {
        let tags = tags(for: query, of: offer)
        guard !tags.isEmpty else { return nil }
        let parts = tags.map { word -> String in
            let term = display(word.reading.derivedTerm ?? word.typed)
            return namesWords ? "\u{201E}\(display(word.typed))\u{201C} über \(term)" : "über \(term)"
        }
        return list(parts)
    }

    // MARK: Kleinkram

    /// Begriffe stehen kleingeschrieben im Wörterbuch, auf dem Bildschirm sind
    /// es deutsche Substantive.
    static func display(_ term: String) -> String {
        guard let first = term.first else { return term }
        return first.uppercased() + term.dropFirst()
    }

    private static func list(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " und " + parts[parts.count - 1]
    }
}
