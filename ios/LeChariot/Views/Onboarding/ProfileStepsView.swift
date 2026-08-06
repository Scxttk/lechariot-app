import SwiftUI

/// Welcome screen — the app used to open on a bare PLZ field, which asked for
/// data before saying what it was for.
struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        OnboardingStepView(
            step: 1,
            totalSteps: OnboardingStep.total,
            title: "Ein Einkauf, ein Markt, der beste Preis.",
            subtitle: "Schreib deine Einkaufsliste. \(AppBrand.name) vergleicht die Wochenangebote deiner Filialen und sagt dir, wo du am besten hinfährst.",
            primaryTitle: "Los geht's",
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                bullet("list.bullet", "Deine Liste", "Artikel eintippen, mehr nicht.")
                bullet("storefront", "Deine Filialen", "Du wählst, welche Märkte zählen.")
                bullet("eurosign.circle", "Ein klares Ergebnis", "Welcher Markt deckt die Liste am besten ab.")
            }
        }
    }

    private func bullet(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// First name, only used for the greeting on the list screen. Never leaves the
/// device — see the note in `UserProfile`.
struct NameStepView: View {
    @Environment(ProfileStore.self) private var profile
    var onContinue: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepView(
            step: 2,
            totalSteps: OnboardingStep.total,
            title: "Wie sollen wir dich nennen?",
            subtitle: "Nur für die Begrüßung. Der Name bleibt auf deinem Gerät.",
            onPrimary: {
                profile.setFirstName(name)
                onContinue()
            },
            skip: (title: "Ohne Namen weiter", action: {
                profile.setFirstName("")
                onContinue()
            })
        ) {
            TextField("Vorname", text: $name)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.done)
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
                .accessibilityLabel("Vorname")
        }
        // **Ohne Tastatur ankommen** (Scott, 06.08.). Vorher stand hier
        // `focused = true`, und der Bildschirm empfing mit einer halben
        // Bildschirmhöhe Tastatur — obwohl der häufigste Weg hier „Ohne Namen
        // weiter" ist. Wer den Namen tippen will, tippt auf das Feld; wer nicht,
        // muss nicht erst eine Tastatur wegräumen, die niemand angefordert hat.
        //
        // Dieselbe Regel wie bei der Angaben-Schicht in der Liste (03.08.):
        // kein Zwang zur Tastatur auf einem Weg, der ohne sie auskommt.
        .onAppear { name = profile.profile.firstName }
    }
}

/// Household size, shopping rhythm and budget bracket.
struct HouseholdStepView: View {
    @Environment(ProfileStore.self) private var profile
    var onContinue: () -> Void

    var body: some View {
        @Bindable var profile = profile
        return OnboardingStepView(
            step: 4,
            totalSteps: OnboardingStep.total,
            title: "Wie kaufst du ein?",
            subtitle: "Grobe Angaben reichen — sie helfen uns, \(AppBrand.name) passender zu machen.",
            onPrimary: onContinue,
            skip: (title: "Überspringen", action: onContinue)
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                household
                rhythm
                budget
            }
        }
    }

    private var household: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            label("Für wie viele Personen?")
            HStack {
                Text(profile.profile.householdSize == 1
                     ? "1 Person"
                     : "\(profile.profile.householdSize) Personen")
                    .font(.title3.weight(.medium).monospacedDigit())
                Spacer()
                Stepper(
                    "Personen im Haushalt",
                    value: Binding(
                        get: { profile.profile.householdSize },
                        set: { profile.setHousehold(size: $0) }
                    ),
                    in: 1...10
                )
                .labelsHidden()
            }
            .padding(Theme.Spacing.md)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                    .strokeBorder(Theme.stroke)
            )
        }
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            label("Wie oft pro Woche?")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.sm)],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(ShoppingRhythm.allCases) { option in
                    SelectableChip(
                        title: option.label,
                        isSelected: profile.profile.rhythm == option
                    ) {
                        profile.setRhythm(option)
                    }
                }
            }
        }
    }

    private var budget: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            label("Was gibst du ungefähr pro Woche aus?")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.sm)],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(BudgetBracket.allCases) { bracket in
                    SelectableChip(
                        title: bracket.label,
                        isSelected: profile.profile.budget == bracket
                    ) {
                        // Tapping the active bracket clears it — "keine Angabe"
                        // without needing its own button.
                        profile.setBudget(profile.profile.budget == bracket ? nil : bracket)
                    }
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
    }
}

/// Dietary preferences. All optional, multi-select.
struct DietStepView: View {
    @Environment(ProfileStore.self) private var profile
    var onContinue: () -> Void

    var body: some View {
        OnboardingStepView(
            step: 5,
            totalSteps: OnboardingStep.total,
            title: "Isst du irgendetwas nicht?",
            subtitle: "Such dir aus, was zutrifft — oder nichts. Du kannst das jederzeit ändern.",
            onPrimary: onContinue,
            skip: (title: "Trifft nichts zu", action: onContinue)
        ) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.sm)],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(DietTag.allCases) { tag in
                    SelectableChip(
                        title: tag.label,
                        symbol: tag.symbol,
                        isSelected: profile.profile.dietTags.contains(tag)
                    ) {
                        profile.toggleDietTag(tag)
                    }
                }
            }
        }
    }
}

#Preview("Willkommen") {
    WelcomeStepView(onContinue: {})
}

#Preview("Haushalt") {
    HouseholdStepView(onContinue: {})
        .environment(ProfileStore())
}

#Preview("Ernährung") {
    DietStepView(onContinue: {})
        .environment(ProfileStore())
}
