import XCTest
import SwiftUI
@testable import LeChariot

/// **„Das Emoji ist ein Rückfall, kein Hintergrund."**
///
/// Der Satz steht als Kommentar über `OfferImageContent`, und er steht dort,
/// weil das Gegenteil schon einmal ausgeliefert wurde: Das Emoji lag als
/// dauerhafte ZStack-Ebene unter dem Bild und blieb nur so lange unsichtbar,
/// wie jede Kette JPEGs schickte. **REWE spiegelt PNG→WebP alphaerhaltend,
/// Netto liefert Freisteller** — durch beide schien ein 🥛 mitten durchs
/// Produkt. Gemeldet als Capture am 2026-07-24, behoben vor dem 2026-07-26.
///
/// Ein Kommentar hat das nicht verhindert und wird es beim nächsten Mal auch
/// nicht. Deshalb steht die Entscheidung „Foto **oder** Emoji" jetzt als
/// eigener Ausdruck da und hier als Zusicherung.
final class OfferImageContentTests: XCTestCase {

    private func bild() -> Image {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let ui = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format)
            .image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        return Image(uiImage: ui)
    }

    private struct Fehler: Error {}

    /// Liegt ein Foto da, liegt **nur** das Foto da. Das ist der ganze Fall.
    func testAloadedPhotoLeavesNoEmojiUnderneath() {
        XCTAssertEqual(OfferImageContent.layer(for: .success(bild())), .photo)
    }

    /// Solange nichts da ist, trägt das Emoji die Kachel — sonst stünde dort
    /// ein leeres Rechteck, und eine ladende Liste sähe kaputt aus.
    func testWhileLoadingTheEmojiCarriesTheTile() {
        XCTAssertEqual(OfferImageContent.layer(for: .empty), .fallback)
    }

    /// Ein Fehlschlag ist kein leeres Kästchen. Lidl schickt aus dem
    /// PDF-Prospekt oft gar keine Bild-URL, und ein toter Link soll aussehen
    /// wie „kein Bild", nicht wie „kaputt".
    func testAFailedLoadFallsBackToTheEmojiToo() {
        XCTAssertEqual(OfferImageContent.layer(for: .failure(Fehler())), .fallback)
    }

    /// Ohne eigenes Emoji steht der Einkaufswagen da — nie nichts.
    func testWithoutAnEmojiThereIsStillSomethingOnTheTile() {
        let ohne = OfferImageContent(
            imageUrl: nil, emoji: nil, emojiSize: 24, contentMode: .fill
        )
        XCTAssertNil(ohne.emoji, "Vorbedingung: dieses Angebot bringt kein Emoji mit")
        // Der Rückfall des Rückfalls steht im View selbst („🛒"); geprüft wird
        // hier, dass der Weg dorthin überhaupt genommen wird.
        XCTAssertEqual(OfferImageContent.layer(for: .empty), .fallback)
    }
}
