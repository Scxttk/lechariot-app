import SwiftUI

/// Everything the tour can point at.
///
/// A case exists only where a real view can carry the tag. The tab bar is drawn
/// by UIKit and cannot — `.tabBarTop` is a zero-height marker on the tab
/// content's bottom safe edge, which *is* the top of the bar.
enum TutorialTarget: String, CaseIterable, Hashable {
    case inputBar
    case suggestions
    /// Die Angaben-Schicht über der Eingabezeile — siehe `ItemDetailPanel`.
    case detailPanel
    case planCard
    /// Angebotskachel der ersten offenen Zeile.
    case rowMatch
    /// Abhak-Kreis derselben Zeile.
    case rowCheck
    case tabBarTop
    /// Nullhöhen-Marker auf der **Ober**kante der sicheren Fläche des
    /// Angebote-Tabs — also genau die Unterkante der Navigationsleiste. Wie
    /// `tabBarTop` der einzige Griff, den SwiftUI auf eine von UIKit
    /// gezeichnete Leiste hergibt.
    case navBarBottom
    /// Die Hinweiszeile der Vorschau („Diese Preise gelten noch nicht") — seit
    /// dem 08.08. eine getönte Zeile in Warnfarbe statt einer Fettung in grauer
    /// Fußnote (#90). Sie ist die eine Sache, die man auf diesem Bildschirm
    /// wissen muss, und damit das Ziel der Schlusskarte des Rundgangs.
    case nextWeekNotice
    case settingsMarkets
    case settingsHelp
}

/// One layout pass' worth of anchors: the tagged views that were on screen.
///
/// A dictionary rather than a list, because the pass collects tagged views from
/// separate subtrees and each target has to stay findable by name.
///
/// Bis L-2 (2026-07-31) trug ein Ziel diese Zusammenführung wirklich: Die
/// Vorschlagskacheln lagen im Leerzustand **und** als Listenabschnitt, immer nur
/// eine der beiden Fassungen wurde gebaut, und der letzte Schreiber gewann. Die
/// Kacheln stehen jetzt an einer Stelle; „last writer wins" ist damit ein
/// Rückfall und kein Weg mehr, den etwas geht.
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
        // mid-typing. One shape always, nothing written when idle.
        //
        // **`transform…` und nicht `anchorPreference` — gemessen am 09.08.**
        //
        // `anchorPreference` **setzt** den Wert dieser Ansicht und wirft dabei
        // weg, was ihr Teilbaum gemeldet hat. Zwei Ziele liegen aber *in* einem
        // anderen Ziel: der Winkel-Knopf in der Eingabezeile
        // (`.inputBar`) und die Preisfahne in der Kachel (`.rowCheck`). Beide
        // wurden vom Elternteil verschluckt und kamen im Overlay **nie** an.
        //
        // Aufgefallen ist es erst, als der neue Rundgang den Winkel-Knopf
        // ausleuchten sollte: Der Rahmen übersprang sich still, weil er kein
        // Ziel hatte. Der Knopf stand im Barrierefreiheits-Baum, das Loch war
        // trotzdem leer — und gefunden wurde es nicht durch Nachdenken, sondern
        // indem die Sonde `tutorial.hole` im Testlauf mitschreibt, **welche
        // Anker das Overlay wirklich hat**: `inputBar, planCard, rowCheck,
        // settingsHelp, tabBarTop` — genau ohne die zwei verschachtelten.
        //
        // `transformAnchorPreference` schreibt in den Wert des Teilbaums hinein,
        // statt ihn zu ersetzen. Damit ist Verschachteln erlaubt.
        content.transformAnchorPreference(
            key: TutorialAnchorKey.self, value: .bounds
        ) { value, anchor in
            guard active else { return }
            value[target] = anchor
        }
    }
}
