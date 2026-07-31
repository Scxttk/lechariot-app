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
///
/// **Warum das über `didMoveToWindow` läuft und nicht über `DispatchQueue.main.async`.**
/// Bis zum 2026-07-31 stand hier ein `async`-Block mit
/// `guard let window = view.window else { return }`. Beim Kaltstart ist die
/// Ansicht in diesem Moment noch in keinem Fenster — der Block fiel also
/// wirkungslos durch, **ohne es noch einmal zu versuchen**. Nachgeholt wurde
/// die Einstellung erst beim nächsten SwiftUI-Durchgang, also wenn irgendwo
/// Inhalte nachluden. Das war der gemeldete „Dark-Frame beim Kaltstart":
/// System dunkel, App auf Hell gestellt, ~1 s lang das falsche Erscheinungsbild.
///
/// `didMoveToWindow()` ist genau der Zeitpunkt, an dem es ein Fenster gibt —
/// nicht ein Runloop-Durchgang später und nicht auf gut Glück. Ein Nachreichen
/// entfällt damit, weil nichts mehr ins Leere laufen kann.
struct AppearanceWindowBridge: UIViewRepresentable {
    let appearance: AppAppearance

    func makeUIView(context: Context) -> AppearanceProbeView {
        let view = AppearanceProbeView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        // Vor dem Einhängen setzen, damit `didMoveToWindow` schon den
        // richtigen Wert vorfindet und nicht erst den Standard anlegt.
        view.style = appearance.interfaceStyle
        return view
    }

    func updateUIView(_ view: AppearanceProbeView, context: Context) {
        view.style = appearance.interfaceStyle
    }
}

/// Trägt den gewünschten Stil ans Fenster, sobald es eines gibt.
final class AppearanceProbeView: UIView {
    var style: UIUserInterfaceStyle = .unspecified {
        didSet {
            guard style != oldValue else { return }
            // Eine Änderung *im Betrieb* ist die Auswahl in den Einstellungen —
            // die bekommt die Überblendung.
            apply(crossFading: hasApplied)
        }
    }

    /// Ob am Fenster schon einmal etwas gesetzt wurde. Beim ersten Mal gibt es
    /// nichts, wovon überzublenden wäre; eine Überblendung sähe dort wie ein
    /// Fehler aus.
    private var hasApplied = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        apply(crossFading: false)
    }

    private func apply(crossFading: Bool) {
        let style = self.style
        guard let window, window.overrideUserInterfaceStyle != style else { return }
        hasApplied = true
        guard crossFading else {
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

extension View {
    /// Attach once, near the root: keeps the window's interface style in sync
    /// with `appearance`.
    func appearanceOverride(_ appearance: AppAppearance) -> some View {
        background(AppearanceWindowBridge(appearance: appearance).frame(width: 0, height: 0))
    }
}
