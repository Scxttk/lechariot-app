import SwiftUI

/// The chips that make up an item's detail line.
///
/// **A note, not a search.** The sheet says so out loud rather than leaving it
/// to be inferred: what is chosen here appears under the item and goes nowhere
/// else — not into the query, not into the offer comparison, not into anything
/// that leaves the phone. Somebody choosing "Bio" would otherwise reasonably
/// expect the offer underneath to change, and it does not.
struct ItemDetailSheet: View {
    let item: ShoppingItem
    let onSave: ([String], String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: [String]
    @State private var note: String

    init(item: ShoppingItem, onSave: @escaping ([String], String) -> Void) {
        self.item = item
        self.onSave = onSave
        _chosen = State(initialValue: item.detail ?? [])
        _note = State(initialValue: item.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    Text("Steht unter dem Artikel — für dich im Laden. Die Suche nach Angeboten benutzt weiter nur „\(item.text)\u{201C}.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)

                    ForEach(ItemDetailVocabulary.groups) { group in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                            chips(of: group)
                        }
                    }

                    // **Der Freitext** ([UI-8], Scott 01.08.). Der Wortschatz
                    // daneben ist bewusst ein Wortschatz; hier gibt es doch
                    // etwas zu tippen, und dafür gilt die Regel aus der
                    // Überschrift dieser Datei doppelt: Was hier steht, geht
                    // nirgendwo hin. Nicht in die Suche, nicht in die
                    // Marktrechnung, **nicht in den Rückmeldungs-Payload**.
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Notiz")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        TextField("z. B. die im blauen Becher", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.plain)
                            .padding(Theme.Spacing.sm)
                            .background(
                                Theme.surface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                                    .strokeBorder(Theme.stroke)
                            )
                            .accessibilityIdentifier("itemDetail.note")
                            .accessibilityLabel("Notiz zum Artikel")
                            .accessibilityHint("Bleibt auf dem Gerät und geht nicht in die Suche")
                    }

                    // Words from an older vocabulary keep their place and stay
                    // removable — see `ItemDetailVocabulary.group(of:)`.
                    if !strangers.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Sonst notiert")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                            chipRow(strangers)
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .themedScreen()
            .navigationTitle(item.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("itemDetail.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        onSave(chosen, note)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("itemDetail.done")
                }
            }
        }
    }

    private var strangers: [String] {
        chosen.filter { ItemDetailVocabulary.group(of: $0) == nil }
    }

    private func chips(of group: ItemDetailVocabulary.Group) -> some View {
        chipRow(group.chips)
    }

    private func chipRow(_ words: [String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.sm)],
            alignment: .leading,
            spacing: Theme.Spacing.sm
        ) {
            ForEach(words, id: \.self) { word in
                let isOn = chosen.contains(word)
                Button {
                    withAnimation(.snappy) {
                        chosen = ItemDetailVocabulary.toggling(word, in: chosen)
                    }
                } label: {
                    Text(word)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                        .frame(maxWidth: .infinity)
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
                // Colour alone would not say it — `.isSelected` is what
                // VoiceOver reads out, and the audit checks for the label.
                .accessibilityLabel(word)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

#Preview {
    ItemDetailSheet(item: ShoppingItem(text: "Milch", detail: ["1 l", "Bio"])) { _, _ in }
}
