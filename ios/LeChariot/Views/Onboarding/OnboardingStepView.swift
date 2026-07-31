import SwiftUI

/// Shared frame for every onboarding step: progress dots, a title, one line of
/// explanation, the step's own content, and the primary action pinned to the
/// bottom where the thumb is.
///
/// Before this existed each step invented its own spacing and button placement,
/// which made a five-screen flow feel like five unrelated screens.
struct OnboardingStepView<Content: View>: View {
    let step: Int
    let totalSteps: Int
    let title: String
    var subtitle: String?
    var primaryTitle: String = "Weiter"
    var isPrimaryEnabled = true
    var onPrimary: () -> Void
    /// Optional low-emphasis escape hatch under the primary button.
    var skip: (title: String, action: () -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        progressDots
                        Text(title)
                            .font(.title.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.xl)
                .readableWidth()
            }

            footer
        }
        // `.ignoresSafeArea()` deckt auch die Tastatur ab — `.background`
        // allein weicht ihr aus. Was dann hinter der (durchscheinenden)
        // Tastatur liegt, ist das schwarze Fenster: Am Gerät standen an der
        // Namenseingabe schwarze Flächen in den unteren Displayecken
        // (31.07., Build 2026.0731.1147).
        .background { Theme.background.ignoresSafeArea() }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.accent : Theme.accent.opacity(0.2))
                    .frame(width: index == step ? 20 : 6, height: 6)
                    .animation(.easeOut(duration: 0.25), value: step)
            }
        }
        .padding(.bottom, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schritt \(step) von \(totalSteps)")
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Theme.onAccent)
            .tint(Theme.accent)
            .disabled(!isPrimaryEnabled)
            // Stable handle for the UI journeys: several steps put a text field
            // on screen, and the software keyboard contributes its own buttons
            // labelled "Weiter" and "Fertig" that are otherwise indistinguishable
            // from these by label alone.
            .accessibilityIdentifier("onboarding.primary")

            if let skip {
                Button(skip.title, action: skip.action)
                    .font(.subheadline)
                    .tint(Theme.accent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .readableWidth()
        // The bar spans the full width even where the buttons do not — a
        // floating strip in the middle of an iPad would read as a dialog.
        .background(.bar)
    }
}

// MARK: - Selectable chip

/// Toggleable pill used by the diet and budget steps. 44 pt tall so it stays a
/// comfortable target, and it carries its selection state to VoiceOver rather
/// than relying on color alone.
struct SelectableChip: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Theme.accent.opacity(0.15) : Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.stroke, lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? Theme.accent : Color.primary)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    OnboardingStepView(
        step: 2,
        totalSteps: 5,
        title: "Wie viele Leute kaufst du ein?",
        subtitle: "Damit die Mengenvorschläge später passen.",
        onPrimary: {},
        skip: (title: "Überspringen", action: {})
    ) {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
            SelectableChip(title: "Vegetarisch", symbol: "carrot", isSelected: true) {}
            SelectableChip(title: "Vegan", symbol: "leaf", isSelected: false) {}
        }
    }
}
