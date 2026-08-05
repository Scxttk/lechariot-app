import SwiftUI
import TipKit

/// **TipKit zeichnet, der `ContextTipStore` entscheidet.**
///
/// TipKit könnte beides — es hat eigene Regeln und eigene Zähler. Benutzt wird
/// davon nur die Sprechblase: Die Entscheidung, *wann* ein Tipp dran ist,
/// steht als reine Rechnung in `ContextTipRules`, weil sie dort prüfbar ist
/// (dasselbe Muster wie `TourTabTransition`). TipKits Makro-Regeln laufen erst
/// in einer konfigurierten Laufzeit und wären es nicht.
///
/// Die Kopplung ist deshalb bewusst simpel: Eine Ansicht trägt die Sprechblase
/// nur, solange ihr Tipp der aktive des Stores ist (`contextTip(_:in:when:)`).
/// TipKits eigenes Einmal-Gedächtnis bleibt als zweiter Riegel trotzdem an —
/// `MaxDisplayCount(1)`, und das X des Nutzers invalidiert bei TipKit selbst.
///
/// **Die Texte stehen für sich.** Sie stammen aus Rahmen, die der gekürzte
/// Rundgang nicht mehr hat, und dürfen deshalb nichts voraussetzen, was „die
/// Tour schon gesagt" hätte.

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

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
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

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
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

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
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

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }
}

/// Die Karte, die den gerade aktiven Tipp zeichnet — **eine je Bildschirm**,
/// oben, über dem, was sie erklärt.
///
/// **Warum keine Sprechblase (`popoverTip`).** Sie war der erste Entwurf, und
/// sie erschien nie: Im Elementbaum stand nach dem Moment weder am
/// Toolbar-Knopf noch an der Listenzeile etwas — auch nicht, als der Anhang
/// testweise bedingungslos hing. Ein `TipView` an derselben Stelle stand
/// sofort da. Zwei Messungen, eine Lehre: In dieser App zeichnet TipKit
/// Karten, keine Sprechblasen. Die Karte trägt dieselben Texte und steht am
/// selben Moment — sie zeigt nur nicht mit dem Finger.
///
/// `screen` hält die Tipps auseinander: Der Vorschau-Tipp gehört in den
/// Angebote-Tab, die anderen drei auf die Liste. Ohne das stünde der Tipp zur
/// Angebotszeile im Angebote-Tab, sobald jemand den Tab wechselt.
struct ContextTipCard: View {
    let store: ContextTipStore?
    let screen: Screen

    enum Screen {
        case list, offers

        func owns(_ tip: ContextTip) -> Bool {
            switch (self, tip) {
            case (.offers, .nextWeekPreview): true
            case (.list, .matchLine), (.list, .itemDetails), (.list, .checkOff): true
            default: false
            }
        }
    }

    var body: some View {
        if let store, let tip = store.active, screen.owns(tip) {
            switch tip {
            case .nextWeekPreview: TipView(NextWeekContextTip())
            case .matchLine: TipView(MatchLineContextTip())
            case .itemDetails: TipView(ItemDetailsContextTip())
            case .checkOff: TipView(CheckOffContextTip())
            }
        }
    }
}
