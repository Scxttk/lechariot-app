import SwiftUI

/// Die Markt-Frage nach dem Onboarding — als gestaltetes Sheet statt als
/// System-Alert.
///
/// **Der wichtigste Moment hatte die schlechteste UI.** Die Filialauswahl ist
/// seit dem 2026-07-31 bewusst aus dem Onboarding heraus; gefragt wurde danach
/// mit einem nackten `alert` — zwei Systemknöpfe für die Entscheidung, an der
/// hängt, ob die App je etwas vergleichen kann. Und wer den Rundgang
/// übersprang, sah die Frage gar nicht. Jetzt steht hier ein Sheet im Ton der
/// App: kurzer Grund, ein grüner Weg hinein, ein ehrliches „Später".
///
/// **Nie blockierend.** Wegwischen ist eine Antwort, „Später" ist eine
/// Antwort, und jede Antwort zählt als gegeben — das Sheet kommt genau einmal
/// (`MarketPromptStore.hasAnsweredMarketPrompt`). Danach bleiben der Leerzustand
/// der Liste und die Einstellungen als dauerhafte Wege.
///
/// Die Filialauswahl selbst liegt als Navigationsziel **im** Sheet: Erst das
/// eine Sheet schließen und dann das nächste öffnen wäre genau der
/// Zwei-Sheets-Tanz, der in SwiftUI regelmäßig den zweiten verliert.
struct MarketPromptSheet: View {
    let plz: String
    let marketRepository: MarketRepositoryProtocol
    /// Die Filialauswahl wurde mit „Fertig" verlassen — Sheet schließen.
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsPicker = false
    /// Die Frage steht auf halber Höhe, die Filialauswahl braucht die ganze.
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            prompt
                .navigationDestination(isPresented: $showsPicker) {
                    MarketPickerView(
                        plz: plz,
                        marketRepository: marketRepository,
                        onDone: onDone
                    )
                }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onChange(of: showsPicker) { _, shown in
            if shown { detent = .large }
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Image(systemName: "storefront")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)

                    Text("Wo kaufst du ein?")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("marketPrompt.title")

                    Text("Le Chariot vergleicht die Wochenangebote der Läden, in die du wirklich gehst. Mit ein, zwei Filialen sagt dir die Karte über der Liste, wo dein Einkauf am günstigsten ist — und im Angebote-Tab liegt alles, was diese Woche billiger ist.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.xl)
                .readableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .background { Theme.background.ignoresSafeArea() }
    }

    /// Dieselbe Knopf-Ordnung wie in den Onboarding-Schritten: der grüne
    /// Primärweg voll breit, darunter der leise Ausweg.
    private var footer: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                showsPicker = true
            } label: {
                Text("Märkte wählen")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Theme.onAccent)
            .tint(Theme.accent)
            .accessibilityIdentifier("marketPrompt.choose")

            Button("Später") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .frame(minHeight: 44)
                .accessibilityIdentifier("marketPrompt.later")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.md)
        .readableWidth()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        MarketPromptSheet(
            plz: "01219",
            marketRepository: MockMarketRepository(),
            onDone: {}
        )
    }
}
