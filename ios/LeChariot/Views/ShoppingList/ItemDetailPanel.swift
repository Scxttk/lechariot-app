import SwiftUI

/// Die Angaben zum eben angelegten Artikel — **als Schicht, nicht als Blatt.**
///
/// Scotts Rückmeldung vom 03.08., nach dem Bring!-Video Bild für Bild: „Das
/// Mengen-Menü blockiert das Weitertippen — genau das, was Bring! nicht tut."
/// Bis dahin war das hier ein `.sheet`, das beim Anlegen von selbst aufging,
/// dem Eingabefeld den Fokus nahm und ein „Fertig" verlangte, bevor der nächste
/// Artikel getippt werden konnte. Drei Artikel hintereinander waren drei
/// Tastatur-Abbrüche.
///
/// **Was diese Ansicht anders macht — und es sind vier Dinge, keine Geschmacks-
/// frage:**
///
/// 1. Sie liegt zwischen Liste und Eingabezeile, im selben Block wie die
///    Vorschläge. Kein Modal, keine sichere Fläche, kein Fokus.
/// 2. Sie hat **keinen „Fertig"-Knopf**, weil es nichts zu bestätigen gibt:
///    Jeder Chip schreibt sofort durch. Ein ignoriertes Panel speichert nichts
///    und richtet nichts an — es wird beim nächsten Artikel schlicht ersetzt.
/// 3. Die Kachelzeile oben zeigt, was gerade entstanden ist; der aktive Artikel
///    hervorgehoben, die vorigen ruhig. Man sieht seinen eigenen Fluss, ohne die
///    Liste zu verlassen.
/// 4. Die volle Fassung (Freitext, Gruppen mit Überschriften, alte Wörter)
///    liegt einen benannten Knopf weiter — sie ist eine Absicht, kein
///    Durchgangszimmer.
struct ItemDetailPanel: View {
    /// Der Artikel, dessen Angaben hier stehen. **Live aus dem Speicher
    /// gereicht**, nicht kopiert: Ein Chip, den man antippt, muss im selben
    /// Durchgang eingefärbt zurückkommen.
    let item: ShoppingItem
    /// Die zuletzt angelegten Artikel, ältester zuerst.
    let recent: [ShoppingItem]
    let onFocus: (ShoppingItem) -> Void
    let onToggleChip: (String) -> Void
    let onOpenFull: () -> Void

    /// Die Höhe des Wortschatz-Feldes. Fest, nicht mitwachsend: Ob ein Artikel
    /// zwei Chips gewählt hat oder keinen, darf die Eingabezeile darunter nicht
    /// bewegen — dieselbe Regel wie beim Wörterbuch-Streifen. Zwei Reihen plus
    /// ein angeschnittener Rest, damit sichtbar ist, dass es weitergeht.
    @ScaledMetric(relativeTo: .subheadline) private var vocabularyHeight: CGFloat = 128

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
            vocabulary
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .readableWidth()
        // **Kein Bezeichner auf dem Behälter.** Er erbt sich auf jedes Kind
        // und überschreibt dessen eigenen — am Simulator gemessen: „Notiz …"
        // trug danach `list.detailPanel` statt `list.detailPanel.more` und war
        // für keine Journey mehr auffindbar. Dieselbe Falle steht seit dem
        // 30.07. in `TutorialOverlay` beschrieben.
        // **Ein- und ausblenden, nicht schieben — und das ist keine
        // Geschmacksfrage.** `.move(edge: .bottom)` verschiebt die Schicht in
        // ihren Platz hinein, und der Rundgang-Anker nimmt diese Verschiebung
        // mit: Am 03.08. gemessen lag sein Loch danach dauerhaft 186 pt tiefer
        // als die Schicht, die der Rahmen erklärt — der Anker wird nach der
        // Bewegung nicht noch einmal gemeldet. Ohne Versatz kein falsches Loch.
        .transition(.opacity)
    }

    // MARK: Kachelzeile

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(recent) { entry in
                        recentChip(entry)
                    }
                }
            }
            // Vorrang, sonst nimmt die gierige Scroll-Ansicht daneben die ganze
            // Breite und drückt den Knopf auf null — am Simulator gemessen:
            // Die Kachelzeile stand, der Knopf war im Baum nicht auffindbar.
            moreButton
                .fixedSize()
                .layoutPriority(1)
        }
    }

    private func recentChip(_ entry: ShoppingItem) -> some View {
        let isActive = entry.id == item.id
        return Button {
            onFocus(entry)
        } label: {
            Text(entry.text)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? Theme.onAccent : Theme.secondaryText)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 32)
                .background(
                    isActive ? Theme.accent : Theme.surface,
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(isActive ? Color.clear : Theme.stroke))
        }
        .buttonStyle(TactileButtonStyle())
        // Der Artikelname allein wäre die Beschriftung der Listenzeile — zwei
        // Knöpfe mit demselben Namen auf einem Bildschirm, und keine Journey
        // könnte sie auseinanderhalten.
        .accessibilityLabel("Angaben zu \(entry.text)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("list.detailPanel.recent")
    }

    /// Der Weg in die volle Fassung. **Benannt statt nur ein Zeichen:** Hier
    /// liegt der Freitext, und ein Punkt-Punkt-Punkt-Knopf sagt niemandem, dass
    /// man dahinter etwas schreiben kann.
    private var moreButton: some View {
        Button(action: onOpenFull) {
            Text("Notiz …")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 32)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.stroke))
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("Notiz und alle Angaben zu \(item.text)")
        .accessibilityIdentifier("list.detailPanel.more")
    }

    // MARK: Wortschatz

    private var vocabulary: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(ItemDetailVocabulary.groups) { group in
                    groupRow(group)
                }
            }
        }
        .frame(height: vocabularyHeight)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func groupRow(_ group: ItemDetailVocabulary.Group) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(group.chips, id: \.self) { chip in
                        chipButton(chip)
                    }
                }
            }
        }
    }

    private func chipButton(_ word: String) -> some View {
        let isOn = (item.detail ?? []).contains(word)
        return Button {
            onToggleChip(word)
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
}

#Preview {
    let milch = ShoppingItem(text: "Milch", detail: ["1 l"])
    return VStack {
        Spacer()
        ItemDetailPanel(
            item: milch,
            recent: [ShoppingItem(text: "Butter"), ShoppingItem(text: "Kaffee"), milch],
            onFocus: { _ in },
            onToggleChip: { _ in },
            onOpenFull: {}
        )
    }
    .background(.bar)
}
