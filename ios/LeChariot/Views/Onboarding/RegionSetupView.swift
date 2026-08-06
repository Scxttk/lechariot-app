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

    @Environment(PlaceNameStore.self) private var placeNames

    @State private var locator = PLZLocator()
    /// Vorschläge beim Tippen — siehe `AddressCompleter`.
    @State private var completer = AddressCompleter()
    /// Was im Feld steht — **PLZ oder Ortsname**. Welches von beidem,
    /// entscheidet `RegionQuery`, nicht diese Ansicht.
    @State private var manualPLZ = ""
    /// Der Ort, den Apple aus dem Namen gemacht hat. Steht so lange da, bis
    /// jemand weitertippt — dieselbe Regel wie bei `locatedPLZ`: Eine
    /// Ableitung gilt nur zu der Eingabe, aus der sie stammt.
    @State private var resolvedPlace: PlaceCandidate?
    /// „Meintest du …" — mehrere Orte desselben Namens.
    @State private var candidates: [PlaceCandidate] = []
    @State private var isSearching = false
    /// Die zuletzt **erkannte** PLZ — nur damit die Zeile darunter sagen kann,
    /// woher die Zahl im Feld stammt. Wer sie überschreibt, bekommt die Zeile
    /// nicht mehr zu sehen: Dann ist es wieder seine eigene Eingabe.
    @State private var locatedPLZ: String?
    /// Wie der erkannte Punkt **heißt** — „Anklam, Friedländer Straße" statt
    /// „17389". Scotts Fund vom 02.08.: Die Zahl ist unser Suchschlüssel,
    /// nicht die Antwort auf „wo bin ich". Nil, solange Apple nichts gesagt
    /// hat; dann steht dort weiter die PLZ.
    @State private var locatedPlaceName: String?
    @State private var isLocating = false
    @State private var isChecking = false
    @State private var errorMessage: String?

    private var isBusy: Bool { isLocating || isChecking || isSearching }
    private var query: RegionQuery { RegionQuery.classify(manualPLZ) }

    /// **Der Name ist noch keine Region.** Solange nur ein Ortsname dasteht,
    /// führt der Knopf zu Apple, nicht in die App — erst der bestätigte Ort
    /// hat die PLZ, mit der intern weitergerechnet wird.
    private var needsLookup: Bool {
        if case .ortsname = query { return resolvedPlace == nil }
        return false
    }

    private var canSubmit: Bool {
        guard !isBusy else { return false }
        if case .postleitzahl = query { return true }
        return resolvedPlace != nil
    }

    private var isPrimaryEnabled: Bool { canSubmit || (needsLookup && !isBusy) }

    private var primaryTitle: String {
        if isChecking { return "Wird geprüft …" }
        if isSearching { return "Ort wird gesucht …" }
        return needsLookup ? "Ort suchen" : "Weiter"
    }

    private func primaryAction() {
        if needsLookup { lookUpCity() } else { submit(submittablePLZ) }
    }

    private var submittablePLZ: String {
        if case .postleitzahl(let plz) = query { return plz }
        return resolvedPlace?.plz ?? ""
    }

    var body: some View {
        if let step {
            OnboardingStepView(
                step: step,
                totalSteps: OnboardingStep.total,
                title: "Wo kaufst du ein?",
                subtitle: "Angebote sind regional. Mit deinem Ort oder deiner Postleitzahl finden wir die Märkte in deiner Nähe.",
                primaryTitle: primaryTitle,
                isPrimaryEnabled: isPrimaryEnabled,
                onPrimary: { primaryAction() }
            ) {
                fields
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    fields
                    Button(primaryTitle) { primaryAction() }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Theme.onAccent)
                        .tint(Theme.accent)
                        .disabled(!isPrimaryEnabled)
                        .frame(maxWidth: .infinity)
                }
                .padding(Theme.Spacing.xl)
                .readableWidth()
            }
            // Dasselbe wie in `OnboardingStepView` und `themedScreen()`: Das
            // Zahlenfeld darüber holt die Tastatur, und ohne
            // `.ignoresSafeArea()` endet der Hintergrund an ihrer Kante statt
            // unter ihr weiterzulaufen.
            .background { Theme.background.ignoresSafeArea() }
            .navigationTitle("Region hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// **Die Vorschläge, die beim Tippen mitlaufen.**
    ///
    /// Antippen heißt: Der Text steht im Feld, und der Ort ist bestätigt —
    /// derselbe Weg wie „Weiter", nur ohne den Umweg über das Tippen zu Ende.
    /// Der Abgleich läuft trotzdem durch `CityLookup`; ein Vorschlag ist ein
    /// Vorschlag, keine Postleitzahl.
    @ViewBuilder
    private var addressSuggestions: some View {
        if !completer.suggestions.isEmpty, resolvedPlace == nil {
            VStack(spacing: 0) {
                ForEach(Array(completer.suggestions.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider() }
                    Button {
                        manualPLZ = item.query
                        completer.clear()
                        lookUpCity()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "mappin.circle")
                                .foregroundStyle(Theme.accent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.primary)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(Theme.Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityIdentifier("region.suggestion")
                }
            }
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.stroke)
            )
            .accessibilityIdentifier("region.suggestions")
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // **Die volle Tastatur, nicht mehr der Ziffernblock** — und das
            // kostet den PLZ-Weg einen Tipp auf „123". Bewusst so: Ein Feld,
            // das Buchstaben annehmen soll, kann keine Tastatur ohne
            // Buchstaben anbieten, und zwei Felder (oder ein Umschalter)
            // kosten jeden Menschen einen Tipp statt nur den, der Ziffern
            // tippt. `.default` statt `.numbersAndPunctuation`, weil letztere
            // keine Umlaute kennt — „München" wäre nicht tippbar.
            TextField("Ort oder PLZ, z. B. Anklam", text: $manualPLZ)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(needsLookup ? .search : .done)
                .onSubmit { if isPrimaryEnabled { primaryAction() } }
                .font(.title3)
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
                .accessibilityLabel("Ort oder Postleitzahl")
                .accessibilityIdentifier("region.input")
                .onChange(of: manualPLZ) {
                    // Ein bestätigter Ort gilt nur zu der Eingabe, aus der er
                    // stammt. Wer weitertippt, hat ihn widerrufen.
                    resolvedPlace = nil
                    candidates = []
                    errorMessage = nil
                    // **Eine PLZ braucht keine Vorschläge.** Fünf Ziffern sind
                    // die Antwort selbst; Apple schlüge dazu Straßen vor, die
                    // niemand gefragt hat.
                    switch query {
                    case .postleitzahl, .zuKurz: completer.clear()
                    case .ortsname: completer.update(query: manualPLZ)
                    }
                }

            addressSuggestions

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
                    "Aus deinem Standort: \(locatedPlaceName ?? locatedPLZ). Stimmt das nicht, überschreib es.",
                    systemImage: "location.circle"
                )
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("region.locatedHint")
            }

            // **Was Apple aus dem Namen gemacht hat, steht da, bevor es
            // gespeichert wird.** Dieselbe Absicherung wie bei der Ortung, und
            // aus demselben Grund: Auf „Neustadt" antwortet der Geocoder mit
            // Wolgast. Eine Ableitung, die niemand zu sehen bekommt, kann
            // niemand korrigieren.
            if let resolvedPlace {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Verstanden als \(resolvedPlace.label)", systemImage: "mappin.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("region.resolvedPlace")

                    Button("Anderer Ort …") { showAlternatives() }
                        .font(.footnote.weight(.medium))
                        .tint(Theme.accent)
                        .disabled(isBusy)
                        .accessibilityIdentifier("region.otherPlace")
                }
            }

            // „Meintest du …" — die Liste gibt es nur, weil der Länder-Fächer
            // sie erzeugt; Apple selbst nennt immer genau einen Ort.
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Meintest du …")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("region.candidatesTitle")

                    ForEach(candidates) { candidate in
                        Button {
                            choose(candidate)
                        } label: {
                            HStack {
                                Text(candidate.label)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: Theme.Spacing.sm)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Spacing.md)
                            .background(
                                Theme.surface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("region.candidate.\(candidate.plz)")
                    }
                }
            }

            // A half-typed code left the user with two dead controls and no
            // idea why. Der Satz gilt weiter nur für Ziffern — bei „Ank" wäre
            // er falsch: Ein Ortsname hat keine fünf Ziffern und soll auch
            // keine haben.
            if case .zuKurz = query, !manualPLZ.isEmpty,
               manualPLZ.contains(where: { $0.isNumber }), !manualPLZ.contains(where: { $0.isLetter }) {
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
                let place = try await locator.currentPlace()
                manualPLZ = place.plz
                locatedPLZ = place.plz
                // Der Name nur, wenn er mehr sagt als die Zahl — sonst stünde
                // dort „Aus deinem Standort: 17389", also das Alte in neu.
                locatedPlaceName = place.name == place.plz ? nil : place.name
                isLocating = false
                // Kein `submit`. „Weiter" drückt der Mensch.
            } catch {
                isLocating = false
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Standort nicht verfügbar – bitte gib deine PLZ manuell ein."
            }
        }
    }

    /// **Der Name geht an Apple, die PLZ bleibt bei uns.**
    ///
    /// Scotts Wunsch vom 02.08.: „Anklam" tippen dürfen. Intern ändert sich
    /// nichts — gespeichert wird weiter die PLZ, gesucht wird weiter mit ihr.
    private func lookUpCity() {
        guard case .ortsname(let name) = query else { return }
        errorMessage = nil
        candidates = []
        isSearching = true
        Task {
            let result = await CityLookup.look(up: name)
            isSearching = false
            switch result {
            case .verstanden(let place):
                resolvedPlace = place
            case .meintestDu(let list):
                candidates = list
            case .unbekannt:
                errorMessage = "„\(name)\u{201C} kennt Apple nicht als Ort. Prüf die Schreibweise oder gib die Postleitzahl ein."
            }
        }
    }

    /// Der Länder-Fächer auf Zuruf — für den Fall, dass die erste Antwort zwar
    /// so hieß wie gefragt, aber der falsche Ort dieses Namens war.
    private func showAlternatives() {
        guard case .ortsname(let name) = query else { return }
        errorMessage = nil
        isSearching = true
        Task {
            let found = await CityLookup.alternatives(for: name)
            isSearching = false
            if found.isEmpty {
                errorMessage = "Mehr Orte namens „\(name)\u{201C} findet Apple nicht."
            } else {
                candidates = found
                resolvedPlace = nil
            }
        }
    }

    private func choose(_ candidate: PlaceCandidate) {
        resolvedPlace = candidate
        candidates = []
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
        // Den Namen, den Apple gerade genannt hat, gleich behalten — sonst
        // fragt `PlaceNameStore.resolve` denselben Geocoder ein zweites Mal
        // nach etwas, das wir schon wissen.
        if let resolvedPlace, resolvedPlace.plz == plz {
            placeNames.remember(name: resolvedPlace.ort, forPLZ: plz)
        }
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
        .environment(PlaceNameStore())
}

#Preview("Aus den Einstellungen") {
    NavigationStack {
        RegionSetupView(onPLZSubmitted: { _ in })
            .environment(RegionStore())
            .environment(PlaceNameStore())
    }
}
