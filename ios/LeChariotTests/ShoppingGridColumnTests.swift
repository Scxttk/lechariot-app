import SwiftUI
import UIKit
import XCTest
@testable import LeChariot

/// **Wie viele Kacheln nebeneinander stehen — gemessen, nicht gerechnet.**
///
/// Scott am 08.08.: drei je Reihe statt vier, „Bring! nimmt drei". Die
/// Umsetzung ist eine einzige Zahl (`ShoppingGridTile.columns`), und genau
/// deshalb ist sie gefährlich: `.adaptive(minimum:)` gibt die Spaltenzahl nicht
/// an, sie **fällt aus** Breite, Rand und Spaltenabstand heraus. Eine Zahl, die
/// auf dem Testgerät drei ergibt, kann auf dem nächsten iPhone vier ergeben,
/// ohne dass irgendwo etwas rot wird.
///
/// Der Test hängt das **gebaute** `columns` in ein echtes Fenster und liest die
/// Rahmen der Zellen ab. Er misst damit dieselbe Rechnung, die SwiftUI auf dem
/// Gerät anstellt — und nicht die, die hier jemand nachgebildet hat.
///
/// **Warum auch das iPad drinsteht.** Die naheliegende Umsetzung wäre
/// `GridItem(.flexible())` dreimal gewesen. Auf dem iPad wären das drei Kacheln
/// von über 300 pt Breite — ein 40-pt-Zeichen in einem Feld von 300. Der Test
/// hält beides zusammen: iPhone drei Spalten, iPad mehr, und die Kachel überall
/// in derselben Größenordnung.
@MainActor
final class ShoppingGridColumnTests: XCTestCase {
    /// Die Breiten, auf denen die Liste wirklich steht — von der schmalsten
    /// iPhone-Fläche (SE, und jedes iPhone mit „Größere Textanzeige") bis zum
    /// iPad Pro im Hochformat.
    private static let iPhoneWidths: [CGFloat] = [375, 390, 393, 402, 430, 440]
    private static let iPadWidths: [CGFloat] = [744, 834, 1024, 1210]

    func testThreeTilesPerRowOnEveryIPhoneWidth() throws {
        for width in Self.iPhoneWidths {
            let (spalten, kachel) = try messen(width: width)
            XCTAssertEqual(spalten, 3,
                           "Auf \(Int(width)) pt stehen \(spalten) Kacheln je Reihe, nicht drei")
            // Die Kachel trägt ein 52-pt-Zeichen und ein Wort darunter; unter
            // 100 pt wäre die Änderung folgenlos, über 140 hätte das Zeichen
            // mehr Rand als Inhalt.
            XCTAssertTrue((100...140).contains(kachel),
                          "Kachelbreite \(kachel) pt auf \(Int(width)) pt liegt außerhalb 100–140")
        }
    }

    /// **Das iPad bekommt mehr Spalten, nicht breitere Kacheln.** Das ist der
    /// ganze Grund, warum `.adaptive` bleibt und keine feste Drei einzieht.
    func testTheIPadGetsMoreColumnsAtTheSameTileSize() throws {
        for width in Self.iPadWidths {
            let (spalten, kachel) = try messen(width: width)
            XCTAssertGreaterThan(spalten, 3,
                                 "Auf \(Int(width)) pt wären \(spalten) Spalten zu wenig")
            XCTAssertTrue((100...140).contains(kachel),
                          "Kachelbreite \(kachel) pt auf \(Int(width)) pt liegt außerhalb 100–140")
        }
    }

    /// **Die Gegenprobe.** Ohne sie wäre nicht bewiesen, dass der Messaufbau
    /// überhaupt etwas misst: Mit dem alten Mindestmaß muss dieselbe Messung
    /// auf 393 pt die alten **vier** Spalten ergeben.
    func testTheHarnessWouldStillSeeTheOldFourColumns() throws {
        let (spalten, _) = try messen(
            width: 393,
            columns: [GridItem(.adaptive(minimum: 76), spacing: Theme.Spacing.md)]
        )
        XCTAssertEqual(spalten, 4, "Der Messaufbau misst nicht, was er messen soll")
    }

    // MARK: Der Messaufbau

    /// Hängt das Raster in ein Fenster dieser Breite und gibt zurück, wie viele
    /// Zellen in der ersten Reihe stehen und wie breit eine ist.
    ///
    /// Zwölf Zellen, damit auch auf dem iPad mehr als eine Reihe entsteht — mit
    /// vier Zellen wäre „alle in einer Reihe" kein Befund über die Spaltenzahl.
    private func messen(
        width: CGFloat, columns: [GridItem] = ShoppingGridTile.columns
    ) throws -> (spalten: Int, kachelbreite: CGFloat) {
        let box = FrameBox()
        let probe = GridProbe(columns: columns, count: 12, box: box)
            // Genau die Einzüge, die die Zeile der `List` dem Raster lässt
            // (`listRowInsets` in `ShoppingListView.raster`). Ohne sie misst
            // der Test eine Breite, die es auf dem Bildschirm nicht gibt.
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(width: width)

        let host = UIHostingController(rootView: probe)
        // Dasselbe wie im Bilderbogen: ein Fenster ohne Szene bekommt kein
        // Layout, und dann stünden alle Rahmen auf .zero.
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: width, height: 900)
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        let frames = box.frames
        XCTAssertFalse(frames.isEmpty, "Das Raster hat keine Zellen gelegt")
        let ersteZeile = try XCTUnwrap(frames.map(\.minY).min())
        // 1 pt Toleranz: Rahmen derselben Reihe können sich im letzten
        // Nachkommastellen-Bit unterscheiden.
        let inDerZeile = frames.filter { abs($0.minY - ersteZeile) < 1 }
        let breite = try XCTUnwrap(inDerZeile.map(\.width).max())
        return (inDerZeile.count, breite.rounded())
    }
}

// MARK: - Rahmen einsammeln

private final class FrameBox {
    var frames: [CGRect] = []
}

private struct CellFrameKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value += nextValue()
    }
}

/// Leere Zellen statt echter Kacheln: Gemessen wird das **Raster**, und eine
/// echte Kachel brächte ihre eigene Höhe und ihr Wörterbuch mit, ohne an der
/// Spaltenrechnung etwas zu ändern.
private struct GridProbe: View {
    let columns: [GridItem]
    let count: Int
    let box: FrameBox

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.lg) {
            ForEach(0..<count, id: \.self) { _ in
                Color.clear
                    .frame(height: 40)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: CellFrameKey.self,
                                value: [geo.frame(in: .named("raster"))]
                            )
                        }
                    )
            }
        }
        .coordinateSpace(name: "raster")
        .onPreferenceChange(CellFrameKey.self) { box.frames = $0 }
    }
}
