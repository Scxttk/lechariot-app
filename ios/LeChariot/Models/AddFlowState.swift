import Foundation

/// Der Tipp-Fluss: welcher Artikel gerade seine Angaben unten stehen hat, und
/// welche kurz davor angelegt wurden.
///
/// **Warum das ein eigener Typ ist.** Die Regeln sind winzig und alle drei
/// unsichtbar, wenn man auf den Bildschirm sieht: Was passiert mit dem
/// vorigen Artikel, wenn ein neuer dazukommt? Was, wenn derselbe Artikel
/// zweimal angetippt wird? Was, wenn der aktive Artikel gelöscht wird? In der
/// Ansicht wären das drei `if`, die nur eine Journey prüfen kann — hier sind es
/// drei Zeilen, die ein Unit-Test in Millisekunden durchspielt.
///
/// Gehalten werden **Identitäten, keine Artikel**. Ein `ShoppingItem` hier
/// wäre eine Kopie vom Moment des Anlegens und wüsste nichts von den Chips,
/// die man ihm danach gibt — genau die Falle, die `detailItem` in der Liste
/// schon einmal gestellt hat.
struct AddFlowState: Equatable {
    /// Wie viele Artikel die Kachelzeile über dem Panel trägt. Vier, weil das
    /// die Reihe auf einem iPhone ohne Scrollen füllt; bei Bring! sind es
    /// ebenso viele, bevor die Reihe seitlich wandert.
    static let recentLimit = 4

    /// Die zuletzt angelegten Artikel, ältester zuerst. Der letzte ist der
    /// neueste — die Zeile zeigt sie in dieser Reihenfolge.
    private(set) var recent: [UUID] = []

    /// Der Artikel, dessen Angaben das Panel zeigt.
    private(set) var activeID: UUID?

    var isActive: Bool { activeID != nil }

    /// Ein Artikel ist entstanden: Er wird der aktive und rückt in die Zeile.
    mutating func added(_ id: UUID) {
        aufnehmen(id)
    }

    /// Artikel nach hinten in die Zeile und aktiv machen. Zwei Aufrufer mit
    /// zwei Anlässen (`added`, `reopen`) und **einer** Regel dahinter — die
    /// Länge der Zeile ist eine davon, und sie darf nicht an zwei Stellen
    /// stehen.
    private mutating func aufnehmen(_ id: UUID) {
        recent.removeAll { $0 == id }
        recent.append(id)
        if recent.count > Self.recentLimit {
            recent.removeFirst(recent.count - Self.recentLimit)
        }
        activeID = id
    }

    /// Eine Kachel der Zeile wurde angetippt. Sie **wechselt nur den Blick** —
    /// die Reihenfolge der Zeile bleibt, sonst wanderte die Kachel unter dem
    /// Finger davon.
    mutating func focus(_ id: UUID) {
        guard recent.contains(id) else { return }
        activeID = id
    }

    /// **Ein Artikel, der schon auf der Liste steht, bekommt seine Angaben
    /// wieder** — Scotts Feldtest vom 09.08.: „Kohl steht da und ich komme an
    /// seine Angaben nicht mehr heran."
    ///
    /// Der Unterschied zu `focus` ist die einzige Zeile, die es hier braucht:
    /// `focus` wechselt **innerhalb** der Kachelzeile und lehnt alles ab, was
    /// nicht schon darin steht — genau richtig für einen Tipp auf die Zeile,
    /// und genau falsch für einen Artikel von weiter oben aus der Liste. Der
    /// kommt hier dazu, statt abzuprallen.
    ///
    /// Der Unterschied zu `added` ist, dass hier nichts entstanden ist. Für die
    /// Zeile ist das dasselbe (der Artikel rückt nach hinten und wird aktiv),
    /// für alles, was am Anlegen hängt, nicht — deshalb ein eigener Name.
    mutating func reopen(_ id: UUID) {
        aufnehmen(id)
    }

    /// Der Fluss ist vorbei — die Tastatur ist unten, oder es wurde etwas
    /// anderes geöffnet. Bei Bring! macht das „Abbrechen": Es beendet das
    /// Tippen insgesamt, nicht die Angaben zu einem Artikel.
    mutating func end() {
        recent = []
        activeID = nil
    }

    /// Ein Artikel ist von der Liste verschwunden (gelöscht, Liste geleert).
    /// Der Blick fällt dann auf den nächstjüngeren, nicht ins Leere.
    mutating func forget(_ id: UUID) {
        recent.removeAll { $0 == id }
        guard activeID == id else { return }
        activeID = recent.last
    }

    /// Alles behalten, was es noch gibt. Die Liste ist die Wahrheit; der Fluss
    /// hält nur Zeiger darauf.
    mutating func keepOnly(_ existing: Set<UUID>) {
        let gone = recent.filter { !existing.contains($0) }
        for id in gone { forget(id) }
    }
}
