import SwiftUI
import XCTest
@testable import LeChariot

/// **„Dei ne Wa hl"** — gemeldet am 2026-08-01 aus Build `2026.0801.1951`.
///
/// Das Pin-Abzeichen stand in der Einkaufsliste in einer engen Spalte neben
/// Bild, Rabatt und Preis. Es bekam den Rest der Breite und brach mitten im
/// Wort um; auf dem Gerät standen vier Silben untereinander.
///
/// **Warum gemessen und nicht angesehen.** „Bricht nicht um" ist eine Aussage
/// über Geometrie, und die einzige ehrliche Prüfung dafür ist, dem Abzeichen zu
/// wenig Platz anzubieten und nachzusehen, ob es höher wird. Ein Blick auf den
/// Quelltext („da steht doch `lineLimit`") prüft die Absicht, nicht das
/// Ergebnis — und ein Screenshot-Vergleich fiele bei jeder Farbänderung um.
///
/// Der Vergleich ist **relativ**: dieselbe Ansicht einmal mit reichlich und
/// einmal mit knappem Platz. Eine absolute Höhe in Punkten wäre eine Zahl, die
/// mit der nächsten Schriftgröße falsch wird, ohne dass etwas kaputt ist.
///
/// **Gemessen wird seit dem Raster nur noch `PinnedBadge`.** Die Liste trägt
/// seit dem 07.08. gar kein Textabzeichen mehr — die Kachel setzt eine bloße
/// Reißzwecke an die Preisfahne, und die kann nicht umbrechen. Mit der
/// Zeilenansicht ist am 08.08. auch `PinnedChip` gegangen, der hier bis dahin
/// geprüft wurde. Das Abzeichen mit Wortlaut steht jetzt im Angebotsdetail
/// (`ItemSheet`), also wird dort gemessen; der Fall ist derselbe
/// geblieben: enge Spalte, Nachbartext daneben.
@MainActor
final class BadgeLayoutTests: XCTestCase {
    /// Enger als jede Spalte, in der das Abzeichen je stehen kann — es selbst
    /// ist rund 80 pt breit.
    private let squeezed: CGFloat = 44
    private let roomy: CGFloat = 400

    func testThePinnedBadgeInTheDetailNeverWrapsMidWord() {
        assertDoesNotGrowWhenSqueezed(PinnedBadge(), name: "PinnedBadge")
    }

    /// Die Zeile, in der das Abzeichen auf dem Gerät wirklich steht: Abzeichen
    /// und Marktname nebeneinander in einer schmalen Spalte — der Fall aus der
    /// Meldung, nicht nur das Bauteil für sich. Bei einer Heftung ist der
    /// Nachbar genau der Marktname (`ItemSheet`).
    ///
    /// Der Marktname ist hier einzeilig festgehalten. Ohne das misst der Test
    /// **seinen** Umbruch mit (bei 110 pt wurde die Zeile 144 pt hoch, und
    /// keine 8 pt davon gehörten dem Abzeichen) — eine Zahl, die nichts über
    /// das Abzeichen aussagt und beim ersten langen Kettennamen rot wird.
    func testTheBadgeKeepsItsLineNextToTheMarketName() {
        let row = HStack(spacing: 4) {
            PinnedBadge()
            Text("Netto Marken-Discount")
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        assertDoesNotGrowWhenSqueezed(row, name: "Abzeichen neben Marktname", squeezedWidth: 110)
    }

    /// Und die andere Hälfte derselben Aussage: Das Abzeichen lässt sich nicht
    /// schmaler drücken, als sein Text braucht. Wäre nur die Höhe geprüft,
    /// ginge ein auf „Deine W…" gekürztes Abzeichen als grün durch.
    func testTheBadgeKeepsItsFullWidthWhenSqueezed() {
        let wide = size(of: PinnedBadge(), proposing: roomy)
        let narrow = size(of: PinnedBadge(), proposing: squeezed)
        XCTAssertEqual(
            narrow.width, wide.width, accuracy: 0.5,
            "das Abzeichen gibt bei \(squeezed) pt Angebot Breite ab (\(narrow.width) statt \(wide.width)) — dann kürzt es den Text"
        )
    }

    // MARK: Messung

    private func assertDoesNotGrowWhenSqueezed(
        _ view: some View,
        name: String,
        squeezedWidth: CGFloat? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let narrow = squeezedWidth ?? squeezed
        let tall = size(of: view, proposing: narrow).height
        let flat = size(of: view, proposing: roomy).height
        XCTAssertEqual(
            tall, flat, accuracy: 0.5,
            """
            \(name) wird bei \(narrow) pt Breite \(tall) pt hoch statt \(flat) pt — \
            der Text bricht um. Genau so entstand „Dei ne Wa hl".
            """,
            file: file, line: line
        )
    }

    /// Die Größe, die die Ansicht unter einer angebotenen Breite tatsächlich
    /// einnimmt.
    ///
    /// **Nicht über `ImageRenderer` mit einem `frame`.** Der erste Anlauf tat
    /// das und maß sich selbst: `.frame(maxWidth: 44)` *setzt* die Breite auf
    /// 44, also kam 44 zurück, egal wie breit der Chip wirklich ist — die
    /// Breitenprüfung war eine Tautologie und meldete einen Umbruch, den es
    /// nicht gab. `sizeThatFits` **bietet** die Breite an und gibt zurück, was
    /// die Ansicht daraus macht. Das ist genau die Frage.
    private func size(of view: some View, proposing width: CGFloat) -> CGSize {
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
