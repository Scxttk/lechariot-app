import Foundation

/// The words an item's detail line can be built from.
///
/// **A vocabulary, not a text field.** Scott's decision from 2026-07-31, and it
/// buys two things at once. For the person: tapping is faster than typing at
/// the moment you are already holding the phone in one hand. For the app: the
/// detail can never contain something that has to be filtered before it is
/// shown, logged, or stored — there is nothing to sanitise, because there is
/// nothing to type.
///
/// Bring!'s "Details zu Milch" sheet is the model: amount, packaging, fat
/// content, kind, and only then free text. We take the first four and leave the
/// free text out.
///
/// **None of this reaches the matcher.** Some of the words (`Bio`, `Hafer`,
/// `Soja`, `1 l`) also exist in the dictionary, which makes the temptation to
/// feed them into the query real — and "Bio" as a fourth search word breaks the
/// AND exactly the way "Landliebe" would. Feeding the vocabulary into matching
/// would be its own decision with its own evidence.
enum ItemDetailVocabulary {

    /// One row of chips.
    ///
    /// - Parameter exclusive: only one chip of this group can be chosen. Two
    ///   amounts or two pack sizes at once say nothing anybody could act on in
    ///   a shop; two kinds ("Bio", "laktosefrei") say something perfectly
    ///   sensible.
    struct Group: Identifiable, Equatable {
        let title: String
        let chips: [String]
        let exclusive: Bool
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "Menge", chips: ["1", "2", "3", "4", "6", "12"], exclusive: true),
        Group(title: "Größe", chips: ["klein", "groß", "250 g", "500 g", "1 kg", "1 l"], exclusive: true),
        Group(
            title: "Art",
            chips: ["Bio", "laktosefrei", "glutenfrei", "vegan", "Hafer", "Soja", "Mandel"],
            exclusive: false
        ),
        anlass,
    ]

    /// **Warum der Artikel auf der Liste steht** — Bring!s dritte Chipreihe
    /// („Dringend · Angebot · Wenn's passt"), übernommen am 2026-08-08.
    ///
    /// Ausschließend, und das ist keine Formalie: „Dringend" und „Wenn's
    /// passt" sind Gegenteile. Zwei davon gleichzeitig sagen im Laden nichts,
    /// was jemand tun könnte — dieselbe Begründung wie bei zwei Mengen.
    static let anlass = Group(
        title: "Anlass",
        chips: ["Dringend", "Angebot", "Wenn's passt"],
        exclusive: true
    )

    /// **Die Sorten, die das Wörterbuch zu diesem Artikel schon kennt.**
    ///
    /// Bring! zeigt an dieser Stelle produktgenaue Sorten — bei Haferflocken
    /// kernig/Porridge/Vollkorn, bei Tomaten Cherry/Rispen/Strauch. Unser
    /// Matching-Wörterbuch führt genau diese Wörter längst als Synonyme:
    /// `tomaten` trägt Rispen-, Cherry-, Kirsch-, Strauch-, Roma- und
    /// Cocktailtomaten, `milch` trägt Frisch-, Voll-, Buttermilch sowie
    /// Mandel-, Hafer- und Sojadrink. **Deshalb kein zweiter Katalog:** Eine
    /// eigene Sortenliste wäre die dritte Stelle, an der Warenkunde gepflegt
    /// wird, und die erste, die von den beiden anderen abweicht.
    ///
    /// **Und trotzdem geht nichts davon in die Suche.** Ein Chip ist eine
    /// Notiz wie „Bio" — wer „Cherrytomaten" wählt, sucht weiterhin nach
    /// „Tomaten". Das ist dieselbe Zusage, die `ItemSheet` im Klartext
    /// ausspricht; sie gilt hier unverändert, obwohl die Wörter diesmal aus
    /// dem Wörterbuch stammen.
    ///
    /// - Parameter query: der Artikeltext, roh.
    static func kinds(for query: String) -> Group? {
        guard let token = OfferMatcher.tokens(query).last else { return nil }
        // Der **engste** Begriff, nicht irgendeiner: `brokkoli` trägt Chicorée
        // und Zuckermais mit, `chicorée` trägt Chicorée. Dieselbe Regel wie in
        // `ItemGlyphTerm`, wo ein zu grober Begriff ein falsches Bild ergibt.
        guard let term = MatchDictionary.terms(forToken: token)
            .min(by: { MatchDictionary.synonymCount(for: $0) < MatchDictionary.synonymCount(for: $1) })
        else { return nil }

        var gesehen = Set<String>()
        let chips = MatchDictionary.words(of: term)
            .filter { isEigeneSorte($0, of: token, term: term) }
            // **„Brötchen" und „broetchen" sind ein Wort.** Das Wörterbuch
            // führt beide Schreibweisen, damit die Suche beide findet; auf
            // einem Chip nebeneinander sähen sie aus wie zwei Sorten. Die
            // Normalisierung des Matchers faltet sie **nicht** zusammen
            // (gemessen: beide überstehen sie), also faltet es diese Zeile —
            // und behält die Fassung mit Umlaut.
            .sorted { umlautform($0) && !umlautform($1) }
            .filter { gesehen.insert(entumlautet($0)).inserted }
            .prefix(kindLimit)
            .map(capitalized)
        return chips.isEmpty ? nil : Group(title: "Sorte", chips: Array(chips), exclusive: true)
    }

    /// Acht, aus demselben Grund wie beim Wörterbuch-Raster: Die Reihe scrollt
    /// zur Seite, die Zahl ist eine Grenze gegen das Suchen, nicht gegen den
    /// Platz.
    static let kindLimit = 8

    /// Ob ein Synonym als **Sorte** taugt — also mehr sagt als der Artikel
    /// selbst.
    ///
    /// Aussortiert wird die Schreibvariante des Wortes, das schon dasteht:
    /// „Tomate" neben „Tomaten" ist keine Sorte, sondern derselbe Artikel
    /// noch einmal. Geprüft wird über den gemeinsamen Anfang — wer bis auf
    /// zwei Zeichen gleich anfängt und gleich lang ist, ist dasselbe Wort.
    private static func isEigeneSorte(_ wort: String, of token: String, term: String) -> Bool {
        let w = OfferMatcher.normalize(wort)
        guard !w.isEmpty else { return false }
        for andere in [token, OfferMatcher.normalize(term)] {
            if w == andere { return false }
            if abs(w.count - andere.count) <= 2,
               w.hasPrefix(andere.prefix(min(w.count, andere.count) - 1)) {
                return false
            }
        }
        return true
    }

    /// Ob das Wort einen Umlaut trägt — die Fassung, die auf einen Chip gehört.
    private static func umlautform(_ wort: String) -> Bool {
        wort.contains { "äöüÄÖÜß".contains($0) }
    }

    /// Umlaute auf ihre Umschrift, damit „brötchen" und „broetchen" denselben
    /// Schlüssel bekommen.
    private static func entumlautet(_ wort: String) -> String {
        var w = wort.lowercased()
        for (auf, ab) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] {
            w = w.replacingOccurrences(of: auf, with: ab)
        }
        return w
    }

    private static func capitalized(_ wort: String) -> String {
        guard let erster = wort.first else { return wort }
        return erster.uppercased() + wort.dropFirst()
    }

    /// **Die Reihen für genau diesen Artikel.**
    ///
    /// Menge, Größe, Art und Anlass gelten für alles; dazwischen steht die
    /// **Sorte**, wenn das Wörterbuch eine kennt. Vier Reihen also, fünf mit
    /// Sorte — das Panel zeigt vier davon, die fünfte liegt einen Wisch
    /// weiter (siehe `ItemDetailPanel`). Seine Höhe hängt bewusst **nicht**
    /// an der Zahl der Reihen, sonst wanderte die Eingabezeile von Artikel zu
    /// Artikel.
    ///
    /// **Die Art bleibt neben der Sorte stehen, und das ist gemessen.** Der
    /// erste Anlauf ließ die Sorte die Art *ersetzen* — dann verschwand „Bio"
    /// bei jedem Artikel, den das Wörterbuch kennt, und zwei Journeys fielen
    /// darüber. Bring! trennt die beiden gar nicht erst: Dort steht „Bio"
    /// mitten in der Milch-Reihe zwischen 3,5 % und „haltbar". Getrennt
    /// bleiben sie hier trotzdem, weil sich Sorten ausschließen und „Bio" und
    /// „laktosefrei" sich nicht.
    static func groups(for query: String) -> [Group] {
        var reihen = [groups[0], groups[1]]
        if let sorte = kinds(for: query) { reihen.append(sorte) }
        // **Der Anlass vor der Art, und das ist die Reihenfolge aus Scotts
        // Auftrag:** „Menge, Gebinde/Größe, produktspezifische Sorte, plus die
        // Kontextzeile." Vier Reihen, und genau die vier stehen im Panel. Die
        // allgemeine Art („Bio", „laktosefrei") liegt dahinter — sie ist die
        // fünfte, wenn das Wörterbuch eine Sorte kennt, und rückt sonst selbst
        // ins Bild.
        reihen.append(contentsOf: [anlass, groups[2]])
        return reihen
    }

    /// Die Gruppe eines Chips **innerhalb eines Satzes von Reihen** — die
    /// Sorten-Reihe gibt es nur je Artikel, ein fester Katalog kennt sie nicht.
    static func group(of chip: String, in reihen: [Group]) -> Group? {
        reihen.first { $0.chips.contains(chip) }
    }

    /// Every chip, in the order the sheet shows them. The detail line follows
    /// this order too — see `toggling`.
    static let allChips: [String] = groups.flatMap(\.chips)

    /// The group a chip belongs to, or nil for a word that is no longer in the
    /// vocabulary.
    ///
    /// Old lists can carry such a word: the vocabulary is allowed to change,
    /// and a detail written last month is still a true note about what somebody
    /// wanted. It stays on the item and stays removable — it just no longer has
    /// a chip to sit under.
    static func group(of chip: String) -> Group? {
        group(of: chip, in: groups)
    }

    /// The detail after tapping `chip`.
    ///
    /// Three rules, and the reason they live here rather than in the sheet is
    /// that all three are invisible in the result: you see which chips are on,
    /// never why the one you did not touch went off.
    ///
    /// 1. Tapping a chosen chip removes it — the same tap undoes itself.
    /// 2. In an exclusive group the new chip replaces its sibling, rather than
    ///    being refused. Somebody correcting "500 g" to "1 kg" taps the one
    ///    they want, not the one they no longer want.
    /// 3. The result keeps **vocabulary order**, not tap order, so the line
    ///    under the item reads "2 · 1 l · Bio" whichever way round it was
    ///    chosen. A line that reshuffles itself looks like a bug.
    ///
    /// Words that are no longer in the vocabulary keep their relative order and
    /// go last.
    static func toggling(_ chip: String, in detail: [String],
                         reihen: [Group] = groups) -> [String] {
        var chosen = Set(detail)
        if chosen.contains(chip) {
            chosen.remove(chip)
        } else {
            // **Die Reihen des Artikels, nicht der feste Katalog.** Die
            // Sorten-Reihe entsteht je Artikel aus dem Wörterbuch; ohne sie
            // hier wäre sie die einzige Reihe, in der zwei Chips gleichzeitig
            // an sein könnten, obwohl sie sich ausschließt.
            if let group = group(of: chip, in: reihen), group.exclusive {
                chosen.subtract(group.chips)
            }
            chosen.insert(chip)
        }
        let reihenfolge = reihen.flatMap(\.chips)
        let known = reihenfolge.filter { chosen.contains($0) }
        let unknown = detail.filter { chosen.contains($0) && !reihenfolge.contains($0) }
        return known + unknown
    }
}
