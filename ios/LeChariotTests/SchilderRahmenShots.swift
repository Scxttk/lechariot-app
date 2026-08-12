import SwiftUI
import TipKit
import UIKit
import XCTest
@testable import LeChariot

/// **Alle vier Schilder auf einem Blatt, hell und dunkel** — Bedienrunde
/// 11.08., Punkt 3: „Bei Tipps der Rahmen ist nicht ganz zu sehen wegen den
/// Container Abrundungen."
///
/// **Warum hier und nicht in `SchilderShots`.** Der UI-Bogen fotografiert die
/// laufende App und bekommt deshalb genau die Schilder, die der Store gerade
/// für aktiv erklärt — **eines je Fläche und Sitzung**
/// (`ContextTipTuning.tipsPerSurfaceAndSession`). Vier Schilder wären vier
/// Läufe. Hier steht dieselbe Einbettung wie in `ShoppingListView` und
/// `OffersView` (Abschnitt in einer `.plain`-Liste, `listRowInsets`, klarer
/// Zeilenhintergrund) und darin alle vier auf einmal.
///
/// Der UI-Bogen bleibt trotzdem der Schiedsrichter für „steht es auf dem
/// Gerät" — dieser hier ist der für „ist der Rahmen ganz da".
@MainActor
final class SchilderRahmenShots: XCTestCase {
    override func setUp() {
        super.setUp()
        // `TipView` zeichnet nur, was TipKit für zeigbar hält. Die vier Tipps
        // tragen keine Regeln (siehe `ContextTipViews`), aber der Merker eines
        // früheren Laufs im App-Container würde sie stumm schalten.
        Tips.showAllTipsForTesting()
    }

    override func tearDown() {
        Tips.hideAllTipsForTesting()
        super.tearDown()
    }

    /// **Ein Schild je Bild, und das ist keine Bequemlichkeit.** Vier Schilder
    /// in einer Liste standen im ersten Anlauf mit vierhundert Punkten Leerraum
    /// dazwischen — eine Lage, die es auf dem Gerät nicht gibt (je Fläche steht
    /// eines). Beurteilt würde dann der Bogen und nicht die App.
    func testDieVierSchilderMitGanzemRahmen() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .light ? "hell" : "dunkel"
            try schild(SchilderBogen { TipView(NextWeekContextTip()) },
                       "schild-vorschau-\(suffix)", scheme)
            try schild(SchilderBogen { TipView(MatchLineContextTip()) },
                       "schild-angebotszeile-\(suffix)", scheme)
            try schild(SchilderBogen { TipView(ItemDetailsContextTip()) },
                       "schild-angaben-\(suffix)", scheme)
            try schild(SchilderBogen { TipView(CheckOffContextTip()) },
                       "schild-abhaken-\(suffix)", scheme)
        }
    }

    private func schild(_ bogen: some View, _ name: String, _ scheme: ColorScheme) throws {
        // `TipView` blendet sich ein; bei 0,35 s steht es halbdurchsichtig im
        // Bild, und ein halbdurchsichtiger Rahmen beantwortet die Frage nicht.
        try schreibeBogen(bogen, named: name, scheme: scheme,
                          groesse: CGSize(width: 393, height: 340), ruhe: 1.5)
    }
}

/// Ein Schild in der Einbettung, in der es auf dem Gerät steht.
private struct SchilderBogen<Inhalt: View>: View {
    @ViewBuilder let inhalt: () -> Inhalt

    var body: some View {
        List {
            // Wortgleich mit dem Abschnitt um `ContextTipCard` in
            // `ShoppingListView` und `OffersView` — der Bogen prüft die
            // Einbettung, also muss sie dieselbe sein.
            Section {
                inhalt()
                    .emailschild {}
                    .listRowInsets(EdgeInsets(
                        top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                        bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                    ))
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }
}
