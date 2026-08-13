import SwiftUI
import UIKit
import XCTest
@testable import LeChariot

/// **Der Bogen für die Einkaufsliste, so wie sie auf dem Gerät steht.**
///
/// Am 06.08. standen hier vier Richtungen nebeneinander, weil eine Entscheidung
/// über Layout am Bild fällt und nicht am Absatz: zwei Nachbauten (B, C), die
/// gebaute Zeilenliste (A) und das Raster (D). **Entschieden ist es seit dem
/// 07.08. — das Raster ist gebaut, die Zeilenliste ist gelöscht.** Damit sind
/// A, B und C keine Alternativen mehr, sondern drei Nachbauten von etwas, das
/// es nicht mehr gibt; sie sind am 08.08. mitgegangen. Geblieben ist D, und D
/// rendert `ShoppingGridTile` selbst — also genau das, was läuft.
///
/// Das Fenster, aus dem die Bilder kommen, und der Weg, sie aus dem
/// `.xcresult` zu holen, stehen seit dem 12.08. in `Fensterbogen` — drei Bögen
/// teilen sich denselben Umweg.
///
/// **Hier stand bis zum 08.08. ein Weg über eine Umgebungsvariable, und der hat
/// nie funktioniert.** Die Anweisung lautete
/// `TEST_RUNNER_LECHARIOT_LIST_SHOTS=…`, mit der Begründung, `xcodebuild` reiche
/// nur so präfigierte Variablen weiter. Nachgemessen: Im Prozess dieses
/// Unit-Ziels kommt **weder** der Name mit Präfix **noch** der ohne an — die
/// Umgebung enthält überhaupt keinen Schlüssel mit „LECHARIOT" darin. Das
/// Präfix-Verfahren gilt für den Läufer eines **UI**-Tests; hier läuft der
/// Bogen im Wirtsprozess der App, und `FOO=bar` hinter `xcodebuild test` ist
/// eine Build-Einstellung, keine Umgebungsvariable. Der Bogen hat sich also
/// stillschweigend übersprungen, egal was man ihm mitgab.
///
/// Anhänge brauchen diese Leitung nicht. Sie kosten dafür bei **jedem** Lauf
/// die zwei Sekunden Zeichenzeit — der Preis dafür, dass der Bogen wirklich
/// etwas liefert, wenn man ihn ruft.
@MainActor
final class ListDirectionShots: XCTestCase {
    func testWriteTheGrid() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .light ? "hell" : "dunkel"
            // Das Raster ist ein voller Einkauf und braucht mehr Höhe als eine
            // Liste mit vier Zeilen — sonst schneidet der Ausschnitt genau die
            // Abschnitte ab, um die es geht.
            try write(DirectionD(), named: "liste-D-raster-\(suffix)", scheme: scheme, hoehe: 1500)
        }

        // **Vorher/Nachher zur Spaltenzahl** (08.08.). Beide Fassungen in
        // *einem* Lauf, damit der Vergleich nicht an zwei Auschecks hängt.
        try write(DirectionD(columns: [GridItem(.adaptive(minimum: 76), spacing: Theme.Spacing.md)]),
                  named: "raster-vorher-vier-393", scheme: .light, hoehe: 1500)
        try write(DirectionD(),
                  named: "raster-nachher-drei-393", scheme: .light, hoehe: 1500)
        // Und die Probe aufs iPad: Dort darf die Kachel **nicht** mitwachsen,
        // sondern es müssen mehr Spalten werden — der Grund, warum `.adaptive`
        // bleibt statt einer festen Drei.
        try write(DirectionD(), named: "raster-nachher-ipad-834",
                  scheme: .light, breite: 834, hoehe: 1200)
    }

    private func write(_ view: some View, named name: String, scheme: ColorScheme,
                       breite: CGFloat? = nil, hoehe: CGFloat? = nil) throws {
        try schreibeBogen(view, named: name, scheme: scheme,
                          groesse: CGSize(width: breite ?? Self.bogenGroesse.width,
                                          height: hoehe ?? Self.bogenGroesse.height))
    }
}

// MARK: - D · Kacheln, wie Bring!

/// **Die Liste hört auf, eine Liste zu sein.**
///
/// Scott, 07.08.: „go more like Bring!" Bring! zeigt Artikel nicht als Zeilen,
/// sondern als **Raster kleiner Kacheln** — gezeichnetes Zeichen oben, Wort
/// darunter, vier nebeneinander. Man liest es nicht von oben nach unten, man
/// **erkennt** es: Der Einkauf ist auf einen Blick da, statt gescrollt zu
/// werden.
///
/// **Warum das hier besser passt als bei jeder anderen App, die es abkupfert:**
/// Le Chariot hat die Zeichnungen längst. `CategoryGlyphView` sind **fünfzehn
/// von Hand gezeichnete Zeichen**, und die Erkundung vom 06.08. hat gezählt,
/// wie oft man sie zu sehen bekam — an *einer* Stelle, als Rückfall eines
/// Rückfalls. Das Raster ist die Form, in der dieser Posten endlich arbeitet.
///
/// **Was Bring! nicht lösen muss und wir schon.** Bei Bring! ist die Kachel
/// nur Artikel plus Menge; die Aktionen liegen in einem eigenen Bereich. Hier
/// trägt der Einkauf den Preis mit — deshalb sitzt das Angebot als **kleine
/// Fahne an der Ecke des Zeichens**, nicht als eigene Zeile. Wer nur einkaufen
/// will, sieht das Raster; wer den Preis sucht, findet ihn, ohne dass er die
/// Fläche beherrscht.
///
/// **Und keine Karten.** Bring! setzt jede Kachel auf ein weißes Kärtchen mit
/// Schatten. Genau das ist der Container, gegen den Scotts ganze Runde am
/// 06.08. lief — das Zeichen hat eine eigene Silhouette und braucht keinen
/// Rahmen, der ihm eine gibt.
private struct DirectionD: View {
    /// Seit dem 07.08. rendert dieser Bogen **die gebaute Kachel**
    /// (`ShoppingGridTile`) und keinen Nachbau mehr. Die zwei Entwürfe, mit
    /// denen die Richtung entschieden wurde — Kategoriezeichen und Emoji —
    /// sind damit erledigt: Die Frage, die sie beantwortet haben, ist
    /// beantwortet.
    ///
    /// Die Spalten kommen aus `ShoppingGridTile.columns` — also aus derselben
    /// Konstante, aus der die App sie nimmt. Überschrieben wird sie nur für
    /// das Vorher-Bild der Spaltenrunde vom 08.08.
    var columns: [GridItem] = ShoppingGridTile.columns

    var body: some View {
        List {
            abschnitt("Obst & Gemüse", ShotGrid.obst)
            abschnitt("Molkerei & Eier", ShotGrid.molkerei)
            abschnitt("Fleisch & Wurst", ShotGrid.fleisch)
            abschnitt("Vorräte & Kochen", ShotGrid.vorrat)
            abschnitt("Backwaren", ShotGrid.backwaren)
            abschnitt("Haushalt", ShotGrid.haushalt)
            abschnitt("Erledigt", ShotGrid.erledigt, kopfzeichen: false)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    @ViewBuilder
    private func abschnitt(_ titel: String, _ einträge: [ShotGrid.Eintrag],
                           kopfzeichen: Bool = true) -> some View {
        Section {
            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: Theme.Spacing.lg
            ) {
                ForEach(einträge) { eintrag in
                    ShoppingGridTile(
                        item: ShoppingItem(
                            text: eintrag.name,
                            isChecked: eintrag.erledigt,
                            detail: eintrag.unterzeile.map { [$0] }
                        ),
                        suggestion: vorschlag(eintrag),
                        onToggle: {}, onOpenItem: {}, onDelete: {}
                    )
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: Theme.Spacing.xs, leading: Theme.Spacing.lg,
                bottom: Theme.Spacing.xs, trailing: Theme.Spacing.lg
            ))
        } header: {
            HStack(spacing: Theme.Spacing.sm) {
                if kopfzeichen {
                    CategoryGlyphView(category: einträge.first?.kategorie ?? "", size: 15)
                        .foregroundStyle(Theme.accent)
                }
                Text(titel)
            }
        }
    }

    /// Ein Angebot nur dort, wo der Eintrag einen Preis trägt — die Fahne soll
    /// im Bild genauso oft fehlen wie in einem echten Einkauf.
    private func vorschlag(_ eintrag: ShotGrid.Eintrag) -> ItemSuggestion {
        guard let preis = eintrag.preis else { return ItemSuggestion(match: nil) }
        let angebot = Offer(
            marketId: "lidl-01219-1", market: eintrag.unterzeile ?? "Lidl",
            product: eintrag.name, price: preis, regularPrice: preis * 1.3,
            unit: nil, category: eintrag.kategorie, emoji: eintrag.emoji,
            validFrom: Date(), validUntil: Date(), basePrice: nil, baseUnit: nil,
            nationwide: true
        )
        return ItemSuggestion(match: OfferMatch(offer: angebot, kind: .direct))
    }
}

/// Ein voller Einkauf statt vier Zeilen — ein Raster mit vier Kacheln sagt
/// nichts darüber aus, ob ein Raster trägt.
private enum ShotGrid {
    struct Eintrag: Identifiable {
        let name: String
        let kategorie: String
        var unterzeile: String? = nil
        /// Das Emoji, das das zugeordnete Angebot mitbringt. Nil heißt: zu
        /// diesem Artikel gibt es diese Woche nichts — dann bleibt nur das
        /// Kategoriezeichen.
        var emoji: String? = nil
        var preis: Double? = nil
        var erledigt = false
        var id: String { name }
    }

    static let obst: [Eintrag] = [
        Eintrag(name: "Erdbeeren", kategorie: "Obst & Gemüse", unterzeile: "Netto", emoji: "🍓", preis: 1.99),
        Eintrag(name: "Bananen", kategorie: "Obst & Gemüse", emoji: "🍌"),
        Eintrag(name: "Tomaten", kategorie: "Obst & Gemüse", unterzeile: "500 g", emoji: "🍅"),
        Eintrag(name: "Zwiebeln", kategorie: "Obst & Gemüse", emoji: "🧅"),
        Eintrag(name: "Salat", kategorie: "Obst & Gemüse", emoji: "🥬"),
        Eintrag(name: "Gurke", kategorie: "Obst & Gemüse"),
        Eintrag(name: "Zucchini", kategorie: "Obst & Gemüse"),
        Eintrag(name: "Paprika", kategorie: "Obst & Gemüse", unterzeile: "rot"),
    ]

    /// **Die Becher.** Der härteste Fall des Satzes: Frischkäse, Quark,
    /// Joghurt, Sahne und Margarine sind in Wirklichkeit derselbe Becher, und
    /// im Raster stehen sie nebeneinander. Wenn das hier auseinanderfällt,
    /// fällt es überall auseinander.
    static let molkerei: [Eintrag] = [
        Eintrag(name: "Milch", kategorie: "Molkerei & Eier", unterzeile: "2 l · Bio", emoji: "🥛", preis: 0.99),
        Eintrag(name: "Butter", kategorie: "Molkerei & Eier", emoji: "🧈", preis: 1.49),
        Eintrag(name: "Eier", kategorie: "Molkerei & Eier", unterzeile: "10er", emoji: "🥚"),
        Eintrag(name: "Joghurt", kategorie: "Molkerei & Eier", emoji: "🥣"),
        Eintrag(name: "Quark", kategorie: "Molkerei & Eier"),
        Eintrag(name: "Frischkäse", kategorie: "Molkerei & Eier"),
        Eintrag(name: "Sahne", kategorie: "Molkerei & Eier"),
        Eintrag(name: "Margarine", kategorie: "Molkerei & Eier"),
    ]

    /// **Die Fleischtheke.** Zehn Begriffe, die alle „Stück Tier" heißen.
    static let fleisch: [Eintrag] = [
        Eintrag(name: "Hackfleisch", kategorie: "Fleisch & Wurst", unterzeile: "500 g"),
        Eintrag(name: "Hähnchen", kategorie: "Fleisch & Wurst"),
        Eintrag(name: "Bratwurst", kategorie: "Fleisch & Wurst"),
        Eintrag(name: "Salami", kategorie: "Fleisch & Wurst"),
        Eintrag(name: "Fleisch", kategorie: "Fleisch & Wurst"),
        Eintrag(name: "Putenschnitzel", kategorie: "Fleisch & Wurst"),
        Eintrag(name: "Lachs", kategorie: "Fisch", unterzeile: "TK"),
        Eintrag(name: "Tofu", kategorie: "Vorräte & Kochen"),
    ]

    /// **Die Flaschen und Dosen**, aus demselben Grund wie die Becher.
    static let vorrat: [Eintrag] = [
        Eintrag(name: "Olivenöl", kategorie: "Vorräte & Kochen"),
        Eintrag(name: "Essig", kategorie: "Vorräte & Kochen"),
        Eintrag(name: "Wein", kategorie: "Alkohol", preis: 4.99),
        Eintrag(name: "Sprudel", kategorie: "Getränke", unterzeile: "6 × 1,5 l"),
        Eintrag(name: "Cola", kategorie: "Getränke"),
        Eintrag(name: "Mais", kategorie: "Vorräte & Kochen"),
        Eintrag(name: "Nudeln", kategorie: "Vorräte & Kochen"),
        Eintrag(name: "Reis", kategorie: "Vorräte & Kochen"),
    ]

    static let backwaren: [Eintrag] = [
        Eintrag(name: "Brot", kategorie: "Backwaren", unterzeile: "Vollkorn", emoji: "🍞"),
        Eintrag(name: "Brötchen", kategorie: "Backwaren", emoji: "🥐"),
    ]

    static let haushalt: [Eintrag] = [
        Eintrag(name: "Zahnpasta", kategorie: "Drogerie"),
        Eintrag(name: "Spülmittel", kategorie: "Haushalt", emoji: "🧴"),
        Eintrag(name: "Müllbeutel", kategorie: "Haushalt"),
    ]

    static let erledigt: [Eintrag] = [
        Eintrag(name: "Orangen", kategorie: "Obst & Gemüse", emoji: "🍊", erledigt: true),
        Eintrag(name: "Kaffee", kategorie: "Vorräte & Kochen", emoji: "☕️", erledigt: true),
    ]
}

