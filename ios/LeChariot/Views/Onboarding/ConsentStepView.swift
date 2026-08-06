import SwiftUI

/// Asks whether the answers may be sent to the backend.
///
/// **Zwei Knöpfe, kein Schalter — seit dem 06.08.** Scotts Befund: „Darf Le
/// Chariot mitlernen?" mit einem Schalter und einem „Fertig" darunter liest
/// sich wie jede andere App, die alle Daten will, „und deswegen klickt man bei
/// der Seite einfach weiter."
///
/// Er hat recht, und der Schalter ist der Grund. Ein Schalter plus „Fertig"
/// heißt: Die eigentliche Entscheidung steckt in einem Bedienelement, das man
/// überspringen kann, und „Fertig" tut dann irgendetwas — nämlich das, was der
/// Schalter zufällig gerade sagt. **Wer durchklickt, hat nicht Nein gesagt, er
/// hat gar nichts gesagt.**
///
/// Jetzt stehen beide Antworten als Knopf da und heißen beide, was sie tun:
/// „Angaben übermitteln" und „Keine Angaben übermitteln". Kein Weg führt an der
/// Frage vorbei, und keine der zwei Antworten ist verkleidet. Die Frage selbst
/// sagt nicht mehr „darf ich", sondern was zur Wahl steht.
///
/// Die Voreinstellung bleibt, was sie war: Ohne Antwort wird nichts übermittelt.
struct ConsentStepView: View {
    @Environment(ProfileStore.self) private var profile
    var onContinue: () -> Void

    private func answer(_ consent: Bool) {
        profile.setConsent(consent)
        onContinue()
    }

    var body: some View {
        OnboardingStepView(
            step: 6,
            totalSteps: OnboardingStep.total,
            title: "Anonyme Angaben — oder nicht?",
            subtitle: "\(AppBrand.name) ist noch jung. Deine Angaben helfen dabei, die App für echte Einkäufe besser zu machen. Beides ist in Ordnung, und die App funktioniert gleich.",
            primaryTitle: "Angaben übermitteln",
            onPrimary: { answer(true) },
            skip: (title: "Keine Angaben übermitteln", action: { answer(false) })
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
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

                Text("Du kannst es in den Einstellungen jederzeit ändern.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
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
