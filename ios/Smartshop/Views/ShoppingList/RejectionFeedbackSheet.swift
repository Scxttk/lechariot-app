import SwiftUI

/// Asks why a match was rejected, right after it was rejected.
///
/// The rejection has already happened when this appears and does not depend on
/// the answer — closing the sheet, skipping, or having no network changes
/// nothing about it. That is the whole deal being offered: the user gets their
/// result immediately and may explain afterwards if they feel like it.
///
/// The options are the point, not the text field. Each one maps to exactly one
/// dictionary operation (see `RejectionReason`), and "Mag ich einfach nicht"
/// exists so preferences can be told apart from real mistakes instead of being
/// silently folded into them.
struct RejectionFeedbackSheet: View {
    let itemText: String
    let match: OfferMatch

    @Environment(MatchFeedbackStore.self) private var feedback
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    @State private var reason: RejectionReason?
    @State private var comment = ""
    @State private var isSending = false
    @FocusState private var commentFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(RejectionReason.allCases) { option in
                        reasonRow(option)
                    }
                } header: {
                    Text("Was stimmt nicht?")
                } footer: {
                    Text("„\(match.offer.product)“ ist für „\(itemText)“ weggelegt — das bleibt so, egal was du hier tust.")
                }
                .listRowBackground(Theme.surface)

                Section {
                    TextField("Optional: was war es genau?", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($commentFocused)
                } footer: {
                    Text("Übertragen werden deine Auswahl, dein Text, der Artikel und das Angebot — verknüpft mit einer Zufallsnummer dieser Installation, nicht mit dir.")
                }
                .listRowBackground(Theme.surface)
            }
            .themedScreen()
            .navigationTitle("Kurze Rückfrage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Überspringen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Senden", action: send)
                        .fontWeight(.semibold)
                        .disabled(reason == nil || isSending)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func reasonRow(_ option: RejectionReason) -> some View {
        Button {
            reason = option
            // "Anderes" without a text says nothing at all, so open the field.
            if option == .other { commentFocused = true }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: option.symbol)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.body)
                    Text(option.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.accent)
                    .opacity(reason == option ? 1 : 0)
            }
            // The middle of the row is a Spacer and would otherwise not react.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.label). \(option.hint)")
        .accessibilityAddTraits(reason == option ? [.isButton, .isSelected] : .isButton)
    }

    private func send() {
        guard let reason else { return }
        isSending = true
        let report = MatchFeedbackReport(
            installId: profile.profile.installId,
            query: itemText,
            offer: match.offer,
            kind: match.kind,
            reason: reason,
            comment: comment
        )
        Task {
            await feedback.submit(report)
            dismiss()
        }
    }
}

#Preview {
    RejectionFeedbackSheet(
        itemText: "Käse",
        match: OfferMatch(offer: MockFixtures.offers[0], kind: .category)
    )
    .environment(MatchFeedbackStore())
    .environment(ProfileStore())
}
