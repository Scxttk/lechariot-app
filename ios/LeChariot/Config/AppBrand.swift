import Foundation

/// **Der Name der App, an einer Stelle.**
///
/// Bis zum 06.08. stand „Le Chariot" in **achtzehn** deutschen Sätzen über die
/// App verteilt — im Onboarding, in der Einwilligung, in vier Erklärtexten der
/// Einstellungen, im Datenexport, im Leerzustand der Liste. Ein Namenswechsel
/// hieß: achtzehn Sätze finden und keinen übersehen.
///
/// **Und ein Wechsel steht wieder im Raum.** Le Chariot hieß bis zum 26.07.
/// Smartshop; seit dem 31.07. ist zusätzlich bekannt, dass **Ford die EU-Marke
/// „CHARIOT" in genau unseren Klassen 9 + 42 hält** (EUTM 016129629, Status
/// lebend), dazu 14 weitere „Chariot"-Marken in 9/35/42. Für eine geschlossene
/// Beta ist das tragbar, für eine Veröffentlichung nicht. Die Vorarbeit für den
/// Wechsel liegt fertig in der Vault-Notiz „Le Chariot Markenrecherche".
///
/// Wenn er kommt, ist er hier **eine Zeile** — plus der Anzeigename in
/// `project.yml`, das Icon und der Eintrag in App Store Connect. Die
/// **Bundle-ID bleibt** `com.skoehler.lechariot`: Beim Wechsel von Smartshop
/// wanderte sie mit, und die alte App steht seitdem als zweites Icon auf
/// Scotts iPhone. Beim nächsten Mal träfe das die Tester.
enum AppBrand {
    /// Wie die App sich selbst nennt, wenn sie in einem Satz vorkommt.
    ///
    /// **Mit geschütztem Leerzeichen** (06.08.): Scott sah „Le" und „Chariot"
    /// auf zwei Zeilen — in einem zentrierten Leerzustand bricht der Name sonst
    /// genau in der Mitte um. Ein Name, der umbricht, liest sich als zwei
    /// Wörter, und „Le" allein am Zeilenende ist keins.
    static let name = "Le\u{00A0}Chariot"
}
