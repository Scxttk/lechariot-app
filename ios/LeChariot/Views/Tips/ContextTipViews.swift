import SwiftUI
import TipKit

/// **TipKit zeichnet, der `ContextTipStore` entscheidet.**
///
/// TipKit könnte beides — es hat eigene Regeln und eigene Zähler. Benutzt wird
/// davon nur die Karte: Die Entscheidung, *wann* ein Schild dran ist, steht als
/// reine Rechnung in `ContextTipRules`, weil sie dort prüfbar ist. TipKits
/// Makro-Regeln laufen erst in einer konfigurierten Laufzeit und wären es nicht.
///
/// Die Kopplung ist deshalb bewusst simpel: Eine Ansicht trägt das Schild nur,
/// solange sein Tipp der aktive ihrer Fläche ist (`ContextTipCard`).
///
/// **Und TipKit zählt bewusst gar nichts mit.** Bis zum 10.08. trug jeder Tipp
/// `MaxDisplayCount(1)`, und das ✗ invalidierte ihn zusätzlich bei TipKit — als
/// „zweiter Riegel". Genau dieser zweite Riegel macht „Tipps wieder anzeigen"
/// aus den Einstellungen (Schicht 3) unmöglich: TipKits Merker liegt im
/// App-Container, `resetDatastore()` wirkt nur **vor** `Tips.configure()`, und
/// ein Knopf, der nichts tut, ist schlimmer als keiner. Das Einmal-Versprechen
/// hält der Store allein (`ContextTipLedger.shown`) — eine Entscheidung, eine
/// Stelle. `ContextTipJourneyTests.testShowingTipsAgainBringsTheSignBack` hält
/// den Fall fest.
///
/// **Die Texte stehen für sich.** Sie stammen aus Rahmen, die es seit dem
/// Abriss des Rundgangs nicht mehr gibt, und dürfen deshalb nichts
/// voraussetzen, was „die Tour schon gesagt" hätte.

/// „Nächste Woche" im Angebote-Tab — das bewusste Warten.
struct NextWeekContextTip: Tip {
    var title: Text {
        Text("Was ab Montag billiger wird")
    }

    var message: Text? {
        Text("Hinter „Nächste Woche“ steht die Vorschau. Sie beantwortet die Frage, die sonst niemand beantwortet: Was kaufe ich heute bewusst nicht, weil es Montag günstiger ist?")
    }

    var image: Image? {
        Image(systemName: "calendar")
    }
}

/// Die Angebotszeile unterm Artikel: Treffer, Preisverlauf, Anheften.
struct MatchLineContextTip: Tip {
    var title: Text {
        Text("Mehr als das eine Angebot")
    }

    var message: Text? {
        Text("Tipp die Angebotszeile an: Dahinter stehen alle Treffer zu diesem Artikel samt Preisverlauf — und du kannst dir eine Wahl fest anheften.")
    }

    var image: Image? {
        Image(systemName: "pin")
    }
}

/// Menge, Größe, Notiz — die Angaben-Schicht hinter dem Artikelnamen.
struct ItemDetailsContextTip: Tip {
    var title: Text {
        Text("Menge, Größe, Notiz")
    }

    var message: Text? {
        Text("Tipp den Artikelnamen an — dahinter liegen seine Angaben, mit Platz für eigene Worte hinter „Notiz …“. Ein Angebot, keine Frage: Deine Liste funktioniert auch ohne.")
    }

    var image: Image? {
        Image(systemName: "square.and.pencil")
    }
}

/// Abhaken und Löschen — die zwei Handgriffe an der Zeile.
struct CheckOffContextTip: Tip {
    var title: Text {
        Text("Abhaken und Löschen")
    }

    var message: Text? {
        Text("Im Laden tippst du den Kreis an — der Artikel wandert zu „Erledigt“. Und wischst du eine Zeile nach links, ist sie weg.")
    }

    var image: Image? {
        Image(systemName: "checkmark.circle")
    }
}

// MARK: - Das Emailschild

/// **Ein Schild, kein Scheinwerfer** — die Gestalt aus Rundgang-Konzept §5.
///
/// Das App-Icon ist ein französisches Emailschild: randvolle Emaille, weißer
/// Rand, dünne Innenlinie. Ein Hinweis dieser App ist ein kleines Schild
/// derselben Familie, und daraus folgt jede Einzelheit:
///
/// - **Die doppelte Kante trägt, nicht der Schatten.** Creme auf Creme hebt
///   sich über den Rand ab — kräftige Außenlinie in Emaille-Grün, feine
///   Innenlinie mit Luft dazwischen. Ein Schlagschatten wäre Höhe, und Höhe
///   ist die Sprache des Belags, den wir gerade abgerissen haben.
/// - **Farbe aus `Theme`, nichts hartkodiert.** Überschrift in Akzent-Grün,
///   Fließtext im warmen Sekundärton; im Dunkelmodus spiegelt es sich mit den
///   Tokens von selbst.
/// - **Textstile statt eigener Größen** (`headline`/`subheadline`) — das Schild
///   wirkt über Rand und Farbe, nicht über eine Zierschrift, und Dynamic Type
///   bleibt heil. Genau daran hat die Rundgang-Karte zweimal geblutet.
/// - **Ein ✗ und sonst kein Knopf.** Das Wegtippen ist der einzige Ausgang, den
///   ein Schild braucht; die HIG lässt einen Knopf nur zu, wenn er irgendwohin
///   führt, und keines der vier Schilder tut das. `configuration.actions` wird
///   deshalb gar nicht gezeichnet — wer je eines hinzufügt, sieht es hier
///   fehlen, statt es unbemerkt zu verlieren.
struct EnamelSignTipViewStyle: TipViewStyle {
    /// Was das ✗ tut: das Schild aus dem Store nehmen, der es zeichnen lässt.
    /// Gezeigt ist es dort längst — der Merker fällt beim Anzeigen, nicht beim
    /// Wegdrücken (`ContextTipStore.activate`).
    let onDismiss: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if let image = configuration.image {
                image
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                configuration.title
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                configuration.message
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.secondaryText)
                    .padding(Theme.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hinweis ausblenden")
            .accessibilityIdentifier("tip.dismiss")
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            // Außenkante kräftig, Innenlinie fein und mit Luft dazwischen —
            // die zwei Linien des Emailschilds.
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.accent, lineWidth: 1.5)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.inner)
                        .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 0.75)
                        .padding(Theme.Spacing.xs)
                }
        }
    }
}

// MARK: - Die Karte

/// Die Karte, die das gerade aktive Schild dieser Fläche zeichnet — **eines je
/// Bildschirm**, oben, über dem, was es erklärt.
///
/// **Warum keine Sprechblase (`popoverTip`).** Sie war der erste Entwurf, und
/// sie erschien nie: Im Elementbaum stand nach dem Moment weder am
/// Toolbar-Knopf noch an der Listenzeile etwas — auch nicht, als der Anhang
/// testweise bedingungslos hing. Ein `TipView` an derselben Stelle stand
/// sofort da. Zwei Messungen, eine Lehre: In dieser App zeichnet TipKit
/// Karten, keine Sprechblasen. Das Schild trägt dieselben Texte und steht am
/// selben Moment — es zeigt nur nicht mit dem Finger.
///
/// `surface` hält die Schilder auseinander: Der Vorschau-Tipp gehört in den
/// Angebote-Tab, die anderen drei auf die Liste. Ohne das stünde das Schild zur
/// Angebotszeile im Angebote-Tab, sobald jemand den Tab wechselt.
struct ContextTipCard: View {
    let store: ContextTipStore?
    let surface: ContextTip.Surface

    var body: some View {
        if let store, let tip = store.activeTip(on: surface) {
            tipView(for: tip)
                .tipViewStyle(EnamelSignTipViewStyle {
                    store.dismissTip(on: surface)
                })
        }
    }

    @ViewBuilder
    private func tipView(for tip: ContextTip) -> some View {
        switch tip {
        case .nextWeekPreview: TipView(NextWeekContextTip())
        case .matchLine: TipView(MatchLineContextTip())
        case .itemDetails: TipView(ItemDetailsContextTip())
        case .checkOff: TipView(CheckOffContextTip())
        }
    }
}
