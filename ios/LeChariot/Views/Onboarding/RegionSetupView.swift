import SwiftUI

/// Region step: pick a region via location (optional) or manual PLZ.
///
/// Used twice: as step 3 of onboarding (`step` set, wrapped in the shared
/// onboarding frame) and as a pushed screen from Settings (`step` nil, plain
/// layout — progress dots would be nonsense there).
struct RegionSetupView: View {
    @Environment(RegionStore.self) private var store
    /// Position in the onboarding flow; nil when opened from Settings.
    var step: Int?
    /// Called once the region check/registration has been kicked off.
    var onPLZSubmitted: (String) -> Void

    @State private var locator = PLZLocator()
    @State private var manualPLZ = ""
    /// Die zuletzt **erkannte** PLZ — nur damit die Zeile darunter sagen kann,
    /// woher die Zahl im Feld stammt. Wer sie überschreibt, bekommt die Zeile
    /// nicht mehr zu sehen: Dann ist es wieder seine eigene Eingabe.
    @State private var locatedPLZ: String?
    @State private var isLocating = false
    @State private var isChecking = false
    @State private var errorMessage: String?

    private var isBusy: Bool { isLocating || isChecking }
    private var canSubmit: Bool { PLZValidator.isValid(manualPLZ) && !isBusy }

    var body: some View {
        if let step {
            OnboardingStepView(
                step: step,
                totalSteps: OnboardingStep.total,
                title: "Wo kaufst du ein?",
                subtitle: "Angebote sind regional. Mit deiner Postleitzahl finden wir die Märkte in deiner Nähe.",
                primaryTitle: isChecking ? "Wird geprüft …" : "Weiter",
                isPrimaryEnabled: canSubmit,
                onPrimary: { submit(manualPLZ) }
            ) {
                fields
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    fields
                    Button("Weiter") { submit(manualPLZ) }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Theme.onAccent)
                        .tint(Theme.accent)
                        .disabled(!canSubmit)
                        .frame(maxWidth: .infinity)
                }
                .padding(Theme.Spacing.xl)
                .readableWidth()
            }
            .background(Theme.background)
            .navigationTitle("Region hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            TextField("PLZ, z. B. 01219", text: $manualPLZ)
                .keyboardType(.numberPad)
                .textContentType(.postalCode)
                .font(.title3.monospacedDigit())
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 52)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.stroke)
                )
                .accessibilityLabel("Postleitzahl")

            Button {
                useLocation()
            } label: {
                Label(
                    isLocating ? "Standort wird ermittelt …" : "Standort verwenden",
                    systemImage: "location.fill"
                )
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(isBusy)

            // Sagt, dass die Zahl im Feld **abgeleitet** ist, und stellt sie
            // damit zur Korrektur. Verschwindet, sobald jemand etwas anderes
            // tippt — dann ist es keine Ableitung mehr.
            if let locatedPLZ, locatedPLZ == manualPLZ {
                Label(
                    "Aus deinem Standort: \(locatedPLZ). Stimmt das nicht, überschreib es.",
                    systemImage: "location.circle"
                )
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("region.locatedHint")
            }

            // The number pad has no return key and "Weiter" is simply grey until
            // the PLZ is complete, so a half-typed code left the user with two
            // dead controls and no idea why.
            if !manualPLZ.isEmpty && !PLZValidator.isValid(manualPLZ) {
                Text("Eine Postleitzahl hat fünf Ziffern.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Actions

    /// **Die erkannte PLZ wird gezeigt, nicht verwendet.**
    ///
    /// Bis zum 2026-07-31 füllte diese Funktion das Feld und schaltete im
    /// selben Atemzug weiter — die Postleitzahl stand null Bilder lang auf dem
    /// Schirm. Gemeldet von Scott am Gerät („springt sofort weiter"), und es
    /// ist mehr als Kosmetik:
    ///
    /// Genau hier hätte sein Bruder am 30.07. gesehen, dass für Ahlbeck
    /// **17373** erkannt wurde statt 17419 — die PLZ des 24,5 km entfernten
    /// Ueckermünde. Stattdessen lief alles grün durch: eine gestempelte
    /// Anforderung, dreizehn Filialen, drei fehlende Ketten und niemand, der
    /// sagen konnte warum. **Eine Ableitung, die der Nutzer nie zu sehen
    /// bekommt, kann er auch nicht korrigieren** — und das Feld, das sie zeigt,
    /// ist die billigste denkbare Absicherung gegen die ganze Klasse.
    private func useLocation() {
        errorMessage = nil
        isLocating = true
        Task {
            do {
                let plz = try await locator.currentPLZ()
                manualPLZ = plz
                locatedPLZ = plz
                isLocating = false
                // Kein `submit`. „Weiter" drückt der Mensch.
            } catch {
                isLocating = false
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Standort nicht verfügbar – bitte gib deine PLZ manuell ein."
            }
        }
    }

    private func submit(_ rawPLZ: String) {
        guard let plz = PLZValidator.normalized(rawPLZ) else { return }
        // `addRegion` quietly does nothing once the limit is reached. Without
        // this the flow would report success and move on with a region that was
        // never stored.
        guard store.canAddRegion || store.regions.contains(plz) else {
            errorMessage = "Mehr als \(RegionStore.maxRegions) Regionen gehen nicht. Entferne in den Einstellungen eine, die du nicht mehr brauchst."
            return
        }
        errorMessage = nil
        isChecking = true
        Task {
            await store.addRegion(plz)
            isChecking = false
            onPLZSubmitted(plz)
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

#Preview("Onboarding") {
    RegionSetupView(step: 3, onPLZSubmitted: { _ in })
        .environment(RegionStore())
}

#Preview("Aus den Einstellungen") {
    NavigationStack {
        RegionSetupView(onPLZSubmitted: { _ in })
            .environment(RegionStore())
    }
}
