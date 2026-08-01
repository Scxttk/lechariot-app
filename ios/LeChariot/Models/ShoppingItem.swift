import Foundation

/// One entry of the local shopping list. Free text — matching against offers
/// happens at display time, never persisted.
struct ShoppingItem: Codable, Equatable, Identifiable {
    let id: UUID
    var text: String
    var isChecked: Bool
    let addedAt: Date

    /// What this item is, more precisely — a note for the person in the shop,
    /// **never** part of the query.
    ///
    /// Bring! writes "corny hafer schoko" under an item called "Riegel": the
    /// entry stays the generic word, the specific part hangs off it. We copy
    /// that, and the reason is arithmetic rather than taste. `OfferMatcher`
    /// stage 1 requires **every** word of the query to hit a title token, and
    /// stage 2 keeps that an AND. "Landliebe Butter Original" would only be
    /// findable where that exact brand is on offer; everywhere else butter
    /// would count as uncovered, the coverage figure in the plan card would
    /// drop, and the recommended market could change. The same holds for a
    /// fourth word like "Bio".
    ///
    /// Stored as the chosen chips rather than one string so the vocabulary
    /// stays inspectable, and **optional with a default** so lists written by
    /// older builds keep decoding — a tester has had the app on their device
    /// since 2026-07-30, and a list that empties itself on update is the worst
    /// bug this app could ship.
    var detail: [String]?

    /// Die Wahl eines einzelnen Angebots, wie [App #40](https://github.com/Scxttk/lechariot-app/pull/40)
    /// sie gebaut hat — **nur noch als Altlast gelesen, nie geschrieben.**
    ///
    /// Seit [UI-7] (2026-08-01) trägt ein Eintrag `pins` (0..n). Das Feld
    /// bleibt trotzdem stehen, und genau darin liegt die Migration: Auf den
    /// Geräten der Tester liegen Listen mit `pinned`, und `ShoppingListStore`
    /// liest sie mit `try? JSONDecoder().decode(...)`. **Ein umbenanntes Feld
    /// allein macht die gespeicherte Liste nicht unlesbar** — beide sind
    /// optional —, aber die alte Wahl wäre still weg. Deshalb wird `pinned`
    /// beim Dekodieren nach `pins` gehoben (siehe `init(from:)`) und danach
    /// nicht mehr geschrieben.
    ///
    /// Nachgewiesen an einem echten Datensatz von vorher:
    /// `PinnedOfferTests.testAListWrittenWithTheOldSinglePinKeepsItsChoice`.
    private var pinned: PinnedOffer?

    /// Freitext am Artikel — **eine Notiz für den Menschen im Laden**
    /// ([UI-8], Scott 2026-08-01).
    ///
    /// Die Chips daneben sind bewusst ein Wortschatz („es gibt nichts zu
    /// säubern, weil es nichts zu tippen gibt"). Hier gibt es etwas zu tippen,
    /// und damit gilt eine harte Regel: **Dieses Feld verlässt das Gerät
    /// nie.** Es geht nicht in die Suche, nicht in die Marktrechnung und vor
    /// allem nicht in den `MatchFeedback`-Payload — dort landet Freitext sonst
    /// auf einem fremden Server, und niemand weiß, was jemand hineinschreibt.
    /// Festgehalten in `ItemDetailTests.testTheNoteNeverReachesTheFeedbackPayload`.
    ///
    /// Optional, aus demselben Grund wie `detail` und `pins`: Ein Pflichtfeld
    /// ohne Vorgabe löscht jedem Tester beim Update still die Liste.
    var note: String?

    /// Die gewählten Angebote dieses Eintrags — 0..n.
    ///
    /// **Ein zweiter Pin ersetzt den ersten nicht, er kommt dazu** (Scott,
    /// 01.08.): „Milch" kann Bio-Milch *und* normale Milch enthalten, jede als
    /// eigene Position. Pin heißt immer „ich will es"; die Lesart „eins von
    /// beiden" gibt es gratis über die nicht weggeklickten Vorschläge.
    ///
    /// Optional mit Vorgabewert, aus demselben Grund wie `detail`: Ein
    /// Pflichtfeld ohne Vorgabe wäre der Tag, an dem alle Tester beim Update
    /// ihre Liste verlieren — ohne Fehlermeldung.
    var pins: [PinnedOffer]?

    /// Die Wahl(en) dieses Eintrags, egal aus welchem Build sie stammen.
    var pinnedOffers: [PinnedOffer] { pins ?? [] }

    /// Ob das Matching für diesen Platz eingefroren ist.
    var usesAutoMatch: Bool { pinnedOffers.isEmpty }

    init(
        id: UUID = UUID(),
        text: String,
        isChecked: Bool = false,
        addedAt: Date = .now,
        detail: [String]? = nil,
        note: String? = nil,
        pins: [PinnedOffer]? = nil
    ) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
        self.addedAt = addedAt
        self.detail = detail
        self.note = note
        self.pins = pins
        self.pinned = nil
    }

    /// **Der Migrationsschritt, ausdrücklich statt nebenbei.**
    ///
    /// Eine Liste aus einem Build vor dem 2026-08-01 trägt `pinned` und kein
    /// `pins`. Ohne diesen Schritt dekodiert sie zwar sauber — beide Felder
    /// sind optional —, aber die Heftung wäre still verschwunden. „Still" ist
    /// hier das Problem: Der Nutzer sähe wieder das billigste Angebot und
    /// hielte seine Wahl für vergessen.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? .now
        detail = try c.decodeIfPresent([String].self, forKey: .detail)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        pinned = nil
        let stored = try c.decodeIfPresent([PinnedOffer].self, forKey: .pins)
        let alt = try c.decodeIfPresent(PinnedOffer.self, forKey: .pinned)
        pins = stored ?? alt.map { [$0] }
    }

    /// `pinned` wird gelesen, aber nie wieder geschrieben — sonst stünden zwei
    /// Wahrheiten in derselben Datei.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(isChecked, forKey: .isChecked)
        try c.encode(addedAt, forKey: .addedAt)
        try c.encodeIfPresent(detail, forKey: .detail)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(pins, forKey: .pins)
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, isChecked, addedAt, detail, note, pins, pinned
    }

    /// The one string that leaves this item — to the matcher, to the purchase
    /// counter, and into the feedback report.
    ///
    /// It exists so the boundary has a name. `text` alone would work today;
    /// what it would not do is make the next person notice that appending the
    /// detail here is the thing that breaks matching.
    var query: String { text }

    /// The detail as one line, or nil when there is nothing to show.
    ///
    /// Die Notiz hängt hinten dran: Sie steht an derselben Stelle und meint
    /// dasselbe („was genau ich brauche"), nur getippt statt getippt-ausgewählt.
    var detailLine: String? {
        let chips = (detail ?? []).joined(separator: " · ")
        let note = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [chips, note].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
