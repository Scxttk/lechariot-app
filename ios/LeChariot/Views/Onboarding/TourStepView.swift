import SwiftUI

/// Letzter Onboarding-Bildschirm: das Angebot, einmal durch die App geführt zu
/// werden.
///
/// Angeboten statt aufgezwungen. Wer die App kennt, tippt „Später“ und ist
/// sofort in der Liste; der Rundgang bleibt in den Einstellungen erreichbar.
struct TourStepView: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    /// Wie viele **Handgriffe** der Rundgang hat — gezählt, nicht behauptet.
    ///
    /// „Vier Handgriffe" stand hier als Konstante, während der Rundgang auf
    /// acht bis neun Rahmen gewachsen war; niemand hat es gemerkt, weil nichts
    /// die Zahl mit dem Rundgang verband. Gezählt wird die Fassung ohne
    /// Filialen — der Normalfall an dieser Stelle, direkt nach dem Onboarding.
    ///
    /// **Seit dem 09.08. stimmt das Wort auch wörtlich:** Jeder Rahmen bis auf
    /// die Schlusskarte ist ein Handgriff des Nutzers, und die Schlusskarte
    /// zählt hier nicht mit — sie ist der Abschied, keine Aufgabe.
    static var frameCount: Int { deeds.count }

    private static var deeds: [TutorialStep] {
        TutorialStep.tour(hasMarkets: false).filter { $0.deed != .reads }
    }

    /// Das Zahlwort zur Rahmenzahl. Eine Ziffer wäre die Notlösung, die der
    /// Test meldet — „4 Handgriffe" liest sich wie eine Fehlermeldung.
    static func zahlwort(_ n: Int) -> String {
        let worte = [2: "Zwei", 3: "Drei", 4: "Vier", 5: "Fünf", 6: "Sechs"]
        return worte[n] ?? "\(n)"
    }

    static var subtitle: String {
        "\(zahlwort(frameCount)) Handgriffe, keine Minute — danach weißt du, wo alles liegt."
    }

    /// Die Aufzählung ist der Rundgang in Kurzform — ein Punkt je Handgriff, in
    /// derselben Reihenfolge.
    ///
    /// **Abgeleitet statt abgeschrieben** (09.08.). Hier standen vier Zeilen von
    /// Hand, und drei davon stimmten nicht mehr: „Ablesen, welcher Markt am
    /// günstigsten ist" war ein Rahmen, den es seit heute nicht mehr gibt,
    /// „Filialen wählen und ändern" war seit dem 06.08. keiner mehr. Der
    /// Kommentar darüber berief sich auf einen Test, den es nie gab. Jetzt
    /// kommen die Punkte aus demselben Rundgang, den der Knopf startet — eine
    /// Liste, die nicht abdriften **kann**, ist besser als eine, die ein
    /// Wächter einfängt.
    static var points: [(symbol: String, text: String)] {
        deeds.compactMap { step in
            switch step.deed {
            case .addsItem: ("square.and.pencil", "Einen Artikel aufschreiben")
            case .checksItem: ("checkmark.circle", "Im Laden abhaken")
            case .opensOffersTab: ("tag", "Die Angebote deiner Filialen ansehen")
            case .opensNextWeek: ("calendar", "In die nächste Woche schauen")
            // Kommt nicht vor — `deeds` filtert die Schlusskarte weg. Lieber
            // eine Zeile weniger als eine leere.
            case .reads: nil
            }
        }
    }

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
