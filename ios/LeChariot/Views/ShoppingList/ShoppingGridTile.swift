import SwiftUI

/// **Ein Artikel als Kachel — die Liste, wie Bring! sie zeigt** (2026-08-07).
///
/// Bis heute war ein Artikel eine Zeile: Kreis, Name, darunter das Angebot als
/// eigene Zeile. Vier Artikel füllten den Bildschirm. Ein Raster aus Kacheln
/// zeigt einen ganzen Einkauf auf einmal, und **das ist der Punkt**: Im Laden
/// will man sehen, was noch fehlt, nicht lesen, was man aufgeschrieben hat.
///
/// **Was von Bring! kommt und was nicht.**
///
/// Von dort: das Raster selbst, das Zeichen über dem Wort, und der Tipp als
/// Abhaken — beim Einkaufen ist das die einzige Handlung, die man im Gehen
/// macht, und sie darf keinen Umweg haben.
///
/// Auch von dort: **die Fläche unter der Kachel** (Scott am 08.08., „i also
/// want a little border around the products in list like in bring").
///
/// **Das dreht eine Begründung um, die hier stand.** Bis gestern Abend stand an
/// dieser Stelle „keine Kärtchen", mit Berufung auf Scotts Runde vom 06.08.
/// („i dont like that everything is in containers"). Der Satz war richtig — für
/// **Zeilen**. Dort steckten drei Rechtecke ineinander: Zeilenfläche, darin die
/// Angebotskachel, darin das Bildchen, zwei davon mit derselben Füllung. Im
/// **Raster** gibt es diese Schachtelung nicht; hier ist die Fläche das
/// einzige, was sagt, wo eine Kachel aufhört und die nächste anfängt. Am
/// gerenderten Blatt gegen die Fassung „nur Strich" gehalten und so entschieden
/// — Umriss allein verschwindet auf der Creme.
///
/// **Und der Preis, den Bring! nicht hat.** Er sitzt als kleine Fahne an der
/// Ecke des Zeichens, nicht als eigene Zeile: Wer nur einkaufen will, sieht
/// das Raster; wer den Preis sucht, findet ihn, ohne dass er die Fläche
/// beherrscht. Die Fahne ist **Anzeige, kein Knopf** — in 81 pt Kachelbreite
/// gibt es keine zweite 44-pt-Trefferfläche neben dem Abhaken. Der Weg zu den
/// Angeboten liegt im Kontextmenü und, prominenter, in der Plan-Karte über dem
/// Raster.
struct ShoppingGridTile: View {
    let item: ShoppingItem
    var suggestion: ItemSuggestion = ItemSuggestion(match: nil)
    /// Trägt die Anker für den Rundgang. Nur die erste offene Kachel setzt das.
    var carriesTutorialAnchors = false
    /// Einmaliges Aufleuchten beim **allerersten** Treffer überhaupt.
    var highlightsFirstMatch = false
    let onToggle: () -> Void
    var onShowMatches: (() -> Void)? = nil
    var onEditDetail: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    /// Der Begriff, dessen Zeichnung die Kachel trägt. Aufgelöst über dasselbe
    /// Wörterbuch, das der Zuordner benutzt — siehe `ItemGlyphTerm`.
    private var glyphTerm: String? { ItemGlyphTerm.term(for: item.text) }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 6) {
                zeichen
                beschriftung
            }
            .frame(maxWidth: .infinity)
            // Der Innenabstand gehört zur Fläche: Ohne ihn klebt das Zeichen
            // an der Kante.
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, 4)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                    .strokeBorder(Theme.stroke)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TactileButtonStyle())
        .opacity(item.isChecked ? 0.45 : 1)
        // **Label ist der Artikel, Value das Angebot.** Beides ins Label zu
        // packen war der erste Anlauf und hat sofort etwas kaputtgemacht: Aus
        // „Vollmilch" wurde „Vollmilch, Günstigstes Angebot: …", und damit war
        // der Artikel unter seinem eigenen Namen nicht mehr zu finden — weder
        // für die Journeys noch für jemanden, der VoiceOver nach ihm suchen
        // lässt. Der Name gehört ins Label, was gerade dazu bekannt ist, in
        // den Wert.
        .accessibilityLabel(item.detailLine.map { "\(item.text), \($0)" } ?? item.text)
        .accessibilityValue(zustandstext)
        .accessibilityHint(item.isChecked ? "Als offen markieren" : "Als erledigt markieren")
        .accessibilityIdentifier("list.tile")
        .tutorialAnchor(.rowCheck, when: carriesTutorialAnchors)
        .contextMenu { menü }
    }

    // MARK: Zeichen und Fahne

    /// Ob das Wörterbuch dieses Wort überhaupt kennt. `ItemGlyphView` liefert
    /// ohne Begriff **und** ohne Kategorie eine leere Fläche — und eine leere
    /// Fläche sagt nichts.
    private var unbekannt: Bool {
        glyphTerm == nil && suggestion.match?.offer.category == nil
    }

    @ViewBuilder
    private var zeichen: some View {
        ZStack(alignment: .topTrailing) {
            if unbekannt {
                // **Die Kachel-Fassung von „das kenne ich nicht".**
                //
                // In der Zeile stand dafür ein Satz („… steht nicht im
                // Wörterbuch"), und der war teuer erkämpft: Bis zum 31.07. sah
                // „das Wort kenne ich nicht" genauso aus wie „diese Woche gibt
                // es dazu nichts", und daran hing „vegan Schnitzel" zehn Tage
                // lang. Diese Unterscheidung darf mit den Zeilen nicht
                // verlorengehen — ein leeres Feld wäre genau der stille
                // Zustand von damals.
                //
                // Der ganze Satz steht weiter im Trefferblatt, das das
                // Kachelmenü öffnet („Warum kein Angebot?").
                Image(systemName: "questionmark")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 52, height: 46)
                    .accessibilityHidden(true)
            }
            ItemGlyphView(
                term: glyphTerm,
                // Rückfall aufs Kategoriezeichen — die Kategorie weiß nur der
                // Treffer, deshalb kommt sie von dort und nicht aus dem Artikel.
                category: suggestion.match?.offer.category,
                size: 40
            )
            .foregroundStyle(item.isChecked ? Theme.secondaryText : Theme.accent)
            // Fester Kasten, damit alle Zeichen auf derselben Grundlinie
            // sitzen — ein hohes und ein flaches Zeichen ließen die Reihe
            // sonst wackeln.
            .frame(width: 52, height: 46)
            // **Das Aufleuchten des ersten Treffers**, hier als Fläche hinter
            // dem Zeichen. Es gibt sie nur im Moment selbst; im Ruhezustand
            // liegt hinter dem Zeichen nichts.
            .background(
                highlightsFirstMatch ? Theme.accent.opacity(0.14) : .clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
            )

            if !item.isChecked, let preis = suggestion.match?.offer.price {
                fahne(preis, angeheftet: suggestion.isPinned)
            } else if !item.isChecked, !suggestion.dormantPins.isEmpty {
                // **Die schlafende Wahl bekommt ihr eigenes Zeichen.** In der
                // Zeile stand dafür ein ganzer Satz („… ist diese Woche nicht
                // im Angebot"); eine Kachel trägt keinen Satz. Was bleibt, ist
                // die Reißzwecke in Grau: etwas ist geheftet, es gilt gerade
                // nur nicht. Der Satz selbst steht im Trefferblatt, und der
                // Vorlesetext sagt ihn hier weiterhin ganz.
                Image(systemName: "pin.slash.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .offset(x: 4, y: -2)
                    .accessibilityHidden(true)
            }
        }
        .tutorialAnchor(.rowMatch, when: carriesTutorialAnchors)
    }

    /// Der Preis als Fähnchen an der Ecke. Es sitzt am Zeichen und nicht unter
    /// dem Wort, damit die Wortzeilen aller Kacheln eine gemeinsame Höhe
    /// behalten — sonst tanzt jede zweite Kachel.
    private func fahne(_ preis: Double, angeheftet: Bool) -> some View {
        HStack(spacing: 2) {
            if angeheftet {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7, weight: .semibold))
            }
            Text(preis, format: .currency(code: "EUR"))
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(Theme.onAccent)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Theme.accent, in: Capsule())
        // **Innerhalb der Fläche, seit die Kachel eine hat** (08.08.). Ohne
        // Fläche durfte die Fahne weit nach außen hängen, damit sie dem
        // Erdbeerkelch und dem Deckel der Milchtüte aus dem Gesicht geht. Mit
        // Fläche schnitt genau dieser Überstand über die Kante — und was über
        // eine Kante ragt, liest sich als Fehler, nicht als Sticker. Jetzt
        // knapp nach außen versetzt, aber innerhalb des Randes.
        .offset(x: 4, y: 0)
        .accessibilityHidden(true)
    }

    // MARK: Beschriftung

    /// **Feste Höhe.** Ohne sie sitzt „Bananen" (ohne Unterzeile) höher als
    /// „Erdbeeren" (mit), und die Reihe tanzt — am ersten gerenderten Bild
    /// gesehen, nicht überlegt.
    private var beschriftung: some View {
        VStack(spacing: 1) {
            Text(item.text)
                .font(.caption.weight(.medium))
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? Theme.secondaryText : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Was die Angabe sagt, bleibt nach dem Abhaken wahr — „2 l, Bio"
            // wird nicht falsch, weil der Artikel im Wagen liegt. Deshalb
            // trägt nur der Name den Strich, die Zeile darunter nicht.
            if let unten = item.detailLine {
                Text(unten)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(height: 28, alignment: .top)
        .multilineTextAlignment(.center)
    }

    // MARK: Das Menü

    /// **Alles außer dem Abhaken liegt hier.** Eine Kachel von 81 pt trägt
    /// genau eine Trefferfläche; jede weitere wäre kleiner als die 44 pt, die
    /// der Barrierefreiheits-Audit verlangt, und läge im Gehen ohnehin daneben.
    ///
    /// Das Trefferblatt bleibt darüber hinaus über die Plan-Karte erreichbar —
    /// die Angebote sind der Kern der App und dürfen nicht nur hinter einem
    /// langen Druck liegen.
    @ViewBuilder
    private var menü: some View {
        if let onShowMatches {
            Button(action: onShowMatches) {
                Label(angebotstext, systemImage: "tag")
            }
            .accessibilityIdentifier(
                suggestion.positions.isEmpty ? "list.matches.empty" : "list.matches"
            )
        }
        if let onEditDetail {
            Button(action: onEditDetail) {
                Label("Angaben", systemImage: "square.and.pencil")
            }
            .accessibilityIdentifier("list.item.detail")
        }
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Löschen", systemImage: "trash")
            }
            .accessibilityIdentifier("list.item.delete")
        }
    }

    /// Der Menüpunkt sagt, was dahinter steht — „Angebote" über einer leeren
    /// Liste wäre ein Versprechen, das der nächste Bildschirm bricht.
    private var angebotstext: String {
        suggestion.positions.isEmpty ? "Warum kein Angebot?" : "Angebote"
    }

    /// Was zu diesem Artikel gerade bekannt ist: erledigt, das Angebot, und
    /// der Satz zur schlafenden Wahl — die drei Auskünfte, die in der Zeile
    /// auf der Fläche standen und in der Kachel keinen Platz mehr haben.
    private var zustandstext: String {
        var teile: [String] = []
        if item.isChecked { teile.append("erledigt") }
        // Dieselbe Auskunft wie das Fragezeichen auf der Kachel — sonst wäre
        // sie für VoiceOver nicht da.
        if unbekannt { teile.append("steht nicht im Wörterbuch") }
        if !item.isChecked {
            // Der Satz zur schlafenden Wahl steht zuerst — er erklärt, warum
            // darunter etwas anderes steht als das Gewählte.
            for pin in suggestion.dormantPins { teile.append(pin.absenceLine) }
            // **Alle Positionen, nicht nur die erste.** Die Zeile zeigte zwei
            // gehefteten Wahlen zwei Kacheln nebeneinander; im Raster hat ein
            // Artikel genau eine Kachel, und die Fahne trägt einen Preis. Was
            // dabei verlorenginge, steht hier: Wer zwei Produkte an einem
            // Eintrag hat, hört beide.
            for position in suggestion.positions {
                let offer = position.offer
                var satz = (position.isPinned ? "Deine Wahl: " : "Günstigstes Angebot: ") + offer.product
                if let price = offer.price {
                    satz += ", " + price.formatted(.currency(code: "EUR"))
                }
                teile.append(satz + " bei \(offer.market)")
            }
        }
        return teile.joined(separator: ", ")
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                  alignment: .leading, spacing: Theme.Spacing.lg) {
            ShoppingGridTile(
                item: ShoppingItem(text: "Milch", detail: ["2 l", "Bio"]),
                suggestion: ItemSuggestion(
                    match: OfferMatch(offer: MockFixtures.offers[0], kind: .direct)
                ),
                onToggle: {}
            )
            ShoppingGridTile(item: ShoppingItem(text: "Zahnpasta"), onToggle: {})
            ShoppingGridTile(
                item: ShoppingItem(text: "Erdbeeren"),
                suggestion: ItemSuggestion(
                    match: OfferMatch(offer: MockFixtures.offers[2], kind: .direct),
                    isPinned: true
                ),
                onToggle: {}
            )
            ShoppingGridTile(
                item: ShoppingItem(text: "Orangen", isChecked: true),
                onToggle: {}
            )
        }
        .padding()
    }
    .background(Theme.background)
}
