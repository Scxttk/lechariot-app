import SwiftUI

/// Full-screen rectangle with a rounded hole punched into it.
///
/// Two subpaths, even-odd filled: the inner one cancels the outer. The same
/// shape serves twice — once as the drawn scrim, once as the overlay's
/// `contentShape`, which is what makes the hole (and only the hole) let touches
/// through to the app underneath.
struct SpotlightShape: Shape {
    var hole: CGRect
    var cornerRadius: CGFloat

    /// Interpolates origin and size, so the highlight slides and resizes as one
    /// piece between frames instead of jumping.
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>,
                                       AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(hole.minX, hole.minY),
                AnimatablePair(hole.width, hole.height)
            )
        }
        set {
            hole = CGRect(
                x: newValue.first.first,
                y: newValue.first.second,
                width: newValue.second.first,
                height: newValue.second.second
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        // Kein Loch: der ganze Bildschirm ist abgedeckt und tot. Genau das ist
        // der Zustand für „nur erklären“ und für laufendes VoiceOver.
        guard hole.width > 0.5, hole.height > 0.5 else { return path }
        path.addRoundedRect(
            in: hole,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        return path
    }
}
