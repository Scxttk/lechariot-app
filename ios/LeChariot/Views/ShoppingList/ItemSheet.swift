import SwiftUI

/// **Ein Artikel, ein Bildschirm: Angaben *und* Treffer** (10.08., Punkt A der
/// Bedienrunde).
///
/// Scott, nach Bring!: „Das Präferenzen menu button I don't like, bring opens
/// it by long pressing the product, so I would share that screen aswell." Das
/// Halten auf einer Kachel führte seit #91 auf die **Treffer**; die Angaben
/// lagen daneben, erst im ⋯-Menü dieses Blattes, seit #97 zusätzlich hinter
/// einem Eck-Knopf auf der Kachel. Drei Türen für zwei Auskünfte über
/// denselben Artikel.
///
/// Jetzt ist es eine: Das Halten öffnet dieses Blatt, und es trägt beides.
///
/// **Die Gewichtung hat sich am Abend des 10.08. umgedreht** (Punkt 10).
///
/// Die erste Fassung stellte die Angaben nach oben und die Treffer darunter —
/// die Antwort auf den Feldtest vom 09.08. („Kohl steht auf der Liste und ich
/// komme an seine Angaben nicht mehr heran"). Am Gerät war das die eine
/// Bewegung zu viel: Wer ein Blatt öffnet, sieht drei Chipreihen und muss an
/// ihnen vorbeiwischen, um zu erfahren, was der Artikel diese Woche kostet.
/// Scott, wörtlich: „just the button where it says ‚Angaben konfigurieren' …
/// and then there is the offers of the week … the main screen."
///
/// Also: **Die Angebote sind der Bildschirm, die Angaben stehen hinter einem
/// Knopf** — und die Zusage vom 09.08. bleibt trotzdem eingelöst, denn der
/// Knopf steht ganz oben und trägt, was schon gewählt ist. Erreichbar heißt
/// nicht ausgebreitet.
///
/// Aufgeklappt wird an Ort und Stelle, nicht in einem zweiten Blatt: Zwei
/// gestapelte Karten für ein Aufklappen sind eine Karte zu viel — dieselbe
/// Regel, aus der der Preisverlauf geschoben und nicht gestapelt wird.
///
/// **Kein „Fertig", das etwas bestätigt.** Jeder Chip, jede Reißzwecke, jedes ✕
/// schreibt sofort durch — dieselbe Zusage wie in `ItemDetailPanel`. Der Knopf
/// oben rechts schließt nur das Blatt.
///
/// **Und das Löschen steht ganz unten**, so weit wie möglich von den Angaben
/// weg. Scott wollte den Eck-Knopf ausdrücklich ohne Löschen („the button in
/// the left corner is only the Präferenzen menu and not löschen"); auf der
/// Kachel bleibt es im Kontextmenü. Ein Weg für den Finger muss es trotzdem
/// geben — gemessen ist, dass das Kontextmenü nicht mehr erscheint, sobald das
/// Halten ein Blatt öffnet (`TileGestureJourneyTests`). Also hier, am Ende
/// eines langen Bildschirms, wo Apple es in den eigenen Apps auch hinlegt.
struct ItemSheet: View {
    let item: ShoppingItem
    let offers: [Offer]
    /// The chosen branches — only used to name the branch in the detail view,
    /// same rule as the offer list sections.
    var favoriteMarkets: [Market] = []
    /// Only the detail view needs it, and only after a tap.
    var priceHistoryRepository: PriceHistoryRepositoryProtocol = AppRepositories.priceHistory

    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(MatchFeedbackStore.self) private var feedback
    /// Optional, damit Previews ohne Liste auskommen — dasselbe Muster wie der
    /// Rundgang in `ShoppingListView`.
    @Environment(ShoppingListStore.self) private var list: ShoppingListStore?
    @Environment(\.dismiss) private var dismiss

    /// The match whose rejection is currently being asked about, if any.
    @State private var askingAbout: OfferMatch?

    /// Der Freitext, während er getippt wird. **Das einzige Stück Zustand, das
    /// dieses Blatt hält** — Chips und Heftungen gehen ohne Umweg in den
    /// Speicher, aber ein Textfeld braucht eine Bindung, und die kann nicht bei
    /// jedem Zeichen aus der Liste zurückgelesen werden.
    @State private var note: String

    /// Ob die Chipreihen ausgeklappt sind. Zu heißt: Das Blatt gehört den
    /// Angeboten.
    @State private var angabenOffen = false

    /// **Aufgeklappt starten — für den einen Weg, der ausdrücklich die Angaben
    /// meint.** „Notiz …" aus der Schicht beim Anlegen heißt wörtlich „Notiz
    /// und alle Angaben zu …"; wer dort tippt, hat die Angebote nicht gesucht.
    /// Das Halten auf der Kachel meint den Artikel und bekommt deshalb den
    /// Normalfall.
    init(item: ShoppingItem,
         offers: [Offer],
         favoriteMarkets: [Market] = [],
         startsWithAngaben: Bool = false,
         priceHistoryRepository: PriceHistoryRepositoryProtocol = AppRepositories.priceHistory) {
        self.item = item
        self.offers = offers
        self.favoriteMarkets = favoriteMarkets
        self.priceHistoryRepository = priceHistoryRepository
        _note = State(initialValue: item.note ?? "")
        _angabenOffen = State(initialValue: startsWithAngaben)
    }

    private var allMatches: [OfferMatch] {
        ShoppingListMatcher.matches(for: item.query, in: offers)
    }

    /// Was aus dem getippten Wort in die Suche gegangen ist.
    private var understanding: QueryUnderstanding {
        QueryUnderstanding.of(query: item.query, in: offers)
    }

    /// Ob die Zeilen sich in der Herkunft überhaupt unterscheiden.
    ///
    /// Kommen alle über denselben Weg, sagt eine Herkunftszeile je Zeile
    /// nichts, was der Kopf nicht schon gesagt hat — sie wäre dann
    /// dasselbe Wort so oft auf dem Bildschirm, wie es Treffer gibt.
    private var routesDiffer: Bool {
        Set(allMatches.map(\.kind)).count > 1
    }

    /// Die aktuelle Heftung — **aus dem Speicher**, nicht aus `item`.
    ///
    /// `item` ist die Kopie, mit der das Blatt geöffnet wurde; sie wüsste von
    /// einer Heftung, die auf diesem Blatt gerade gesetzt wurde, nichts. Ohne
    /// den Speicher (Previews) bleibt sie der Stand von damals.
    private var pins: [PinnedOffer] {
        guard let list else { return item.pinnedOffers }
        return list.items.first { $0.id == item.id }?.pinnedOffers ?? []
    }

    /// Die gehefteten Angebote, die es diese Woche gibt.
    private var pinnedOffers: [Offer] {
        pins.compactMap { ShoppingListMatcher.pinnedOffer($0, in: offers) }
    }

    /// Die Heftungen, deren Produkt diese Woche nirgends steht.
    private var dormantPins: [PinnedOffer] {
        pins.filter { ShoppingListMatcher.pinnedOffer($0, in: offers) == nil }
    }

    /// Ob die geheftete Wahl in der Trefferliste unten überhaupt vorkommt.
    ///
    /// Sie kann fehlen, ohne dass es die Woche war: Die Heftung geht am Matcher
    /// vorbei, also steht ein geheftetes Produkt auch dann auf der Liste, wenn
    /// sein Prospekttitel ein Wort verloren hat oder ein Tag weggefallen ist.
    private func isListed(_ pin: PinnedOffer) -> Bool {
        allMatches.contains { $0.offer.matches(pin) }
    }

    private var active: [OfferMatch] {
        allMatches.filter { !rejections.isRejected(itemText: item.query, offer: $0.offer) }
    }

    private var rejected: [OfferMatch] {
        allMatches.filter { rejections.isRejected(itemText: item.query, offer: $0.offer) }
    }

    var body: some View {
        NavigationStack {
            List {
                angabenKnopfSection
                if angabenOffen {
                    // **Die Notiz zuerst, dann die Chipreihen.** Am Bild
                    // nachgemessen: Aufgeklappt schob der Wortschatz von
                    // „Butter" das Freitextfeld unter die Kante — zwei Journeys
                    // fanden es nicht mehr, und eine `List` baut nur, was im
                    // Bild ist. Der Freitext ist außerdem das Einzige hier, das
                    // man *tippt*; die Chips sind zum Durchsehen da. Und der
                    // Weg, der aufgeklappt ankommt, heißt „Notiz und alle
                    // Angaben zu …" — er landet jetzt auf der Notiz.
                    notizSection
                    angabenSection
                    if !fremdwörter.isEmpty { fremdwortSection }
                }

                trefferKopf
                understandingSection

                // Je Heftung, die unten nicht vorkommt, eine eigene Zeile:
                // Ohne sie wäre eine Wahl, die man nicht mehr will, nie wieder
                // loszuwerden.
                ForEach(pins.filter { !isListed($0) }, id: \.key) { pinnedSection($0) }

                if active.isEmpty && rejected.isEmpty {
                    ContentUnavailableView(
                        "Keine Treffer",
                        systemImage: "magnifyingglass",
                        description: Text("Kein Angebot passt diese Woche zu „\(item.text)\u{201C}.")
                    )
                    .listRowBackground(Color.clear)
                }

                if !active.isEmpty {
                    Section {
                        ForEach(active) { match in
                            matchRow(match, isRejected: false)
                        }
                    } footer: {
                        // Der erste Satz benennt, was hinter einer Zeile
                        // liegt. Der Preisverlauf war gebaut und erreichbar,
                        // aber nichts sagte, dass es ihn gibt — Scotts Frage
                        // „where can i see the preisverlauf?" ([UI-5]).
                        Text("Tippe ein Angebot an: Packungsgröße, Gültigkeit und der Preisverlauf der letzten Wochen. Tippe die Reißzwecke, um es dauerhaft auf die Liste zu heften — auch wenn es nicht das billigste ist. Passt eines gar nicht zu deinem Artikel? Leg es weg, dann schlägt \(AppBrand.name) es nicht mehr vor.")
                    }
                    .listRowBackground(Theme.surface)
                }

                if !rejected.isEmpty {
                    Section("Weggelegt") {
                        ForEach(rejected) { match in
                            matchRow(match, isRejected: true)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                löschenSection
            }
            .themedScreen()
            .navigationTitle(item.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("itemSheet.done")
                }
            }
            .sheet(item: $askingAbout) { match in
                RejectionFeedbackSheet(itemText: item.query, match: match)
                    .environment(feedback)
            }
            // Geschoben, nicht als zweites Sheet: Das hier IST schon ein
            // Sheet, und zwei gestapelte Karten für ein Aufklappen sind eine
            // Karte zu viel. Der Zurück-Pfeil führt dorthin zurück, wo man
            // hergekommen ist — ein „Fertig" auf einem Sheet über einem Sheet
            // wäre mehrdeutig.
            .navigationDestination(for: Offer.self) { offer in
                OfferDetailView(
                    offer: offer,
                    favoriteMarkets: favoriteMarkets,
                    historyRepository: priceHistoryRepository,
                    presentation: .pushed
                )
            }
        }
        // **Der durchsichtige schwarze Behälter oben** (Punkt B-1, Scott:
        // „when preferences menu opens there is small visual bug at the top, a
        // transparent black container").
        //
        // Er ist keine Ansicht dieser App, sondern **die Abdunklung, die iOS
        // hinter ein Blatt legt**. Ein Blatt reicht nicht bis an die
        // Statusleiste; der Streifen darüber zeigt die Liste, und über der
        // liegt der Schleier. Am gerenderten Bild nachgemessen: Die Creme
        // #E3DEB8 steht dort als #B6B293 — Faktor 0,80, also Schwarz mit rund
        // 20 %. Auf einem hellen, warmen Hintergrund liest sich das nicht als
        // Tiefe, sondern als ein Kasten, der dort nichts zu suchen hat. Auf
        // Apples eigenem Grau fällt derselbe Schleier kaum auf — deshalb ist
        // es „Standardverhalten" und trotzdem hier ein Fehler.
        //
        // `presentationBackgroundInteraction` nimmt dem Blatt seine Modalität,
        // und damit fällt die Abdunklung weg. Der Preis ist, dass der Streifen
        // oben antippbar bleibt — dort liegt die sichere Fläche mit der Uhr,
        // also nichts, was auf einen Tipp reagiert.
        //
        // **`upThrough:` ist nicht Zierrat, sondern der Unterschied.** Das
        // bloße `.enabled` war der erste Versuch und hat den Streifen am
        // gerenderten Bild bei #B6B293 gelassen — Deckkraft unverändert. Erst
        // `.enabled(upThrough: .large)` misst sich als #E3DEB8, also volle
        // Creme. Die Abdunklung hängt am **größten** Halt, und den muss man
        // ausdrücklich nennen.
        .presentationDetents([.large])
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }

    // MARK: Die Angaben

    /// Die Angaben **live aus dem Speicher** — `item` ist die Kopie vom Moment
    /// des Öffnens und wüsste von einem Chip, der hier gerade gesetzt wurde,
    /// nichts. Dieselbe Begründung wie bei `pins`.
    private var gewählt: [String] {
        guard let list else { return item.detail ?? [] }
        return list.items.first { $0.id == item.id }?.detail ?? []
    }

    /// Die Reihen dieses Artikels — dieselbe Quelle wie die Schicht beim
    /// Anlegen (`ItemDetailPanel`). Zwei Wege zu denselben Angaben dürfen
    /// nicht zwei Wortschätze sein.
    private var reihen: [ItemDetailVocabulary.Group] {
        ItemDetailVocabulary.groups(for: item.query)
    }

    /// Gewählte Wörter aus einem älteren Wortschatz — sie behalten ihren Platz
    /// und bleiben abwählbar. Siehe `ItemDetailVocabulary.group(of:)`.
    private var fremdwörter: [String] {
        gewählt.filter { ItemDetailVocabulary.group(of: $0, in: reihen) == nil }
    }

    /// **Der Knopf, hinter dem die Angaben liegen.**
    ///
    /// Er steht als Erstes auf dem Blatt und ist zugeklappt die einzige Zeile,
    /// die den Angeboten Platz wegnimmt. Was schon gewählt ist, steht trotzdem
    /// darunter — sonst wäre „zugeklappt" dasselbe wie „nicht da", und genau
    /// das war der Befund vom 09.08.
    private var angabenKnopfSection: some View {
        Section {
            Button {
                withAnimation(Theme.Motion.element.animation) { angabenOffen.toggle() }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Label("Angaben konfigurieren", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: Theme.Spacing.sm)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(angabenOffen ? 180 : 0))
                        .foregroundStyle(Theme.secondaryText)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(TactileButtonStyle())
            .tint(Theme.accent)
            .accessibilityIdentifier("itemSheet.angaben")
            .accessibilityHint(angabenOffen ? "Klappt die Angaben wieder zu" : "Klappt die Angaben auf")

            if !angabenOffen, let stand = angabenStand {
                Text(stand)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("itemSheet.angabenStand")
            }
        }
        .listRowBackground(Theme.surface)
    }

    /// Was am Artikel steht, in einer Zeile — nil, solange nichts gewählt und
    /// nichts notiert ist.
    private var angabenStand: String? {
        var teile = gewählt
        let notiz = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notiz.isEmpty { teile.append(notiz) }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    /// **Die Chipreihen — aufgeklappt, mit dem Satz, der die Angaben von der
    /// Suche trennt.**
    ///
    /// Der Satz stand seit dem 01.08. im alten Angaben-Blatt und ist der
    /// Grund, aus dem hier niemand „Bio" wählt und dann ein anderes Angebot
    /// erwartet: Was hier steht, steht unter dem Artikel — und nirgends sonst.
    private var angabenSection: some View {
        Section {
            ForEach(reihen) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(group.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    // **Eine Reihe je Gruppe, die zur Seite scrollt — wie in
                    // der Schicht beim Anlegen.** Der erste Entwurf ließ die
                    // Chips umbrechen, und am gerenderten Bild war das
                    // Ergebnis eindeutig: „Angebote diese Woche" fing erst
                    // nach rund 1000 pt an, also zwei vollen Wischern. Auf
                    // einem Bildschirm, der beides tragen soll, darf der eine
                    // Teil den anderen nicht unter den Rand schieben.
                    scrollendeChips(group.chips)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        } header: {
            Text("Angaben")
        } footer: {
            Text("Steht unter dem Artikel — für dich im Laden. Die Suche nach Angeboten benutzt weiter nur „\(item.text)\u{201C}.")
        }
        .listRowBackground(Theme.surface)
    }

    private var notizSection: some View {
        Section("Notiz") {
            TextField("z. B. die im blauen Becher", text: $note, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                // **Durchgeschrieben beim Tippen, nicht auf Knopfdruck.** Das
                // Blatt hat kein „Sichern"; ein Freitext, der nur mit einem
                // Knopf überlebt, wäre der einzige Teil davon, der es hat.
                .onChange(of: note) { _, neu in
                    list?.setDetail(gewählt, note: neu, for: item)
                }
                .accessibilityIdentifier("itemDetail.note")
                .accessibilityLabel("Notiz zum Artikel")
                .accessibilityHint("Bleibt auf dem Gerät und geht nicht in die Suche")
        }
        .listRowBackground(Theme.surface)
    }

    private var fremdwortSection: some View {
        Section("Sonst notiert") {
            umbrechendeChips(fremdwörter)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .listRowBackground(Theme.surface)
    }

    private func scrollendeChips(_ words: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(words, id: \.self) { word in
                    chip(word)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Die Fassung mit Umbruch — für „Sonst notiert", wo es selten mehr als
    /// zwei Wörter sind und eine scrollende Reihe nur Mechanik wäre.
    private func umbrechendeChips(_ words: [String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.sm)],
            alignment: .leading,
            spacing: Theme.Spacing.sm
        ) {
            ForEach(words, id: \.self) { word in
                chip(word)
            }
        }
    }

    private func chip(_ word: String) -> some View {
        let isOn = gewählt.contains(word)
        return Button {
            withAnimation(.snappy) { toggle(word) }
        } label: {
            Text(word)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(minWidth: 64)
                .frame(height: 44)
                .background(
                    isOn ? Theme.accent : Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                        .strokeBorder(isOn ? Color.clear : Theme.stroke)
                )
        }
        .buttonStyle(TactileButtonStyle())
        // Farbe allein sagt es nicht — `.isSelected` ist, was VoiceOver
        // vorliest, und der Audit prüft auf die Beschriftung.
        .accessibilityLabel(word)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// Ein Chip schreibt sofort durch — wie in der Schicht beim Anlegen.
    private func toggle(_ word: String) {
        list?.setDetail(
            ItemDetailVocabulary.toggling(word, in: gewählt, reihen: reihen),
            note: note,
            for: item
        )
    }

    // MARK: Der Übergang zu den Treffern

    /// **Eine Überschrift, damit der Bildschirm zwei Hälften hat und nicht
    /// eine lange Rutsche.** Ohne sie stünden Chipreihen und Angebotszeilen
    /// als derselbe Stoff untereinander; mit ihr sagt der Bildschirm, wo die
    /// eigene Angabe aufhört und die Auskunft der App anfängt.
    private var trefferKopf: some View {
        Section { EmptyView() } header: {
            Text("Angebote diese Woche")
                .accessibilityIdentifier("itemSheet.offers.header")
        }
    }

    // MARK: Löschen

    /// **Am Ende, allein, und ohne Nachfrage** — wie „Liste leeren" oben im
    /// Menü der Liste eine hat, hier aber nicht: Ein Artikel ist ein Wort, und
    /// wer ihn versehentlich löscht, tippt ihn in drei Sekunden wieder.
    private var löschenSection: some View {
        Section {
            Button(role: .destructive) {
                list?.remove(item)
                dismiss()
            } label: {
                Label("Löschen", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
                    // Die Rolle allein färbt hier nicht: Die Zeile erbt den
                    // Akzent der App (grün), und ein grünes „Löschen" ist die
                    // falsche Ansage. Am gerenderten Bild gesehen.
                    //
                    // `Theme.error` und nicht `.red`: Systemrot steht auf der
                    // Creme bei rund 3,3:1 und fiele im Kontrast-Audit durch.
                    // Der Token ist genau dafür da (20.07.).
                    .foregroundStyle(Theme.error)
            }
            .accessibilityIdentifier("itemSheet.delete")
        }
        .listRowBackground(Theme.surface)
    }

    // MARK: Was die App aus dem Wort gemacht hat

    /// Der Kopf des Trefferblatts: **als was** das getippte Wort gesucht wurde.
    ///
    /// Er steht oben und nicht an jeder Zeile, weil er bei einem Suchwort auf
    /// jeder Zeile derselbe wäre. Und er steht **auch dann**, wenn unten nichts
    /// ist — der leere Bildschirm ist genau der, auf dem die Frage brennt.
    @ViewBuilder
    private var understandingSection: some View {
        let reading = understanding
        if reading.headline != nil || reading.unknownNote != nil {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if let headline = reading.headline {
                        HStack(spacing: Theme.Spacing.xs) {
                            // Rein dekorativ, und deshalb ausdrücklich stumm:
                            // Der Satz daneben sagt schon alles. Ohne diese
                            // Zeile meldet `testShoppingListAndSettingsPassTheAudit`
                            // „Label not human-readable — text.magnifyingglass"
                            // — vom Audit gefunden, nicht überlegt.
                            Image(systemName: "text.magnifyingglass")
                                .foregroundStyle(Theme.secondaryText)
                                .accessibilityHidden(true)
                            Text(headline)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("matches.understanding")
                        }
                    }
                    if let note = reading.unknownNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("matches.understanding.unknown")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Spacing.xs)
            }
            .listRowBackground(Theme.surface)
        }
    }

    // MARK: Die Heftung, die nicht in der Liste steht

    /// Die geheftete Wahl, wenn sie unten nicht vorkommt.
    ///
    /// **Ohne diesen Abschnitt wäre die Heftung eine Sackgasse.** Es gibt zwei
    /// Wege dorthin, und beide sind echt: Das Produkt ist diese Woche nicht im
    /// Angebot (dann fällt die Liste sichtbar aufs billigste zurück), oder es
    /// ist im Angebot, aber der Matcher findet es unter diesem Listenwort nicht
    /// mehr — die Heftung geht ja absichtlich an ihm vorbei. In beiden Fällen
    /// taucht das Produkt in keiner Trefferzeile auf, und ohne eine eigene
    /// Zeile könnte man eine Wahl, die man nicht mehr will, nie wieder
    /// loswerden.
    private func pinnedSection(_ pin: PinnedOffer) -> some View {
        let vorhanden = ShoppingListMatcher.pinnedOffer(pin, in: offers)
        return Section("Angeheftet") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(pin.product)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Theme.Spacing.sm)
                    if let price = vorhanden?.price {
                        PriceText(amount: price)
                    }
                }
                Text(vorhanden == nil
                     ? "\(pin.absenceLine) bei \(pin.market). Solange steht das billigste Angebot auf deiner Liste."
                     : "Bei \(pin.market) im Angebot. Es steht auf deiner Liste, obwohl die Suche nach „\(item.text)\u{201C} es diese Woche nicht findet.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.md) {
                    Button("Heftung lösen") { unpin(pin) }
                        .accessibilityIdentifier("matches.unpin.dormant")
                    // „Als eigenes Produkt trennen" ([UI-7]): Hafermilch ist
                    // kein Ersatz für Milch, sondern ein eigener Bedarf.
                    Button("Als eigenes Produkt") { split(pin) }
                        .accessibilityIdentifier("matches.split")
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(TactileButtonStyle())
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .listRowBackground(Theme.surface)
    }

    // MARK: Die Trefferzeile

    private func matchRow(_ match: OfferMatch, isRejected: Bool) -> some View {
        let offer = match.offer
        let isPinned = pins.contains { offer.matches($0) }
        return HStack(spacing: Theme.Spacing.sm) {
            // Die Zeile führt jetzt ins Detail. Vorher war sie ein reiner
            // HStack: Man sah Produkt, Markt und Preis — und kam nicht weiter.
            // Ausgerechnet hier, wo man vor dem Einkauf entscheidet, fehlte
            // Packungsgröße, Gültigkeit und Preisverlauf.
            NavigationLink(value: offer) {
                HStack(spacing: Theme.Spacing.sm) {
                    OfferThumbnail(
                        imageUrl: offer.imageUrl, emoji: offer.emoji,
                        category: offer.category, title: offer.product, size: 40
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.product)
                            .font(.subheadline)
                            // Drei statt zwei Zeilen, seit die Reißzwecke
                            // neben dem ✕ steht: Die Zeile hat 44 pt Breite
                            // an den Namen verloren, und genau hier entscheidet
                            // sich jemand zwischen zwei Produkten. Höhe ist in
                            // einer scrollenden Liste billig, Breite nicht.
                            .lineLimit(3)
                        HStack(spacing: Theme.Spacing.xs) {
                            if isPinned { PinnedBadge() }
                            // Markt und Herkunft in **einem** Text: zwei
                            // Beschriftungen nebeneinander sind zwei Elemente
                            // im Bedienungshilfen-Baum und zwei Messstellen im
                            // Kontrast-Audit, für einen Satz.
                            Text(rowSubtitle(match, isPinned: isPinned))
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    if let price = offer.price {
                        PriceText(amount: price)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(offer.voiceOverSummary)
            .accessibilityHint("Öffnet die Details zum Angebot")

            // Der Knopf, der aus der Rückmeldung eine Auswahl macht. Links vom
            // ✕, weil er die häufigere und die harmlosere der beiden Gesten
            // ist — und weil das Wegwerfen dort bleibt, wo Testerhände es
            // schon kennen.
            //
            // **Ein zweiter Pin ersetzt den ersten nicht, er kommt dazu**
            // (Scott, [UI-7], 01.08.). „Milch" trägt dann Bio-Milch *und*
            // normale Milch als eigene Positionen. Pin heißt immer „ich will
            // es"; die Lesart „eins von beiden" gibt es gratis über die nicht
            // weggeklickten Vorschläge — ✕ = nie, Pin = auf jeden Fall,
            // unberührt = entscheide du.
            Button {
                withAnimation(Theme.Motion.element.animation) { togglePin(offer) }
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.title3)
                    .foregroundStyle(isPinned ? Theme.accent : Theme.secondaryText)
                    // [UI-6]: Vorher wechselte das Zeichen hart. Der
                    // Symbolwechsel ist die Bewegung, die zu einem 44-pt-Knopf
                    // passt — kein Hüpfen, kein Aufblitzen.
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            // Fester Griff für die Journey: Die Beschriftung wechselt mit dem
            // Zustand, der Bezeichner nicht.
            .accessibilityIdentifier("matches.pin")
            .accessibilityLabel(isPinned ? "Heftung lösen" : "Auf die Liste heften")
            .accessibilityHint(isPinned
                               ? "Nimmt dieses Produkt wieder von der Liste"
                               : "Dieses Angebot steht dann dauerhaft auf der Liste, zusätzlich zu schon gehefteten")

            Button {
                withAnimation {
                    if isRejected {
                        rejections.unreject(itemText: item.query, offer: offer)
                    } else {
                        rejections.reject(itemText: item.query, offer: offer)
                        // Wer das geheftete Angebot weglegt, hat es sich
                        // anders überlegt — die Heftung geht mit. Sonst
                        // stünde ein weggelegtes Angebot weiter auf der
                        // Liste, und das ✕ wäre ein Knopf ohne Wirkung.
                        if isPinned { togglePin(offer) }
                        // The rejection is already done and persisted; the
                        // question is an optional afterthought on top of it.
                        if feedback.isAskingEnabled { askingAbout = match }
                    }
                }
            } label: {
                Image(systemName: isRejected ? "arrow.uturn.backward.circle" : "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel(isRejected ? "Wieder vorschlagen" : "Weglegen")
        }
        .opacity(isRejected ? 0.5 : 1)
    }

    /// Markt — und, wenn es etwas zu unterscheiden gibt, woher dieser Treffer
    /// kommt.
    ///
    /// **Das ersetzt „Genau das" / „Passt vielleicht".** Die zwei Abzeichen
    /// behaupteten Güte und beschrieben Mechanik, und in Scotts Screenshot vom
    /// 01.08. kippt das ins Gegenteil: Der Speck-Käse-Twister nennt „Käse"
    /// wörtlich und bekam „Genau das", der GRÜNLÄNDER Schnittkäse trägt es nur
    /// zusammengeschrieben und bekam „Passt vielleicht". Ein Wort im Titel ist
    /// das **schwächere** Signal, wurde aber als das stärkere angezeigt.
    ///
    /// Die Unterscheidung selbst verschwindet nicht — bei „vegan" ist ein
    /// Tag-Treffer wirklich ein Vielleicht. Sie sagt ab jetzt nur, **worüber**
    /// die Zeile gefunden wurde, und behauptet nicht mehr, wie gut sie ist.
    private func rowSubtitle(_ match: OfferMatch, isPinned: Bool) -> String {
        // Bei einer Heftung ist die Frage „warum steht das hier" schon vom
        // Abzeichen beantwortet: weil ein Mensch es ausgesucht hat.
        guard !isPinned, routesDiffer else { return match.offer.market }
        let note = QueryUnderstanding.rowNote(
            for: item.query, of: match.offer,
            namesWords: understanding.words.count > 1
        )
        return "\(match.offer.market) · \(note ?? "im Namen")"
    }

    /// Heften und Weglegen sind zwei Aussagen über dasselbe Angebot; sie dürfen
    /// einander nicht widersprechen. Wer heftet, holt es damit zurück.
    private func togglePin(_ offer: Offer) {
        rejections.unreject(itemText: item.query, offer: offer)
        list?.togglePin(offer.asPin, for: item)
    }

    /// Löst eine Heftung, deren Produkt diese Woche gar nicht im Vorrat steht.
    private func unpin(_ pin: PinnedOffer) {
        list?.togglePin(pin, for: item)
    }

    /// „Als eigenes Produkt trennen" (Scott, [UI-7]).
    ///
    /// Hafermilch ist kein Ersatz für Milch, sondern ein eigener Bedarf. Wer
    /// sie unter „Milch" anheftet, kann sie hier zu einem eigenen Eintrag
    /// machen — mit eigenem Suchbegriff, und er bleibt auch nächste Woche.
    private func split(_ pin: PinnedOffer) {
        list?.splitPinIntoOwnItem(pin, from: item)
        dismiss()
    }
}

/// Das Abzeichen der eigenen Wahl. Steht an derselben Stelle wie
/// `MatchKindBadge` und ersetzt es: Ob der Matcher das Angebot für „Genau das"
/// hält, ist bedeutungslos, sobald ein Mensch es selbst ausgesucht hat.
struct PinnedBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "pin.fill")
            Text("Deine Wahl")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Theme.accent.opacity(0.15), in: Capsule())
        .foregroundStyle(Theme.accent)
        // **„Dei ne Wa hl"**, gemeldet am 01.08.: In einer engen Spalte bekam
        // das Abzeichen den Rest der Breite und brach mitten im Wort um. Beides
        // zusammen hält es in einer Zeile — `lineLimit` allein ließe es noch
        // auf „Deine W…" kürzen. `BadgeLayoutTests` misst das.
        .lineLimit(1)
        .fixedSize()
    }
}

#Preview {
    ItemSheet(item: ShoppingItem(text: "Milch", detail: ["1 l"]), offers: MockFixtures.offers)
        .environment(MatchRejectionStore())
        // Beide neu seit der Rückfrage: die Ablehnung liest den Schalter,
        // das Sheet die install_id. Fehlt einer, stürzt die Preview beim
        // ersten Tippen auf ✕ ab statt sie nur anders auszusehen.
        .environment(MatchFeedbackStore())
        .environment(ProfileStore())
        // Neu für die Heftung: ohne sie ist die Reißzwecke ein toter Knopf.
        .environment(ShoppingListStore())
}
