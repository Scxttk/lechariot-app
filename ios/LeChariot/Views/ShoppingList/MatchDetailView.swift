import SwiftUI

/// Sheet listing every offer matched for one list item — direct hits and
/// category hits labeled — with per-offer rejection. Rejections persist via
/// MatchRejectionStore and expire with the offer week.
///
/// **Und seit dem Tester-Wunsch vom 2026-07-31 der Ort, an dem man wählt.**
/// Vorher konnte man hier nur wegwerfen: Das ✕ ist Rückmeldung, keine Auswahl,
/// und wer den zweitbilligsten Käse lieber mochte, hatte keinen Knopf dafür.
/// Jetzt heftet die Reißzwecke ein Angebot an den Listeneintrag — es steht dann
/// dauerhaft auf der Hauptseite, statt jede Woche vom billigsten überschrieben
/// zu werden.
struct MatchDetailView: View {
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

    private var allMatches: [OfferMatch] {
        ShoppingListMatcher.matches(for: item.query, in: offers)
    }

    /// Die aktuelle Heftung — **aus dem Speicher**, nicht aus `item`.
    ///
    /// `item` ist die Kopie, mit der das Blatt geöffnet wurde; sie wüsste von
    /// einer Heftung, die auf diesem Blatt gerade gesetzt wurde, nichts. Ohne
    /// den Speicher (Previews) bleibt sie der Stand von damals.
    private var pin: PinnedOffer? {
        guard let list else { return item.pinned }
        return list.items.first { $0.id == item.id }?.pinned
    }

    /// Das geheftete Angebot, falls es diese Woche dabei ist.
    private var pinnedOffer: Offer? {
        pin.flatMap { ShoppingListMatcher.pinnedOffer($0, in: offers) }
    }

    /// Ob die geheftete Wahl in der Trefferliste unten überhaupt vorkommt.
    ///
    /// Sie kann fehlen, ohne dass es die Woche war: Die Heftung geht am Matcher
    /// vorbei, also steht ein geheftetes Produkt auch dann auf der Liste, wenn
    /// sein Prospekttitel ein Wort verloren hat oder ein Tag weggefallen ist.
    private var pinIsListed: Bool {
        guard let pin else { return false }
        return allMatches.contains { $0.offer.matches(pin) }
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
                if let pin, !pinIsListed {
                    pinnedSection(pin)
                }

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
                        Text("Tippe die Reißzwecke, um ein Angebot dauerhaft auf die Liste zu heften — auch wenn es nicht das billigste ist. Passt eines gar nicht zu deinem Artikel? Leg es weg, dann schlägt Le Chariot es nicht mehr vor.")
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
            }
            .themedScreen()
            .navigationTitle("Treffer für „\(item.text)\u{201C}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
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
        let vorhanden = pinnedOffer
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
                Button("Heftung lösen") { setPin(nil) }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityIdentifier("matches.unpin.dormant")
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .listRowBackground(Theme.surface)
    }

    // MARK: Die Trefferzeile

    private func matchRow(_ match: OfferMatch, isRejected: Bool) -> some View {
        let offer = match.offer
        let isPinned = pin.map { offer.matches($0) } == true
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
                            if isPinned {
                                PinnedBadge()
                            } else {
                                MatchKindBadge(kind: match.kind)
                            }
                            Text(offer.market)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
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
            Button {
                withAnimation { setPin(isPinned ? nil : offer.asPin) }
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.title3)
                    .foregroundStyle(isPinned ? Theme.accent : Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            // Fester Griff für die Journey: Die Beschriftung wechselt mit dem
            // Zustand, der Bezeichner nicht.
            .accessibilityIdentifier("matches.pin")
            .accessibilityLabel(isPinned ? "Heftung lösen" : "Auf die Liste heften")
            .accessibilityHint(isPinned
                               ? "Dann steht wieder das billigste Angebot auf der Liste"
                               : "Dieses Angebot steht dann dauerhaft auf der Liste")

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
                        if isPinned { setPin(nil) }
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

    /// Heften und Weglegen sind zwei Aussagen über dasselbe Angebot; sie dürfen
    /// einander nicht widersprechen. Wer heftet, holt es damit zurück.
    private func setPin(_ pin: PinnedOffer?) {
        if let pin, let offer = ShoppingListMatcher.pinnedOffer(pin, in: offers) {
            rejections.unreject(itemText: item.query, offer: offer)
        }
        list?.setPin(pin, for: item)
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
    }
}

#Preview {
    MatchDetailView(item: ShoppingItem(text: "Milch"), offers: MockFixtures.offers)
        .environment(MatchRejectionStore())
        // Beide neu seit der Rückfrage: die Ablehnung liest den Schalter,
        // das Sheet die install_id. Fehlt einer, stürzt die Preview beim
        // ersten Tippen auf ✕ ab statt sie nur anders auszusehen.
        .environment(MatchFeedbackStore())
        .environment(ProfileStore())
        // Neu für die Heftung: ohne sie ist die Reißzwecke ein toter Knopf.
        .environment(ShoppingListStore())
}
