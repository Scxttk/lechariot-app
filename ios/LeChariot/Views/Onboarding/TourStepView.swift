import SwiftUI

/// Letzter Onboarding-Bildschirm: das Angebot, einmal durch die App geführt zu
/// werden.
///
/// Angeboten statt aufgezwungen. Wer die App kennt, tippt „Später“ und ist
/// sofort in der Liste; der Rundgang bleibt in den Einstellungen erreichbar.
struct TourStepView: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingStepView(
            step: OnboardingStep.total,
            totalSteps: OnboardingStep.total,
            title: "Alles bereit. Einmal kurz zeigen?",
            subtitle: "Vier Handgriffe, keine Minute — danach weißt du, wo alles liegt.",
            primaryTitle: "Los geht’s",
            onPrimary: onStart,
            skip: (title: "Später", action: onSkip)
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                point(symbol: "square.and.pencil", text: "Artikel auf die Liste setzen")
                point(symbol: "cart", text: "Ablesen, welcher Markt am günstigsten ist")
                point(symbol: "checkmark.circle", text: "Im Laden abhaken")
                point(symbol: "gearshape", text: "Filialen später ändern")
            }
        }
    }

    private func point(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    TourStepView(onStart: {}, onSkip: {})
}
