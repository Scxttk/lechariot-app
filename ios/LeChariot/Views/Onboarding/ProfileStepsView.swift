import SwiftUI

/// Welcome screen — the app used to open on a bare PLZ field, which asked for
/// data before saying what it was for.
struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        OnboardingStepView(
            step: 1,
            totalSteps: OnboardingStep.total,
            title: "Ein Einkauf, ein Markt, der beste Preis.",
            subtitle: "Schreib deine Einkaufsliste. Le Chariot vergleicht die Wochenangebote deiner Filialen und sagt dir, wo du am besten hinfährst.",
            primaryTitle: "Los geht's",
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                bullet("list.bullet", "Deine Liste", "Artikel eintippen, mehr nicht.")
                bullet("storefront", "Deine Filialen", "Du wählst, welche Märkte zählen.")
                bullet("eurosign.circle", "Ein klares Ergebnis", "Welcher Markt deckt die Liste am besten ab.")
            }
        }
    }

    private func bullet(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// First name, only used for the greeting on the list screen. Never leaves the
/// device — see the note in `UserProfile`.
struct NameStepView: View {
    @Environment(ProfileStore.self) private var profile
    var onContinue: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepView(
            step: 2,
            totalSteps: OnboardingStep.total,
            title: "Wie sollen wir dich nennen?",
            subtitle: "Nur für die Begrüßung. Der Name bleibt auf deinem Gerät.",
            onPrimary: {
                profile.setFirstName(name)
                onContinue()
            },
            skip: (title: "Ohne Namen weiter", action: {
                profile.setFirstName("")
                onContinue()
            })
        ) {
            TextField("Vorname", text: $name)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.done)
                .font(.title3)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 52)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.stroke)
                )
                .accessibilityLabel("Vorname")
        }
        .onAppear {
            name = profile.profile.firstName
            focused = true
        }
    }
}

// **Haushalts- und Ernährungsschritt standen hier bis zum 2026-08-05.**
// Beide Fragen sind aus dem Onboarding raus: Sie füllten ursprünglich die
// Wartezeit eines Backend-Scrapes, den es seit Migration v16 nicht mehr gibt,
// und ihre Antworten änderten sichtbar nichts (Blinkist-Lehre: Fragen stellen
// und ignorieren schadet mehr als nicht fragen). Das Datenmodell
// (`UserProfile`, `ShoppingRhythm`, `BudgetBracket`, `DietTag`) und die
// `ProfileStore`-Setter bleiben unangetastet — gespeicherte Antworten
// bestehender Nutzer gelten weiter, und gefragt wird künftig kontextuell in
// der App, wo die Antwort etwas bewirkt (eigenes Arbeitspaket).

#Preview("Willkommen") {
    WelcomeStepView(onContinue: {})
}
