import Foundation
import Observation

// MARK: - Offer matching

/// Suggestion logic for shopping-list items on top of OfferMatcher: rejected
/// matches drop out, and the suggested offer is the cheapest direct hit,
/// falling back to the cheapest category hit.
enum ShoppingListMatcher {
    static func matches(
        for text: String,
        in offers: [Offer],
        isRejected: (Offer) -> Bool = { _ in false }
    ) -> [OfferMatch] {
        OfferMatcher.matches(for: text, in: offers).filter { !isRejected($0.offer) }
    }

    static func cheapestMatch(
        for text: String,
        in offers: [Offer],
        isRejected: (Offer) -> Bool = { _ in false }
    ) -> OfferMatch? {
        // matches() already orders direct-before-category, each by price —
        // but priceless offers sort last, so prefer the first priced hit.
        let ranked = matches(for: text, in: offers, isRejected: isRejected)
        return ranked.first { $0.offer.price != nil } ?? ranked.first
    }

    // MARK: Die geheftete Wahl

    /// Das geheftete Angebot in diesem Vorrat, falls es diese Woche dabei ist.
    ///
    /// **Bewusst am Matcher vorbei.** Wer ein Produkt selbst ausgesucht hat,
    /// will es sehen — auch dann, wenn das Wörterbuch es diese Woche nicht mehr
    /// unter sein Listenwort sortiert oder der Prospekttitel ein Wort verloren
    /// hat. Die Heftung ist eine Aussage über ein Produkt, keine Anfrage.
    ///
    /// **Und bewusst an den Ablehnungen vorbei.** Anheften ist die deutlichere
    /// der beiden Aussagen; stünden beide gegeneinander, gewinnt die Heftung.
    /// Die Oberfläche lässt es gar nicht erst so weit kommen — ein ✕ auf dem
    /// gehefteten Angebot nimmt die Heftung mit, siehe `MatchDetailView`.
    static func pinnedOffer(_ pin: PinnedOffer, in offers: [Offer]) -> Offer? {
        offers.first { $0.matches(pin) }
    }

    /// Welcher Art der Treffer wäre, wenn man dieses eine Angebot durch den
    /// Matcher schickt. Nur fürs Abzeichen im Treffer-Blatt — ein geheftetes
    /// Angebot steht dort auch dann, wenn keine der beiden Stufen es findet;
    /// „Passt vielleicht" ist dann die ehrlichere der zwei Beschriftungen.
    static func kind(of offer: Offer, for query: String) -> MatchKind {
        OfferMatcher.matches(for: query, in: [offer]).first?.kind ?? .category
    }

    /// Was in einer Listenzeile steht: das Angebot **und** ob es die eigene
    /// Wahl ist.
    ///
    /// Die Heftung schlägt das billigste, solange es sie gibt. Gibt es sie
    /// diese Woche nicht, fällt die Zeile auf das billigste zurück — aber
    /// `dormantPin` zwingt sie, das auch zu sagen.
    static func suggestion(
        for item: ShoppingItem,
        in offers: [Offer],
        isRejected: (Offer) -> Bool = { _ in false }
    ) -> ItemSuggestion {
        if let pin = item.pinned, let offer = pinnedOffer(pin, in: offers) {
            return ItemSuggestion(
                match: OfferMatch(offer: offer, kind: kind(of: offer, for: item.query)),
                isPinned: true
            )
        }
        return ItemSuggestion(
            match: cheapestMatch(for: item.query, in: offers, isRejected: isRejected),
            dormantPin: item.pinned
        )
    }
}

/// Was eine Listenzeile über ihr Angebot zu sagen hat.
///
/// Drei Zustände in einem Wert, damit die Zeile sie nicht aus zwei Optionals
/// zusammenraten muss: das billigste (Normalfall), die eigene Wahl
/// (`isPinned`), und die eigene Wahl, die es diese Woche nicht gibt
/// (`dormantPin` gesetzt, `match` ist dann der sichtbar gemachte Rückfall).
struct ItemSuggestion: Equatable {
    /// Das Angebot, das die Zeile zeigt. `nil` heißt „nichts gefunden".
    let match: OfferMatch?
    /// Ob `match` die geheftete Wahl ist.
    var isPinned: Bool = false
    /// Gesetzt, wenn eine Wahl geheftet ist, es sie diese Woche aber nirgends
    /// gibt. Die Zeile **muss** das aussprechen.
    var dormantPin: PinnedOffer?
}

// MARK: - Quick-add suggestions

/// The staples offered as one-tap chips on the shopping list.
///
/// Lives outside the view so the "what is still worth suggesting" rule is
/// testable — it used to be a private constant behind the empty state, where
/// the whole strip vanished the moment the first chip was tapped.
enum ShoppingSuggestions {
    /// Staples that cover most first lists. The empty screen is otherwise a
    /// text field and nothing to react to — one tap here and the app can
    /// immediately show what it is for.
    static let staples = [
        "Milch", "Brot", "Butter", "Eier",
        "Käse", "Bananen", "Kaffee", "Nudeln",
    ]

    /// The staples not on the list yet, in their fixed order.
    ///
    /// Checked items count as on the list: re-suggesting what the user just
    /// ticked off would be the app arguing with them, and `add` would refuse
    /// the duplicate anyway.
    static func remaining(for items: [ShoppingItem], from staples: [String] = staples) -> [String] {
        let taken = Set(items.map { $0.text.lowercased() })
        return staples.filter { !taken.contains($0.lowercased()) }
    }

    /// How many tiles the strip shows.
    static let stripLength = 8

    /// Tags that are never a shopping list entry.
    private static let notGroceries: Set<String> = ["nonfood"]

    /// **Alkohol wird nicht vorgeschlagen.**
    ///
    /// Scotts Entscheidung vom 2026-07-31, und der Grund ist kein moralischer:
    /// Das Telefon wird herumgereicht, und die App liegt auf den Geräten
    /// seiner Großeltern. Ein Streifen, der aus der Kaufhistorie „Bier"
    /// hochspült, erzählt jedem, der gerade draufschaut, etwas über den
    /// Haushalt — auch dann, wenn niemand danach gefragt hat.
    ///
    /// Gilt für **beide** Quellen, den persönlichen Teil wie den
    /// Angebots-Teil: Ein Wochenangebot auf Wodka ist an dieser Stelle
    /// genauso wenig eine Anregung. Wer Alkohol sucht, findet ihn weiterhin
    /// über die Suche und in den Angeboten — zurückgehalten wird nur der
    /// **ungefragte Vorschlag**.
    private static let notSuggested: Set<String> = ["bier", "wein", "spirituosen"]

    /// Ob dieses Wort ungefragt vorgeschlagen werden darf.
    ///
    /// Geprüft wird über das Wörterbuch und nicht über eine eigene Wortliste:
    /// „Pils", „Prosecco" und „Wodka" sind dort schon Synonyme von `bier`,
    /// `wein` und `spirituosen`. Eine zweite Liste danebenzustellen hieße,
    /// sie ab dem ersten Pflegelauf auseinanderlaufen zu lassen.
    static func maySuggest(_ word: String) -> Bool {
        let token = OfferMatcher.normalize(word)
            .split(separator: " ")
            .joined(separator: " ")
        if notSuggested.contains(token) { return false }
        return MatchDictionary.terms(forToken: token).isDisjoint(with: notSuggested)
    }

    /// The strip: staples first, then topped up from **this week's offers** so
    /// it keeps its length instead of running dry.
    ///
    /// The old behaviour was the opposite of what it should be: eight fixed
    /// staples, minus whatever is already on the list, so the strip shrank
    /// with every tap and was gone after eight. Now new ones move up.
    ///
    /// The top-ups come from the `match_key` tags of the offers, not from
    /// product titles: a tag *is* a shopping term ("käse", "bananen") and is
    /// by construction something the matcher can find again, whereas
    /// "K-Classic Bio Vollmilch 1l" is a flyer headline nobody writes on a
    /// list. Ordered by the best discount carrying that tag — so a suggestion
    /// has a reason, which is the whole difference to a longer fixed list.
    /// Höchstens so viele persönliche Kacheln. Vier, damit der Streifen nicht
    /// zur Historie wird: Was diese Woche im Angebot ist, soll weiter zu sehen
    /// sein.
    static let personalLength = 4

    static func strip(
        for items: [ShoppingItem],
        offers: [Offer],
        history: [String] = [],
        includeStaples: Bool = true,
        limit: Int = stripLength
    ) -> [String] {
        var taken = Set(items.map { $0.text.lowercased() })
        var result: [String] = []

        // Stufe 1: was dieser Haushalt tatsächlich kauft.
        for word in history where !taken.contains(word.lowercased()) {
            guard maySuggest(word) else { continue }
            result.append(word.prefix(1).uppercased() + word.dropFirst())
            taken.insert(word.lowercased())
            if result.count == personalLength || result.count == limit { break }
        }

        // Stufe 3, aber vor Stufe 2 eingefügt: Die acht festen Wörter sind der
        // **Kaltstart** und verschwinden, sobald genug eigene Käufe da sind
        // (`includeStaples`). Solange sie da sind, stehen sie vor den
        // Angeboten — ein leerer Bildschirm braucht „Milch, Brot, Butter",
        // nicht den tiefsten Rabatt der Woche.
        if includeStaples {
            for staple in staples where !taken.contains(staple.lowercased()) {
                guard maySuggest(staple) else { continue }
                result.append(staple)
                taken.insert(staple.lowercased())
                if result.count == limit { return result }
            }
        }

        // Best discount per tag; a tag without a discount still counts, just
        // last — "im Angebot" beats "nothing to suggest".
        var bestDiscount: [String: Int] = [:]
        for offer in offers {
            for tag in offer.matchKeys where !notGroceries.contains(tag) {
                let discount = offer.discountPercent ?? 0
                if let seen = bestDiscount[tag], seen >= discount { continue }
                bestDiscount[tag] = discount
            }
        }

        let ranked = bestDiscount
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)

        for tag in ranked {
            let word = tag.prefix(1).uppercased() + tag.dropFirst()
            guard !taken.contains(word.lowercased()), maySuggest(tag) else { continue }
            result.append(word)
            taken.insert(word.lowercased())
            if result.count == limit { break }
        }
        return result
    }
}

// MARK: - Store

/// Local source of truth for the shopping list.
///
/// Persistence: UserDefaults, same rationale as RegionStore — a handful of
/// short strings, no queries or relations, so SwiftData would be overkill.
@MainActor
@Observable
final class ShoppingListStore {
    private(set) var items: [ShoppingItem]

    private let defaults: UserDefaults
    private static let key = "shopping.items"

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.items = stored
        } else {
            self.items = []
        }
    }

    var uncheckedItems: [ShoppingItem] { items.filter { !$0.isChecked } }
    var checkedItems: [ShoppingItem] { items.filter(\.isChecked) }

    /// Adds an item unless one with the same text already exists
    /// (case-insensitive, like the CLI). Returns false on duplicates.
    @discardableResult
    func add(_ rawText: String) -> Bool {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        guard !items.contains(where: { $0.text.lowercased() == text.lowercased() }) else {
            return false
        }
        items.append(ShoppingItem(text: text))
        persist()
        return true
    }

    func toggle(_ item: ShoppingItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isChecked.toggle()
        persist()
    }

    func remove(_ item: ShoppingItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    /// Sets the item's detail — the note under the name, never the query.
    ///
    /// An empty selection is stored as `nil` rather than `[]`: the two mean the
    /// same thing to everyone reading the item, and one representation cannot
    /// drift from the other. `detailLine` treats both alike anyway, which is
    /// the belt to this brace.
    func setDetail(_ detail: [String], for item: ShoppingItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].detail = detail.isEmpty ? nil : detail
        persist()
    }

    /// Heftet ein Angebot an den Eintrag, oder löst die Heftung (`nil`).
    ///
    /// Die Wahl liegt **im Artikel**, nicht in einem eigenen Speicher: Sie
    /// gehört zu genau diesem Listeneintrag, verschwindet mit ihm, und
    /// `AppReset` räumt sie schon mit ab, ohne dass jemand daran denken muss.
    func setPin(_ pin: PinnedOffer?, for item: ShoppingItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].pinned = pin
        persist()
    }

    func clearChecked() {
        items.removeAll { $0.isChecked }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// See `AppReset`. Clears memory and disk, not just the array — a
    /// `clearAll()` would leave an empty-but-present record behind.
    func resetAllData() {
        items = []
        defaults.removeObject(forKey: Self.key)
    }
}
