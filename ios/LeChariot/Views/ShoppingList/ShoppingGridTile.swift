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
/// beherrscht. Die Fahne ist **Anzeige, kein Knopf** — eine zweite
/// Trefferfläche auf einer Kachel, deren einzige Handlung das Abhaken im Gehen
/// ist, wäre der eine Fehlgriff, den man sich dabei nicht leisten will. Der Weg
/// zu den Angeboten ist seit dem 08.08. **das Halten selbst** (vorher ein
/// Umweg über das Kontextmenü) und, prominenter, die Plan-Karte über dem
/// Raster.
struct ShoppingGridTile: View {
    /// **Die Spalten des Rasters — drei je Reihe auf dem iPhone** (08.08.).
    ///
    /// Bis heute stand hier `.adaptive(minimum: 76)`, und daraus wurden auf
    /// 393 pt vier Spalten zu je 81 pt. Scott am 08.08.: „Bring! nimmt drei,
    /// die Kacheln sind entsprechend größer."
    ///
    /// **Warum weiter `.adaptive` und keine feste Drei.** Eine feste Zahl ist
    /// auf dem iPad falsch: Dort wären drei Kacheln über 300 pt breit — ein
    /// Zeichen von 40 pt in einem Feld von 300, mit dem Wort verloren darunter.
    /// `.adaptive` hält stattdessen die **Kachelgröße** und lässt die Spaltenzahl
    /// mit dem Bildschirm wachsen; das iPhone bekommt dann drei, weil auf keiner
    /// iPhone-Breite eine vierte hineinpasst.
    ///
    /// **Die 100 ist gerechnet und nachgemessen** (`ShoppingGridColumnTests`):
    /// Bei Rand `lg` (16) und Spalte `md` (12) muss die Zahl über 93 liegen,
    /// damit auf der breitesten iPhone-Fläche (440 pt) keine vierte Spalte mehr
    /// passt, und höchstens 106 betragen, damit auf der schmalsten (375 pt) noch
    /// drei passen. 100 liegt in der Mitte dieses Fensters. Wer sie anfasst,
    /// bekommt es vom Test gesagt.
    static let columns = [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.md)]

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
        // **Oben links, und beide anderen Ecken sind durchgefallen — an
        // gerenderten Bildern, nicht im Kopf.**
        //
        // *Oben rechts:* Dort hängt das Preisfähnchen. Es sitzt an der Ecke des
        // Zeichens und ragt 4 pt nach außen; auf der Vollmilch-Kachel
        // berührten sich „0,99 €" und der Knopf fast, und auf einer schmaleren
        // Kachel derselben Reihe wäre daraus eine Überlappung geworden.
        //
        // *Unten rechts:* Dort steht die Beschriftung. „Bananen" reicht bis
        // fast an den Rand, und der Knopf klebte am Wort, als gehörte er dazu.
        //
        // Oben links ist auf jeder Kachel frei — das Zeichen steht mittig, das
        // Fähnchen rechts davon, die Reißzwecke ebenfalls.
        ZStack(alignment: .topLeading) {
            kachel
            // **Die sichtbare Tür zu den Angaben** (Feldtest 09.08.). Sie liegt
            // über der Kachelfläche, nicht darin: Die Kachel ist ein Knopf, und
            // ein Knopf im Knopf bekommt seinen Tipp nur, wenn er obenauf liegt.
            if onEditDetail != nil {
                angabenKnopf
            }
        }
        // **Das Zurücktreten gilt der ganzen Kachel, nicht nur ihrer Fläche.**
        // Bis zum 09.08. sass dieser Modifikator am Knopf der Kachel selbst;
        // seit der Angaben-Knopf als Geschwister daneben liegt, wäre er sonst
        // der einzige Teil einer abgehakten Kachel in voller Deckkraft — ein
        // helles Bedienelement auf etwas, das gerade in den Hintergrund tritt.
        // Eine Regel, eine Stelle.
        .opacity(item.isChecked ? 0.45 : 1)
    }

    /// **Warum die Kachel überhaupt eine sichtbare Tür braucht.**
    ///
    /// Seit #91 führt das Halten zum Trefferblatt, und damit ist das
    /// Kontextmenü der Kachel für den Finger tot (gemessen, siehe `menü`).
    /// Übrig blieb ein Weg zu den Angaben, der durch das Trefferblatt und dort
    /// durch das ⋯-Menü führt — drei Griffe hinter einer Geste, die nichts
    /// ankündigt. Scotts Feldtest am 09.08. ist genau darüber gestolpert:
    /// „Kohl steht auf der Liste und ich komme an seine Angaben nicht mehr
    /// heran." Das Bild dazu ist eindeutig — ein Bildschirm mit der
    /// Überschrift „Treffer für ‚Kohl'", der „Keine Treffer" meldet, und die
    /// einzige Tür zu den Angaben ist das ⋯ in seiner Ecke.
    ///
    /// Der Knopf hier ist die Antwort darauf: ein Griff, sichtbar, und er
    /// führt in **dieselbe** Angaben-Schicht wie das Anlegen (`ItemDetailPanel`)
    /// — nicht in eine zweite Fassung mit eigenem Wortschatz.
    private var angabenKnopf: some View {
        Button {
            onEditDetail?()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                // Die Fläche zum Treffen ist größer als das Zeichen: 44 pt sind
                // Apples Maß, und die Ecke einer Kachel ist der Ort, an dem ein
                // Daumen am ehesten danebengreift.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // **Nicht „Angaben zu Butter" — der Name ist vergeben**, und zwar an
        // die Kachelzeile der Angaben-Schicht (`ItemDetailPanel.recentChip`).
        // Steht die Schicht über der Liste, tragen sonst zwei Knöpfe auf einem
        // Bildschirm denselben Namen; gemessen am 09.08. hieß das „Multiple
        // matching elements found" in zwei Journeys, die es vorher gab. Genau
        // die Falle, vor der `recentChip` an Ort und Stelle warnt.
        //
        // „ändern" ist außerdem das ehrlichere Wort: Auf der Kachel steht ein
        // Artikel, den es schon gibt, und der Knopf ändert seine Angaben. Die
        // Kachelzeile wechselt nur den Blick.
        .accessibilityLabel("Angaben zu \(item.text) ändern")
        .accessibilityIdentifier("list.tile.detail")
    }

    private var kachel: some View {
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
        .simultaneousGesture(haltenÖffnetDieTreffer)
    }

    /// **Halten führt zu den Treffern** (08.08., Scott: „ein Griff weniger").
    ///
    /// `simultaneousGesture` und nicht `onLongPressGesture`: Letzteres schiebt
    /// sich vor den Tipp des Knopfes, und der Tipp ist die eine Handlung, die
    /// diese Kachel im Gehen können muss. Gemessen ist beides — Tipp bis
    /// „erledigt" vorher 0,74 s, nachher 0,74 s (`TileGestureJourneyTests`).
    ///
    /// **0,35 s ist Apples eigene Schwelle für langes Drücken** — dieselbe, die
    /// `onLongPressGesture` ohne Angabe nimmt. Deutlich kürzer würde ein Tipp
    /// mit etwas Nachdruck zum Halten erklären; deutlich länger geriete in die
    /// Nähe des Kontextmenüs, das auf derselben Kachel liegt.
    ///
    /// **Was daran gemessen ist und was nicht:** Gemessen ist das *Ergebnis* —
    /// bei 0,4 s, 0,7 s und 1,2 s öffnet das Trefferblatt und das Kontextmenü
    /// bleibt weg (`testEveryHoldLengthOpensTheMatchesAndNotTheContextMenu`).
    /// Die Schwelle des Kontextmenüs selbst ist **nicht** nachgemessen; sie ist
    /// hier auch nicht nötig, weil der Test das Ergebnis festhält statt die
    /// Rechnung dahinter.
    private var haltenÖffnetDieTreffer: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .onEnded { _ in onShowMatches?() }
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

    /// **Der Weg für Zeigegerät und Hilfstechnik.** Für den Finger ist er seit
    /// dem 08.08. tot, und das ist gemessen: Sobald der lange Druck das
    /// Trefferblatt öffnet, erscheint dieses Menü nicht mehr — bei 0,4 s
    /// nicht, bei 0,7 s nicht, bei 1,2 s nicht (`TileGestureJourneyTests`).
    /// Es bleibt trotzdem stehen, weil es nichts kostet und Zeigegerät und
    /// Hilfstechnik es über andere Wege als den Fingerdruck ansteuern —
    /// **nachgemessen ist das nicht**, deshalb hängt nichts daran.
    ///
    /// **Was der Finger stattdessen erreicht:** Angebote über das Halten,
    /// Angaben und Löschen über das ⋯-Menü in genau dem Blatt, das dabei
    /// aufgeht (`MatchDetailView.artikelmenü`). Nur dieser Weg ist geprüft.
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
