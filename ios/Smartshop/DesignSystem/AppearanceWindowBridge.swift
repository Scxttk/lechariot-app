import SwiftUI
import UIKit

/// Applies the user's appearance choice to the `UIWindow` instead of via
/// `preferredColorScheme`.
///
/// `preferredColorScheme` on the `WindowGroup` re-evaluates the whole hierarchy:
/// the dynamic theme colours flip immediately while navigation bar, tab bar and
/// the `List` background get dragged along by whatever animation the picker
/// happens to be running. The result is a multi-step flip with a wrong-coloured
/// flash in between.
///
/// UIKit can do better: changing `overrideUserInterfaceStyle` inside a
/// `UIView.transition` cross-fades a snapshot of the entire window, bars
/// included, so everything changes in one step.
struct AppearanceWindowBridge: UIViewRepresentable {
    let appearance: AppAppearance

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let style = appearance.interfaceStyle
        // The view is not in a window yet during the first layout pass, and
        // `window` is only reliable once the current pass has finished.
        DispatchQueue.main.async {
            guard let window = view.window, window.overrideUserInterfaceStyle != style else { return }
            // No cross-fade on the very first application — at launch there is
            // nothing to fade from, and a fade there just looks like a glitch.
            guard context.coordinator.hasApplied else {
                context.coordinator.hasApplied = true
                window.overrideUserInterfaceStyle = style
                return
            }
            UIView.transition(
                with: window,
                duration: 0.28,
                options: [.transitionCrossDissolve, .allowAnimatedContent]
            ) {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var hasApplied = false
    }
}

extension View {
    /// Attach once, near the root: keeps the window's interface style in sync
    /// with `appearance`.
    func appearanceOverride(_ appearance: AppAppearance) -> some View {
        background(AppearanceWindowBridge(appearance: appearance).frame(width: 0, height: 0))
    }
}
