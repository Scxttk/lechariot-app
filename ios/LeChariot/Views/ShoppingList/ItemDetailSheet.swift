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
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: [String]

    init(item: ShoppingItem, onSave: @escaping ([String]) -> Void) {
        self.item = item
        self.onSave = onSave
        _chosen = State(initialValue: item.detail ?? [])
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
                        onSave(chosen)
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
    ItemDetailSheet(item: ShoppingItem(text: "Milch", detail: ["1 l", "Bio"])) { _ in }
}
