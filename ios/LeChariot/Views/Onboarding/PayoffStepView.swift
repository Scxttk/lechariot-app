import SwiftUI

/// Die Sätze des Belohnungsschritts, als reine Funktionen — damit die
/// Singular-Fälle („1 Kette") getestet sind statt behauptet.
enum PayoffCopy {
    /// **Was VoiceOver aus den zwei großen Zahlen liest.**
    ///
    /// Bis zum 10.08. war das die Überschrift des Schritts. Seitdem stehen die
    /// Zahlen groß und einzeln da (Punkt 4 der Bedienrunde) — vorgelesen
    /// gehören sie trotzdem als ein Satz, sonst hört jemand „9", „Ketten",
    /// „34", „Filialen" in vier Anläufen.
    static func headline(chains: Int, branches: Int) -> String {
        let ketten = chains == 1 ? "1 Kette" : "\(chains) Ketten"
        let filialen = branches == 1 ? "1 Filiale" : "\(branches) Filialen"
        return "\(ketten), \(filialen) in deiner Nähe."
    }

    /// Das Wort neben der großen Zahl — ohne die Zahl selbst.
    static func chainUnit(_ count: Int) -> String { count == 1 ? "Kette" : "Ketten" }
    static func branchUnit(_ count: Int) -> String { count == 1 ? "Filiale" : "Filialen" }

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

    /// Wächst mit der Systemschrift mit — eine feste Punktzahl wäre bei großer
    /// Schrift die einzige Stelle des Bildschirms, die nicht mitwächst.
    @ScaledMetric(relativeTo: .largeTitle) private var zahlenGröße = Theme.Typography.heroNumber

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
                    zahlen(nearby)
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

    /// **Die zwei Zahlen, groß.**
    ///
    /// Sie standen bis zum 10.08. als Überschrift im Fließtext („4 Ketten, 5
    /// Filialen in deiner Nähe."), und genau das war Scotts Befund: Die
    /// eindrucksvollste Auskunft des Assistenten sah aus wie jeder andere Satz.
    /// Jetzt trägt die Zahl das Gewicht und das Wort steht daneben.
    ///
    /// **Nebeneinander, solange es passt.** Bei großer Systemschrift werden aus
    /// zwei Spalten zwei Zeilen — `ViewThatFits` entscheidet das an der
    /// gemessenen Breite, nicht an einer Schriftgrößen-Abfrage.
    private func zahlen(_ nearby: NearbyMarkets) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xl) {
                zahl(nearby.chains.count, PayoffCopy.chainUnit(nearby.chains.count))
                zahl(nearby.branchCount, PayoffCopy.branchUnit(nearby.branchCount))
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                zahl(nearby.chains.count, PayoffCopy.chainUnit(nearby.chains.count))
                zahl(nearby.branchCount, PayoffCopy.branchUnit(nearby.branchCount))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PayoffCopy.headline(chains: nearby.chains.count,
                                                branches: nearby.branchCount))
        .accessibilityIdentifier("payoff.numbers")
    }

    private func zahl(_ value: Int, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text("\(value)")
                .font(.system(size: zahlenGröße, weight: .bold, design: .rounded))
                // Ohne das springt die Zahl beim Wechsel von 9 auf 10 in der
                // Breite; abgerundete Ziffern sind ohnehin für Tabellen gemacht.
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                // Eine 152 darf nicht umbrechen, und drei Stellen passen auch
                // bei großer Schrift noch in eine Zeile, wenn sie darf.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: String {
        guard nearby != nil else { return "Deine Gegend ist eingerichtet." }
        return "In deiner Nähe."
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
