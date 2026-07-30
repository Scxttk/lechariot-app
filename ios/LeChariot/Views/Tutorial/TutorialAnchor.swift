import SwiftUI

/// Everything the tour can point at.
///
/// A case exists only where a real view can carry the tag. The tab bar is drawn
/// by UIKit and cannot — `.tabBarTop` is a zero-height marker on the tab
/// content's bottom safe edge, which *is* the top of the bar.
enum TutorialTarget: String, CaseIterable, Hashable {
    case inputBar
    case suggestions
    case planCard
    /// Angebotskachel der ersten offenen Zeile.
    case rowMatch
    /// Abhak-Kreis derselben Zeile.
    case rowCheck
    case tabBarTop
    case settingsMarkets
    case settingsHelp
}

/// One layout pass' worth of anchors: the tagged views that were on screen.
///
/// A dictionary rather than a list, because the same target can be published
/// twice in one pass — the suggestion chips exist both in the empty state and
/// as a list section, and only one of them is ever laid out. Last writer wins.
struct TutorialAnchorKey: PreferenceKey {
    static let defaultValue: [TutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TutorialTarget: Anchor<CGRect>],
        nextValue: () -> [TutorialTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Publishes this view's bounds to the tutorial overlay at the root.
    func tutorialAnchor(_ target: TutorialTarget) -> some View {
        modifier(TutorialAnchorModifier(target: target))
    }

    /// Conditional variant for views that appear many times over — only the
    /// first open row carries the row anchors.
    @ViewBuilder
    func tutorialAnchor(_ target: TutorialTarget, when condition: Bool) -> some View {
        if condition {
            tutorialAnchor(target)
        } else {
            self
        }
    }
}

private struct TutorialAnchorModifier: ViewModifier {
    /// Optional on purpose: previews and unit-test hosts that never show the
    /// tour do not have to inject the store just to render a tagged view.
    @Environment(TutorialStore.self) private var tutorial: TutorialStore?
    let target: TutorialTarget

    func body(content: Content) -> some View {
        // Read in `body`, so @Observable actually registers the dependency.
        // Inside the anchor closure it would not: that closure runs during
        // layout, outside the observation scope.
        let active = tutorial?.isRunning == true
        // Deliberately not `if active { … } else { content }`: a branch changes
        // structural identity, and the input bar holds a TextField bound to
        // @FocusState. Flipping identity under it drops first responder
        // mid-typing. One shape always, empty dictionary when idle.
        content.anchorPreference(key: TutorialAnchorKey.self, value: .bounds) {
            active ? [target: $0] : [:]
        }
    }
}
