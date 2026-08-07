import SwiftUI

/// **Der Auftritt beim Kaltstart: Der Wagen zeichnet sich selbst.**
///
/// Scott, 06.08.: „i want a start animation where the logo morphs and
/// everything."
///
/// **Was iOS erlaubt, und was nicht.** Der Startbildschirm ist statisch,
/// Punkt — das System zeichnet ihn, bevor der eigene Prozess läuft. Kein Code,
/// keine Bewegung. Der einzige Hebel ist, das **letzte statische Bild und das
/// erste eigene Bild gleich aussehen zu lassen**, damit der Übergang nicht zu
/// sehen ist. Genau deshalb ist der Startbildschirm hier eine leere cremefarbene
/// Fläche (`LaunchBackground` in `project.yml`) und das erste Bild dieser
/// Ansicht auch eine — der Wagen steht bei `trim = 0`, ist also noch gar nicht
/// da. Zwei identische leere Flächen lassen sich nicht falsch aneinandersetzen.
///
/// **Warum Aufziehen und kein echter Form-Morph.** Ein überzeugender Morph
/// zwischen zwei Silhouetten braucht beide von Hand als dieselben ~20 Punkte,
/// mit gleicher Umlaufrichtung — ein Tagwerk für eine Sekunde, die man einmal
/// pro Installation sieht. `.trim` auf einem mehrteiligen Pfad läuft dessen
/// Teilpfade der Reihe nach ab und schreibt den Wagen dadurch **in der
/// Reihenfolge, in der ein Mensch ihn zeichnen würde** (siehe `CartShape`).
///
/// **Und kein `Task.sleep` als Taktgeber.** `PhaseAnimator` läuft auf der
/// Render-Schleife, ist unterbrechbar und driftet unter Last nicht. Die
/// Sequenz-mit-Schlafen-Bauart steht anderswo in dieser App und ist genau das,
/// was hier nicht kopiert werden soll.
struct LaunchIntroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void

    @State private var started = false

    /// Fünf Takte. `leer` ist absichtlich der erste: Er ist das Bild, das der
    /// statische Startbildschirm schon zeigt.
    private enum Beat: CaseIterable {
        case leer, gezeichnet, gesetzt, gewandelt, weg

        /// Wie weit der Wagen schon Liste ist. Siehe `CartToListShape`.
        var morph: CGFloat {
            switch self {
            case .leer, .gezeichnet, .gesetzt: 0
            case .gewandelt, .weg: 1
            }
        }

        var draw: CGFloat {
            switch self {
            case .leer: 0
            default: 1
            }
        }

        var scale: CGFloat {
            switch self {
            case .leer, .gezeichnet: 0.94
            case .gesetzt, .gewandelt: 1
            case .weg: 1.04
            }
        }

        var opacity: CGFloat {
            switch self {
            case .weg: 0
            default: 1
            }
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            PhaseAnimator(Beat.allCases, trigger: started) { beat in
                // **Zuerst zeichnen, dann wandeln.** Das Aufziehen erzählt
                // „hier entsteht etwas", die Wandlung erzählt, **was** die App
                // tut: Die Räder werden zu den Kästchen, zwei Streben zu den
                // Zeilen. Siehe `CartToListShape`.
                CartToListShape(progress: beat.morph)
                    .trim(from: 0, to: beat.draw)
                    .stroke(
                        Theme.accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 116, height: 116)
                    .scaleEffect(beat.scale)
                    .opacity(beat.opacity)
            } animation: { beat in
                switch beat {
                case .leer: .none
                // Zeichnen ist kein Federweg: Eine Feder ließe den Strich am
                // Ende zurückschwingen, und ein Strich schwingt nicht.
                case .gezeichnet: .easeOut(duration: 0.55)
                case .gesetzt: .snappy(duration: 0.28)
                // Die Wandlung darf Zeit haben — sie ist der Satz, den der
                // Auftritt erzählt, und sie ist in 0,2 s nicht zu lesen.
                case .gewandelt: .snappy(duration: 0.5)
                case .weg: Theme.Motion.screen.animation
                }
            }
        }
        .accessibilityHidden(true)
        .task {
            // **Bewegung abgestellt heißt: kein Auftritt.** Nicht „kürzer" —
            // dieselbe Regel wie überall sonst in dieser App. Wer Bewegung
            // ausgeschaltet hat, sieht den statischen Startbildschirm und dann
            // die Liste.
            //
            // **Und im Testlauf gibt es ihn gar nicht.** Das ist keine
            // Bequemlichkeit: Der Auftritt schiebt jeden Start um 1,15 s nach
            // hinten, und Journeys, die ohne `waitForExistence` tippen, laufen
            // dadurch ins Leere. Fünf fremde Journeys sind daran gefallen,
            // bevor diese Zeile stand — sie einzeln laufen zu lassen war grün,
            // im Rudel rot. **Merksatz: Was jeden Start verzögert, verzögert
            // auch jeden Test, und der Fehler zeigt sich woanders.**
            // `UITestSupport` gibt es nur im Debug-Bau — dieselbe Klammer wie
            // in `AppRepositories.usesMockData`.
            #if DEBUG
            let imTestlauf = UITestSupport.isActive
            #else
            let imTestlauf = false
            #endif
            guard !reduceMotion, !imTestlauf else { onFinish(); return }
            started = true
            try? await Task.sleep(for: .milliseconds(1700))
            onFinish()
        }
    }
}

#Preview {
    LaunchIntroView(onFinish: {})
}
