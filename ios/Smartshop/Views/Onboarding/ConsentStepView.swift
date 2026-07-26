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
            step: 6,
            totalSteps: OnboardingStep.total,
            title: "Darf Smartshop mitlernen?",
            subtitle: "Smartshop ist noch jung. Deine Angaben helfen dabei, die App für echte Einkäufe besser zu machen.",
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

                detail(
                    "checkmark.circle",
                    Theme.success,
                    "Übermittelt werden",
                    "Haushaltsgröße, wie oft du einkaufst, dein Budget-Rahmen, deine Ernährungsangaben, deine Postleitzahl und die Filialen, die du wählst."
                )
                detail(
                    "iphone",
                    Theme.accent,
                    "Bleibt auf dem Gerät",
                    "Dein Vorname und deine Einkaufsliste."
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
