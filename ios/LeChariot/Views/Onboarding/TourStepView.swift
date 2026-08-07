import SwiftUI

/// Letzter Onboarding-Bildschirm: das Angebot, einmal durch die App geführt zu
/// werden.
///
/// Angeboten statt aufgezwungen. Wer die App kennt, tippt „Später“ und ist
/// sofort in der Liste; der Rundgang bleibt in den Einstellungen erreichbar.
struct TourStepView: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    /// Wie viele Rahmen der Rundgang hat — **gezählt, nicht behauptet.**
    ///
    /// „Vier Handgriffe" stand hier als Konstante, während der Rundgang auf
    /// acht bis neun Rahmen gewachsen war; niemand hat es gemerkt, weil nichts
    /// die Zahl mit dem Rundgang verband. Gezählt wird die Fassung ohne
    /// Filialen — der Normalfall an dieser Stelle, direkt nach dem Onboarding.
    /// Sollten die Fassungen je verschieden lang werden, schlägt der Test an
    /// (`testTheOfferCountsItsFramesInsteadOfGuessing`).
    static var frameCount: Int { TutorialStep.tour(hasMarkets: false).count }

    /// Das Zahlwort zur Rahmenzahl. Eine Ziffer wäre die Notlösung, die der
    /// Test meldet — „4 Handgriffe" liest sich wie eine Fehlermeldung.
    static func zahlwort(_ n: Int) -> String {
        let worte = [2: "Zwei", 3: "Drei", 4: "Vier", 5: "Fünf", 6: "Sechs"]
        return worte[n] ?? "\(n)"
    }

    static var subtitle: String {
        "\(zahlwort(frameCount)) Handgriffe, keine Minute — danach weißt du, wo alles liegt."
    }

    /// Die Aufzählung ist der Rundgang in Kurzform — ein Punkt je Rahmen, in
    /// derselben Reihenfolge. Der Test hält die Zahl der Punkte an der Zahl
    /// der Rahmen fest, damit die Vorschau nicht wieder von der Führung
    /// abdriftet.
    static let points: [(symbol: String, text: String)] = [
        ("square.and.pencil", "Artikel auf die Liste setzen"),
        ("cart", "Ablesen, welcher Markt am günstigsten ist"),
        ("tag", "Sehen, was diese Woche im Angebot ist"),
        ("gearshape", "Filialen wählen und ändern"),
    ]

    var body: some View {
        OnboardingStepView(
            step: OnboardingStep.total,
            totalSteps: OnboardingStep.total,
            title: "Alles bereit. Einmal kurz zeigen?",
            subtitle: Self.subtitle,
            primaryTitle: "Los geht’s",
            onPrimary: onStart,
            skip: (title: "Später", action: onSkip)
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(Self.points, id: \.text) { point in
                    self.point(symbol: point.symbol, text: point.text)
                }
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
