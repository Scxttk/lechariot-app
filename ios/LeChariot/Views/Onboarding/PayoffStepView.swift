import SwiftUI

/// Die Sätze des Belohnungsschritts, als reine Funktionen — damit die
/// Singular-Fälle („1 Kette") getestet sind statt behauptet.
enum PayoffCopy {
    static func headline(chains: Int, branches: Int) -> String {
        let ketten = chains == 1 ? "1 Kette" : "\(chains) Ketten"
        let filialen = branches == 1 ? "1 Filiale" : "\(branches) Filialen"
        return "\(ketten), \(filialen) in deiner Nähe."
    }

    static func likedLine(count: Int) -> String {
        count == 1
            ? "1 Kette hast du dir gemerkt."
            : "\(count) Ketten hast du dir gemerkt."
    }
}

/// Der Belohnungsschritt: direkt nach Ort und Ketten zeigt die App, was die
/// Antworten gebracht haben — mit echten Zahlen aus dem Verzeichnis.
///
/// Die Forschungsnotiz dahinter: Fragen, deren Antwort sichtbar nichts
/// ändert, kosten nur (Blinkist-Lehre). Dieser Bildschirm ist die sichtbare
/// Wirkung des Orts-Schritts.
///
/// **Er rechnet nur, er lädt nicht.** Die Zahlen kommen aus der Abfrage, die
/// der Ketten-Schritt schon gemacht hat; ohne sie (offline, Zeitüberschreitung)
/// steht hier ein ehrlicher Satz statt eines Kreisels. Angebotszahlen je
/// Gegend („34 Angebote diese Woche") gibt es an dieser Stelle noch nicht —
/// die Angebote hängen an Filialen, und Filialen sind noch keine gewählt.
struct PayoffStepView: View {
    var plz: String?
    var nearby: NearbyMarkets?
    /// Wie viele Ketten gerade gemerkt sind — Wirkung des Schritts davor.
    var likedCount: Int
    var onContinue: () -> Void

    var body: some View {
        OnboardingStepView(
            step: 5,
            totalSteps: OnboardingStep.total,
            title: title,
            subtitle: subtitle,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let nearby {
                    row("storefront", "Deren Wochenangebote vergleicht Le Chariot für deine Liste.")
                    if likedCount > 0 {
                        row("heart.fill", PayoffCopy.likedLine(count: likedCount))
                    }
                    row("checkmark.circle", "Deine Filialen wählst du gleich in der Liste — erst siehst du, wofür.")
                    // Der stille Zeuge für die UI-Journeys: die Filialzahl als
                    // eigenes Element, unabhängig vom Satzbau des Titels.
                    Text("Rund um \(plz ?? "deine PLZ") · \(nearby.branchCount) Filialen im Verzeichnis")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .accessibilityIdentifier("payoff.facts")
                } else {
                    row("wifi.slash", "Gerade keine Verbindung — die Märkte deiner Gegend holt die App, sobald sie online ist.")
                    row("checkmark.circle", "Deine Einkaufsliste funktioniert auch so, sofort.")
                }
            }
        }
    }

    private var title: String {
        guard let nearby else { return "Deine Gegend ist eingerichtet." }
        return PayoffCopy.headline(chains: nearby.chains.count, branches: nearby.branchCount)
    }

    private var subtitle: String {
        guard nearby != nil else {
            return "Deine Postleitzahl \(plz.map { "(\($0)) " } ?? "")ist gespeichert — mehr braucht es fürs Erste nicht."
        }
        return "Dafür war der Ort gut: Das sind die Märkte, die für dich zählen können."
    }

    private func row(_ symbol: String, _ text: String) -> some View {
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
        .accessibilityElement(children: .combine)
    }
}

#Preview("Mit Zahlen") {
    PayoffStepView(
        plz: "01219",
        nearby: NearbyMarkets(chains: ["Aldi", "Lidl", "Netto", "REWE"], branchCount: 34),
        likedCount: 2,
        onContinue: {}
    )
}

#Preview("Offline") {
    PayoffStepView(plz: "01219", nearby: nil, likedCount: 0, onContinue: {})
}
