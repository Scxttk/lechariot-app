import SwiftUI

/// **Die Einrichtungs-Checkliste** — vier Punkte, halb voll ab dem ersten
/// Blick (Endowed-Progress-Effekt, Punkt 9 der Onboarding-Forschung).
///
/// Sie fängt die auf, die das Onboarding oder den Rundgang übersprungen
/// haben: „Profil erstellt" ist geschenkt (wer sie sieht, hat den Assistenten
/// hinter sich), die offenen Punkte führen mit einem Tipp zur Handlung —
/// Markt in den Wähler, Artikel in die Eingabezeile. Der Treffer-Punkt hat
/// keinen Knopf, weil es zu ihm nichts zu drücken gibt: Er erledigt sich von
/// selbst, sobald ein Artikel der Liste im Angebot ist.
///
/// Wann sie steht und wann nicht, entscheidet `ListGuidance`; dass sie nach
/// dem vierten Haken für immer verschwindet, versiegelt `SetupProgressStore`.
struct SetupChecklistCard: View {
    let hasMarkets: Bool
    let firstItemAdded: Bool
    let firstMatchSeen: Bool
    var onChooseMarkets: () -> Void = {}
    var onAddItem: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Text("Dein Start")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.secondaryText)
                        .padding(Theme.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityLabel("Checkliste ausblenden")
                .accessibilityIdentifier("list.checklist.dismiss")
            }

            doneRow("Profil erstellt")
            if hasMarkets {
                doneRow("Markt gewählt")
            } else {
                openRow(
                    "Markt wählen",
                    action: onChooseMarkets,
                    identifier: "list.checklist.markets"
                )
            }
            if firstItemAdded {
                doneRow("Erster Artikel auf der Liste")
            } else {
                openRow(
                    "Ersten Artikel hinzufügen",
                    action: onAddItem,
                    identifier: "list.checklist.item"
                )
            }
            if firstMatchSeen {
                doneRow("Erster Angebots-Treffer")
            } else {
                waitingRow(
                    "Erster Angebots-Treffer",
                    note: "kommt von allein, sobald ein Artikel deiner Liste im Angebot ist"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        // Ohne Bezeichner auf der Karte selbst — er überschriebe die der
        // Zeilen darin, siehe `FirstItemCard`.
        .themeCard()
    }

    private func doneRow(_ title: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .strikethrough()
            Spacer(minLength: 0)
        }
        // Ein Satz statt „Häkchen, Text": VoiceOver soll den Zustand hören,
        // nicht das Symbol.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Erledigt: \(title)")
    }

    private func openRow(_ title: String, action: @escaping () -> Void, identifier: String) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    /// Der Punkt ohne Knopf. Der Halbsatz daneben ist keine Dekoration: Ohne
    /// ihn sähe die Zeile aus wie ein kaputter Knopf — ein offener Punkt, auf
    /// dem ein Tipp nichts tut.
    private func waitingRow(_ title: String, note: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) — \(note)")
    }
}

#Preview("Halb voll") {
    SetupChecklistCard(hasMarkets: false, firstItemAdded: true, firstMatchSeen: false)
        .padding()
}

#Preview("Fast fertig") {
    SetupChecklistCard(hasMarkets: true, firstItemAdded: true, firstMatchSeen: false)
        .padding()
}
