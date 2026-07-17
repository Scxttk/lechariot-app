import SwiftUI

/// First onboarding step: pick a region via location (optional) or manual PLZ.
struct RegionSetupView: View {
    @Environment(RegionStore.self) private var store
    /// Called once the region check/registration has been kicked off.
    var onPLZSubmitted: (String) -> Void

    @State private var locator = PLZLocator()
    @State private var manualPLZ = ""
    @State private var isLocating = false
    @State private var isChecking = false
    @State private var errorMessage: String?

    private var isBusy: Bool { isLocating || isChecking }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)

            Text("Wo kaufst du ein?")
                .font(.title2).bold()
            Text("Smartshop zeigt dir nur Angebote aus deiner Region.\nGib deine Postleitzahl ein oder nutze deinen Standort.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                TextField("PLZ, z. B. 01219", text: $manualPLZ)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button("Weiter") { submit(manualPLZ) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!PLZValidator.isValid(manualPLZ) || isBusy)
            }

            HStack {
                VStack { Divider() }
                Text("oder").font(.caption).foregroundStyle(.secondary)
                VStack { Divider() }
            }

            Button {
                useLocation()
            } label: {
                Label(
                    isLocating ? "Standort wird ermittelt…" : "Standort verwenden",
                    systemImage: "location.fill"
                )
                .frame(maxWidth: .infinity)
                .padding(8)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)

            if isChecking {
                ProgressView("Region wird geprüft…")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
        .navigationTitle("Deine Region")
    }

    private func useLocation() {
        errorMessage = nil
        isLocating = true
        Task {
            do {
                let plz = try await locator.currentPLZ()
                manualPLZ = plz
                isLocating = false
                submit(plz)
            } catch {
                isLocating = false
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Standort nicht verfügbar – bitte gib deine PLZ manuell ein."
            }
        }
    }

    private func submit(_ rawPLZ: String) {
        guard let plz = PLZValidator.normalized(rawPLZ) else { return }
        errorMessage = nil
        isChecking = true
        Task {
            await store.addRegion(plz)
            isChecking = false
            if case .failed(.network) = store.syncState(for: plz) {
                errorMessage = "Die Region konnte nicht geprüft werden. Bitte prüfe deine Internetverbindung und versuche es erneut."
            } else {
                onPLZSubmitted(plz)
            }
        }
    }
}

/// Wraps RegionSetupView so a successful submit pops back to the pushing
/// screen. Used from Settings and the market picker's PLZ-border affordance.
struct AddRegionScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RegionSetupView(onPLZSubmitted: { _ in dismiss() })
    }
}

#Preview {
    NavigationStack {
        RegionSetupView(onPLZSubmitted: { _ in })
            .environment(RegionStore(repository: MockRegionRepository()))
    }
}
