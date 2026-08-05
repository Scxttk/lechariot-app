import SwiftUI

/// Die Ernährungsfrage — **im Angebote-Tab statt im Onboarding.**
///
/// Das Onboarding hat sie abgegeben (siehe [[Le Chariot Onboarding-Forschung]]:
/// Fragen nur, wenn die Antwort sichtbar etwas ändert — und dort änderte sie
/// nichts, jeder Frage-Screen kostet Abbrecher). Hier steht sie an dem Ort, an
/// dem die Antwort einmal wirken soll, und erst ab dem zweiten Besuch
/// (`ContextTipTuning.offersVisitsBeforeDietPrompt`).
///
/// **Überspringen ist eine vollständige Antwort.** Das X, „Ich esse alles" und
/// „Fertig" beenden die Frage gleichermaßen endgültig; nichts hängt an ihr,
/// und ändern kann man die Angaben jederzeit in den Einstellungen unter
/// „Profil". Der Text verspricht bewusst nur, was heute wahr ist: Die Angaben
/// landen im Profil. Hervorgehobene Angebote dazu sind Folgearbeit — eine
/// Zusage dazu stünde hier erst, wenn sie eingelöst ist.
struct DietPromptCard: View {
    let profile: ProfileStore
    /// Beendet die Frage endgültig — siehe `ContextTipStore.dismissDietPrompt`.
    let onDismiss: () -> Void

    private var hasSelection: Bool {
        !profile.profile.dietTags.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Text("Isst du irgendetwas nicht?")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.secondaryText)
                        .padding(Theme.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Frage ausblenden")
                .accessibilityIdentifier("offers.dietPrompt.skip")
            }

            Text("Vegetarisch, ohne Laktose, kein Schwein? Sag es einmal — es steht danach in deinem Profil unter „Ernährung“, ändern geht dort jederzeit. Überspringen ist eine genauso gute Antwort.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.sm)],
                alignment: .leading,
                spacing: Theme.Spacing.sm
            ) {
                ForEach(DietTag.allCases) { tag in
                    chip(tag)
                }
            }

            // Ein Knopf, zwei Beschriftungen: Ohne Auswahl ist „Ich esse
            // alles" die ehrliche Antwort auf die Frage oben — ein „Fertig"
            // über sechs unangetippten Chips sagte nicht, was es bedeutet.
            Button(action: onDismiss) {
                Text(hasSelection ? "Fertig" : "Ich esse alles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(minHeight: 44)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityIdentifier("offers.dietPrompt.done")
            .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        // **Kein Bezeichner auf der Karte selbst.** Ein
        // `accessibilityIdentifier` auf einem Container überschreibt die
        // Bezeichner *aller* Kinder — im Elementbaum hießen dann Frage, Chips
        // und Knopf gleich, und keine Journey fände mehr ihren Knopf. Die
        // Bezeichner gehören an das, was gedrückt wird.
        .themeCard()
    }

    /// Ein Chip je Angabe — dieselben Werte, die auch die Einstellungen
    /// schreiben (`ProfileStore.toggleDietTag`), nichts Eigenes daneben.
    private func chip(_ tag: DietTag) -> some View {
        let selected = profile.profile.dietTags.contains(tag)
        return Button {
            withAnimation(.snappy) { profile.toggleDietTag(tag) }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: selected ? "checkmark" : tag.symbol)
                    .font(.caption.weight(.semibold))
                Text(tag.label)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 40)
            .background(
                selected ? Theme.accent.opacity(0.12) : Theme.background,
                in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.45) : Theme.stroke)
            )
            .foregroundStyle(selected ? Theme.accent : .primary)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("offers.dietPrompt.\(tag.rawValue)")
    }
}

#Preview {
    List {
        Section {
            DietPromptCard(profile: ProfileStore(), onDismiss: {})
        }
        .listRowBackground(Color.clear)
    }
}
