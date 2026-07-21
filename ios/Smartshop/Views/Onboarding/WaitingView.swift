import SwiftUI

/// Shown while a freshly requested region is being scraped by the backend
/// (states `requested` / `syncing`), plus the failure state with retry.
struct WaitingView: View {
    @Environment(RegionStore.self) private var store
    let plz: String
    /// Lets the user go back and pick a different PLZ.
    var onChangeRegion: () -> Void

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            switch store.syncState(for: plz) {
            case .failed(.timedOut):
                timeoutContent
            case .failed(.network):
                networkErrorContent
            default:
                progressContent
            }

            Spacer()

            Button("Andere PLZ wählen") { onChangeRegion() }
                .font(.subheadline)
        }
        .padding(24)
        .readableWidth()
        .frame(maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Region \(plz)")
        // Progress polling lives exactly as long as this view is on screen;
        // observeProgress returns by itself once the region is ready or failed.
        .task(id: plz) { await store.observeProgress(plz: plz) }
    }

    private var progressContent: some View {
        let progress = store.progress(for: plz)
        return VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Fast fertig")
                .font(.title2).bold()
            Text("Wir sammeln gerade die Angebote für \(plz).\nDas dauert meist nur wenige Minuten.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !progress.markets.isEmpty {
                foundMarketsList(progress.markets)
            }
            if progress.offerCount > 0 {
                Text("\(progress.offerCount.formatted()) Angebote geladen")
                    .font(.subheadline.weight(.medium))
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(progress.offerCount) Angebote bereits geladen")
            }

            Text("Du kannst die App schließen – die Vorbereitung läuft auf unseren Servern weiter. Schau in ein paar Minuten wieder rein.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .animation(.default, value: progress)
    }

    /// The markets found so far — they appear one by one while the server sync
    /// works through the chains, which is the only honest progress signal we
    /// have (no total is known).
    private func foundMarketsList(_ markets: [Market]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(markets, id: \.marketId) { market in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                    Text("\(market.chain) \(market.branchName)")
                        .lineLimit(1)
                }
                .font(.subheadline)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(market.chain) \(market.branchName) gefunden")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gefundene Märkte")
    }

    private var timeoutContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("Das dauert etwas länger")
                .font(.title2).bold()
            Text("Deine Region \(plz) ist vorgemerkt. Die Angebote kommen spätestens über Nacht – schau einfach morgen wieder vorbei.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            retryButton
        }
    }

    private var networkErrorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(Theme.warning)
            Text("Verbindung fehlgeschlagen")
                .font(.title2).bold()
            Text("Der Status deiner Region konnte nicht abgefragt werden. Bitte prüfe deine Internetverbindung.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            retryButton
        }
    }

    /// The retry itself is a network round trip that can take seconds and, if it
    /// fails again, leaves the screen looking exactly as before. Without the
    /// busy state the button swallowed taps silently and invited hammering.
    private var retryButton: some View {
        Button {
            guard !isRetrying else { return }
            isRetrying = true
            Task {
                await store.retry(plz)
                isRetrying = false
            }
        } label: {
            Label(
                isRetrying ? "Wird geprüft …" : "Erneut versuchen",
                systemImage: "arrow.clockwise"
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(Theme.onAccent)
        .disabled(isRetrying)
    }
}

#Preview {
    NavigationStack {
        WaitingView(plz: "01219", onChangeRegion: {})
            .environment(RegionStore(repository: MockRegionRepository()))
    }
}
