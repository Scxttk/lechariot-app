import SwiftUI

/// Asks whether the answers may be sent to the backend. Opt-in, off by default,
/// and "Weiter" works either way — declining costs the user nothing, so the
/// question can be asked honestly instead of nagged.
struct ConsentStepView: View {
    @Environment(ProfileStore.self) private var profile
    var onContinue: () -> Void

    @State private var isOn = false

    var body: some View {
        OnboardingStepView(
            // Schritt 6 von 7 — das Rundgang-Angebot hat seit dem 2026-08-05
            // seinen eigenen Punkt, vorher teilten sich beide den sechsten.
            step: 6,
            totalSteps: OnboardingStep.total,
            title: "Darf Le Chariot mitlernen?",
            subtitle: "Le Chariot ist noch jung. Deine Angaben helfen dabei, die App für echte Einkäufe besser zu machen.",
            primaryTitle: "Fertig",
            onPrimary: {
                profile.setConsent(isOn)
                onContinue()
            }
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Toggle(isOn: $isOn) {
                    Text("Angaben anonym übermitteln")
                        .font(.body.weight(.medium))
                }
                .tint(Theme.accent)
                .padding(Theme.Spacing.lg)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.stroke)
                )

                // Die Liste zählt auf, was wirklich geht — seit die Fragen zu
                // Haushalt und Ernährung nicht mehr im Onboarding stehen,
                // stehen sie hier als das, was sie sind: spätere, freiwillige
                // Angaben in der App.
                detail(
                    "checkmark.circle",
                    Theme.success,
                    "Übermittelt werden",
                    "Deine Postleitzahl, die Filialen, die du wählst — und Angaben wie Ernährung oder Haushaltsgröße, falls die App dich später danach fragt und du antwortest."
                )
                detail(
                    "iphone",
                    Theme.accent,
                    "Bleibt auf dem Gerät",
                    "Dein Vorname, deine Einkaufsliste und welche Märkte du magst."
                )
                detail(
                    "person.fill.questionmark",
                    .secondary,
                    "Kein Konto, kein Name",
                    "Die Daten hängen an einer Zufallsnummer dieser Installation — nicht an dir."
                )

                Text("Sagst du Nein, funktioniert die App genau gleich. Du kannst es in den Einstellungen jederzeit ändern.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .onAppear { isOn = profile.hasConsented }
    }

    private func detail(
        _ symbol: String,
        _ color: Color,
        _ title: String,
        _ text: String
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ConsentStepView(onContinue: {})
        .environment(ProfileStore())
}
