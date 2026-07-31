import CoreGraphics

/// Wohin das Loch des Rundgangs als Nächstes springt — und ob dabei animiert
/// wird.
///
/// Steht als eigener, reiner Typ da und nicht als drei Zeilen im Overlay, weil
/// genau diese Entscheidung der gemeldete Ruckler ist: Eine Animation kann
/// kein Test ansehen, die Entscheidung darüber schon.
///
/// **Der Fehler, gegen den er gebaut ist.** Bis zum 2026-07-31 stand im
/// Overlay `resolvedHole ?? .zero`. Die Anker kommen aber einen
/// Layout-Durchgang **nach** dem Schrittwechsel — bei 2→3 baut sich die Liste
/// darunter um (der gelegte Artikel lässt die Plan-Karte erscheinen), bei 6→7
/// wechselt sogar der Tab. In diesem Durchgang war das Loch also `.zero`, und
/// weil die Abdunklung auf den Schrittindex animiert, **schrumpfte das Loch
/// sichtbar zur linken oberen Ecke und verschwand**; wenn der Anker dann
/// eintraf, sprang es ungefedert an seinen neuen Platz, denn der Index hatte
/// sich da schon nicht mehr geändert. Zwei Bewegungen, von denen keine
/// gewollt war — genau die zwei Übergänge, die gemeldet wurden.
enum SpotlightTransition {
    struct Move: Equatable {
        let rect: CGRect
        /// Nur der Schrittwechsel wird geflogen. Bewegt sich dasselbe Ziel
        /// (Tastatur, Scrollen), springt das Loch sofort mit — sonst schwämme
        /// es dem Finger hinterher, und das war der Grund, aus dem hier
        /// überhaupt auf den Index und nicht auf das Rechteck animiert wird.
        let animated: Bool
    }

    /// - Returns: `nil`, wenn nichts zu tun ist — insbesondere, solange für
    ///   den neuen Schritt noch **kein** Anker gemeldet ist. Das alte Loch
    ///   bleibt dann stehen. Ein Loch, das einen Wimpernschlag zu lange auf
    ///   dem vorigen Ziel liegt, ist besser als eins, das in die Ecke fliegt.
    static func move(
        shown: CGRect,
        shownIndex: Int,
        resolved: CGRect?,
        index: Int
    ) -> Move? {
        guard let resolved else { return nil }
        if index != shownIndex {
            // `shownIndex < 0` heißt: Das Overlay ist gerade erschienen und hat
            // noch nie ein Loch gezeigt. Da gibt es nichts zu fliegen — ein
            // Loch, das aus der linken oberen Ecke aufzieht, wäre schlechter
            // als eins, das einfach da ist. Genau das tat es bisher auch.
            return Move(rect: resolved, animated: shownIndex >= 0)
        }
        guard resolved != shown else { return nil }
        return Move(rect: resolved, animated: false)
    }
}
