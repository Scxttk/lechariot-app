import SwiftUI
import UIKit
import XCTest
@testable import LeChariot

/// **Die drei Richtungen für die Liste, nebeneinander zum Ansehen.**
///
/// Am 06.08. standen drei Vorschläge im Raum, wie die Einkaufsliste ihre
/// Rechtecke loswird. Gebaut wurde A; B und C existierten nur als Absatz in
/// einem Bericht. Scott soll aber entscheiden, und **eine Entscheidung über
/// Layout trifft man am Bild, nicht am Absatz.**
///
/// | | Idee |
/// |---|---|
/// | **B** | Ein Blatt, viele Zeilen — nur die zwei inneren Rechtecke weg, die Abschnittsfläche bleibt |
/// | **A** | Linien statt Kästen — gar keine Flächen, Haarlinien, Kategoriezeichen (**heute im Bau**) |
/// | **C** | Preisspalte — das Angebot ist kein verschachteltes Objekt, sondern eine Spalte |
///
/// **A ist echt, B und C sind Entwürfe.** A rendert `ShoppingListRowView`
/// selbst, also genau das, was auf dem Gerät läuft. B und C sind hier
/// nachgebaut — mit denselben Bausteinen (`OfferThumbnail`, `PriceText`,
/// `DiscountBadge`, `PinnedChip`) und denselben Theme-Werten, aber es ist
/// nachgebaut und nicht die App. Wer B oder C wählt, bekommt danach den echten
/// Umbau.
///
/// **Warum `drawHierarchy` und nicht `ImageRenderer`.** Eine `List` ist
/// UIKit-getragen; `ImageRenderer` bekommt davon eine leere Fläche. Der Umweg
/// über ein echtes Fenster kostet zwei Zeilen und liefert das, was der
/// Bildschirm zeigt — samt Trennlinien, Einzügen und Abschnittsköpfen, also
/// genau den Unterschieden, um die es hier geht.
///
/// Läuft **nur auf Zuruf**, sonst schreibt jeder Testlauf PNGs:
///
///     LECHARIOT_LIST_SHOTS=/pfad/zum/ordner xcodebuild test …
@MainActor
final class ListDirectionShots: XCTestCase {
    private var outDir: String? {
        ProcessInfo.processInfo.environment["LECHARIOT_LIST_SHOTS"]
    }

    func testWriteTheThreeDirections() throws {
        let dir = try XCTUnwrap(outDir, "ohne LECHARIOT_LIST_SHOTS wird nichts geschrieben")
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .light ? "hell" : "dunkel"
            try write(DirectionB(), to: "\(dir)/liste-B-blatt-\(suffix).png", scheme: scheme)
            try write(DirectionA(), to: "\(dir)/liste-A-linien-\(suffix).png", scheme: scheme)
            try write(DirectionC(), to: "\(dir)/liste-C-preisspalte-\(suffix).png", scheme: scheme)
        }
    }

    /// iPhone-Breite in Punkten, Höhe großzügig: Ein zu knapper Ausschnitt
    /// schneidet genau die Zeile ab, um die es geht.
    private let size = CGSize(width: 393, height: 800)

    private func write(_ view: some View, to path: String, scheme: ColorScheme) throws {
        let host = UIHostingController(
            rootView: view
                .environment(\.colorScheme, scheme)
                .frame(width: size.width, height: size.height)
        )
        host.overrideUserInterfaceStyle = scheme == .light ? .light : .dark
        // **Das Fenster muss an eine Szene.** Ein frei gebautes `UIWindow`
        // gehört zu keinem Bildschirm, und `drawHierarchy` zeichnet dann eine
        // weiße Fläche — sechs bitgleiche PNGs, erst am `md5` gemerkt.
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        // Eine Umlaufrunde: Ohne sie steht die Liste im ersten Bild noch leer,
        // weil ihre Zellen erst beim Layout entstehen.
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        let png = try XCTUnwrap(image.pngData())
        try png.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - Der Inhalt, für alle drei derselbe

/// Dieselben vier Zeilen in jeder Richtung — sonst vergleicht man Inhalte statt
/// Layouts. Sie decken die Fälle ab, an denen sich die Richtungen unterscheiden:
/// ein normales Angebot, eine geheftete Wahl mit Rabatt, ein Artikel ohne
/// Treffer, ein abgehakter.
private enum ShotData {
    /// **Über den Produktnamen, nicht über den Index.** `MockFixtures.offers[2]`
    /// ist eine Milch; als Angebot zu „Käse" hätte das Bild eine Aussage über
    /// den Zuordner gemacht, die gar nicht gemeint ist.
    ///
    /// `standard` und nicht `offers`: Letzteres hat vier Zeilen, drei davon
    /// Milch. Für zwei Ketten untereinander — das, was die Preisspalte zeigen
    /// soll — braucht es eine Zeile aus einem der anderen Töpfe. Welche Woche
    /// das Angebot trägt, ist für ein Layout-Bild ohne Belang.
    static func angebot(_ product: String) -> Offer {
        MockFixtures.standard.first { $0.product == product }!
    }

    static let milch = ShoppingItem(text: "Milch", detail: ["2 l", "Bio"])
    static let erdbeeren = ShoppingItem(text: "Erdbeeren", pins: [angebot("Deutsche Erdbeeren").asPin])
    static let zahnpasta = ShoppingItem(text: "Zahnpasta")
    static let orangen = ShoppingItem(text: "Orangen", isChecked: true)

    static let milchAngebot = ItemSuggestion(
        match: OfferMatch(offer: angebot("Bio Vollmilch"), kind: .direct)
    )
    static let erdbeerAngebot = ItemSuggestion(
        match: OfferMatch(offer: angebot("Deutsche Erdbeeren"), kind: .direct),
        isPinned: true
    )
}

// MARK: - A · Linien statt Kästen (gebaut)

/// **Was heute läuft.** Keine Flächen, Haarlinien zwischen den Zeilen, das
/// Kategoriezeichen im Abschnittskopf. Gerendert mit der echten
/// `ShoppingListRowView`.
private struct DirectionA: View {
    var body: some View {
        List {
            Section {
                ShoppingListRowView(item: ShotData.milch, suggestion: ShotData.milchAngebot, onToggle: {}, onShowMatches: {}, onEditDetail: {})
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { kopf("Molkerei & Eier") }
            Section {
                ShoppingListRowView(item: ShotData.erdbeeren, suggestion: ShotData.erdbeerAngebot, onToggle: {}, onShowMatches: {}, onEditDetail: {})
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { kopf("Obst & Gemüse") }
            Section {
                ShoppingListRowView(item: ShotData.zahnpasta, onToggle: {}, onShowMatches: {}, onEditDetail: {})
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { kopf("Haushalt") }
            Section {
                ShoppingListRowView(item: ShotData.orangen, onToggle: {}, onEditDetail: {})
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { Text("Erledigt") }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    /// Der Abschnittskopf mit dem gezeichneten Kategoriezeichen — die Stelle,
    /// an der `CategoryGlyphView` seit dem 06.08. endlich zu sehen ist.
    private func kopf(_ kategorie: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            CategoryGlyphView(category: kategorie, size: 15)
                .foregroundStyle(Theme.accent)
            Text(kategorie)
        }
    }
}

// MARK: - B · Ein Blatt, viele Zeilen

/// **Der halbe Schritt.** Die Abschnittsfläche bleibt — die Liste liest sich
/// als Blatt Papier —, aber die zwei Rechtecke *innerhalb* der Zeile fallen
/// weg: die Angebotskachel und der Rahmen ums Bildchen.
private struct DirectionB: View {
    var body: some View {
        List {
            Section("MOLKEREI & EIER") {
                row(ShotData.milch, ShotData.milchAngebot)
            }
            .listRowBackground(Theme.surface)
            Section("OBST & GEMÜSE") {
                row(ShotData.erdbeeren, ShotData.erdbeerAngebot)
            }
            .listRowBackground(Theme.surface)
            Section("HAUSHALT") {
                row(ShotData.zahnpasta, ItemSuggestion(match: nil))
            }
            .listRowBackground(Theme.surface)
            Section("ERLEDIGT") {
                row(ShotData.orangen, ItemSuggestion(match: nil))
            }
            .listRowBackground(Theme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func row(_ item: ShoppingItem, _ suggestion: ItemSuggestion) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isChecked ? Theme.accent : Color.secondary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .font(.body.weight(.medium))
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    if let line = item.detailLine {
                        Text(line).font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
                if !item.isChecked {
                    if let offer = suggestion.positions.first?.offer {
                        angebot(offer, isPinned: suggestion.positions.first?.isPinned ?? false)
                    } else {
                        Text("Diese Woche nirgends im Angebot")
                            .font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// Ohne Kachelrahmen, ohne Bildrahmen — das ist der ganze Unterschied zum
    /// Stand vor dem 06.08.
    private func angebot(_ offer: Offer, isPinned: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            OfferThumbnail(
                imageUrl: offer.imageUrl, emoji: offer.emoji,
                category: offer.category, title: offer.product, size: 32,
                framed: false
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.product).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(2)
                HStack(spacing: Theme.Spacing.xs) {
                    if isPinned { PinnedChip() }
                    Text(offer.market).font(.caption2).foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            if let discount = offer.discountPercent { DiscountBadge(percent: discount) }
            if let price = offer.price { PriceText(amount: price) }
        }
    }
}

// MARK: - C · Preisspalte

/// **Die typografische Wette.** Das Angebot hängt nicht mehr als eigenes Ding
/// in der Zeile, sondern die Zeile hat **zwei Spalten**: links, was du willst
/// und was es dafür gibt, rechts der Preis — auf fester Breite, mit
/// Ziffern gleicher Laufweite, sodass alle Preise **eine Kante** bilden.
///
/// Der Markt steht in Versalien mit Sperrung: dieselbe Stimme wie „AM BESTEN
/// ZU" auf der Plan-Karte und wie `ChainMark` — die Emailschild-Stimme der App.
/// Kein Bildchen: Es war das dritte Rechteck, und in einer Spaltenordnung ist
/// es der einzige Klotz, der die Kante bricht.
///
/// **Was man dafür aufgibt:** das Produktfoto und den Rabatt-Chip als Farbe.
/// Der Rabatt steht hier als durchgestrichener Vorpreis unter dem Preis — das
/// ist die Kassenbon-Lesart, leiser als ein rotes Abzeichen.
private struct DirectionC: View {
    var body: some View {
        List {
            Section {
                row(ShotData.milch, ShotData.milchAngebot)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { kopf("Molkerei & Eier") }
            Section {
                row(ShotData.erdbeeren, ShotData.erdbeerAngebot)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { kopf("Obst & Gemüse") }
            Section {
                row(ShotData.zahnpasta, ItemSuggestion(match: nil))
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { kopf("Haushalt") }
            Section {
                row(ShotData.orangen, ItemSuggestion(match: nil))
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
            } header: { kopf("Erledigt") }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func kopf(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(Theme.accent)
    }

    private func row(_ item: ShoppingItem, _ suggestion: ItemSuggestion) -> some View {
        let position = suggestion.positions.first
        return HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(item.isChecked ? Theme.accent : Color.secondary)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .font(.body.weight(.medium))
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                if let line = item.detailLine {
                    Text(line).font(.caption2).foregroundStyle(Theme.secondaryText)
                }
                if !item.isChecked {
                    if let offer = position?.offer {
                        HStack(spacing: 6) {
                            if position?.isPinned == true {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            Text(offer.market.uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(Theme.accent)
                            Text(offer.product)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(1)
                        }
                    } else {
                        Text("nichts im Angebot")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            // **Die Spalte.** Feste Breite und Ziffern gleicher Laufweite sind
            // das, was aus vier Preisen eine Kante macht; ohne beides
            // franst sie bei „0,99" gegen „12,49" aus.
            VStack(alignment: .trailing, spacing: 1) {
                if let price = position?.offer.price {
                    Text(price, format: .currency(code: "EUR"))
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                    if let regular = position?.offer.regularPrice {
                        Text(regular, format: .currency(code: "EUR"))
                            .font(.caption2.monospacedDigit())
                            .strikethrough()
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else {
                    Text("—")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                }
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}
