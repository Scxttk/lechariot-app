import SwiftUI

/// **Der geführte erste Artikel** — die leere Liste lädt zu genau einer
/// konkreten Handlung ein, statt nur zu erklären (NN/g: Machen schlägt
/// Zuschauen; Scotts Punkt 7 aus der Onboarding-Forschung).
///
/// Zwei Fassungen, eine Fläche:
///
/// - **Mit Angeboten** stehen hier zwei, drei echte Wochenangebote als
///   Beispiel-Artikel („Butter — diese Woche bei Kaufland im Angebot"),
///   Things-3-Stil: klar als Vorschlag markiert, ein Tipp legt an, ✕ lässt
///   verschwinden. Der Aha-Moment ist eingebaut — was hier steht, bekommt auf
///   der Liste sofort seine Treffer-Kachel.
/// - **Ohne Angebote** (der Normalfall direkt nach dem Onboarding: keine
///   Filiale, also bewusst leerer `OfferStore`) bleibt der eine Satz:
///   „Füg mal ‚Milch‘ hinzu" — als `FirstItemPrompt` in der Ansprache, nicht
///   als zweite Karte neben der Filialen-Karte. Die Vorfahrt regelt
///   `ListGuidance`.
struct FirstItemCard: View {
    let examples: [FirstItemExample]
    var onAdd: (String) -> Void = { _ in }
    var onDismiss: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Fang mit einem Artikel an")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            // Der Satz, der die Zeilen zu Vorschlägen macht. Ohne ihn sähen
            // drei fremde Wörter auf einer leeren Liste aus, als hätte die App
            // schon eingekauft — genau das darf sie nie.
            Text("Zum Ausprobieren — erst dein Tipp legt etwas auf die Liste.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(examples) { example in
                    exampleRow(example)
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .themeCard()
    }

    // **Kein Bezeichner auf der Karte selbst.** Ein
    // `accessibilityIdentifier` auf einem Container überschreibt die
    // Bezeichner *aller* Kinder: Im Elementbaum hießen dann Überschrift,
    // Fließtext und beide Knöpfe `list.firstItem`, und keine Journey fand
    // mehr ihren Knopf. Genauso in `SetupChecklistCard` und bei jeder
    // weiteren Karte — die Bezeichner gehören an die Elemente, die gedrückt
    // werden.

    private func exampleRow(_ example: FirstItemExample) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                onAdd(example.word)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.word)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                        Text(example.reason)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.sm)
                .background(
                    Theme.background,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                        .strokeBorder(Theme.stroke)
                )
            }
            .buttonStyle(TactileButtonStyle())
            // Bewusst nicht „… hinzufügen": Die Kacheln in „Häufig gekauft"
            // heißen so, und zwei gleich benannte Knöpfe auf einem Bildschirm
            // sind für VoiceOver wie für die Journeys nicht zu unterscheiden.
            .accessibilityLabel("\(example.word) auf die Liste legen — \(example.reason)")
            .accessibilityIdentifier("list.firstItem.add.\(example.word)")

            Button {
                onDismiss(example.word)
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel("Vorschlag \(example.word) ausblenden")
            .accessibilityIdentifier("list.firstItem.dismiss.\(example.word)")
        }
    }
}

/// Die eine konkrete Einladung, wenn es keine Angebote zu zeigen gibt:
/// „Füg mal ‚Milch‘ hinzu".
///
/// Gehört zur Ansprache über der leeren Liste, nicht zu den Führungskarten —
/// deshalb steht sie auch **neben** der Filialen-Karte, ohne die
/// Eine-Fläche-Regel aus `ListGuidance` zu brechen: Der erste Artikel und die
/// erste Filiale sind zwei verschiedene nächste Schritte, und der Artikel
/// kommt zuerst (der Aha-Moment passiert in den eigenen Daten).
struct FirstItemPrompt: View {
    let word: String
    var onAdd: (String) -> Void = { _ in }

    var body: some View {
        Button {
            onAdd(word)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                Text("Füg mal \u{201E}\(word)\u{201C} hinzu")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(minHeight: 44)
            .background(Theme.accent, in: Capsule())
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("Füg mal \(word) hinzu")
        .accessibilityIdentifier("list.firstItem.prompt")
    }
}

#Preview("Mit Angeboten") {
    FirstItemCard(examples: [
        FirstItemExample(word: "Butter", market: "Kaufland", discountPercent: 30),
        FirstItemExample(word: "Kaffee", market: "Penny", discountPercent: 25),
        FirstItemExample(word: "Milch", market: "Lidl", discountPercent: nil),
    ])
    .padding()
}

#Preview("Nur der Satz") {
    FirstItemPrompt(word: "Milch")
        .padding()
}
