import XCTest

/// **Punkt B-3: Verformt sich die Eingabezeile beim Tippen?**
///
/// Scott am Build `2026.810.705`: „while typing a product, the ‚Nächster
/// Artikel'-Container gets morphed." Gemessen wird deshalb der **Rahmen des
/// Feldes nach jedem Buchstaben** — nicht das Aussehen, sondern die Zahl, die
/// dahinter steht. Ein Feld, das mitten im Wort seine Breite ändert, ist
/// genau das, was ein Auge als „verformt" meldet.
///
/// Die Buchstabenfolge ist mit Bedacht gewählt: „v" kennt das Wörterbuch
/// nicht, „vo" schon, „vollx" wieder nicht. Wer an der Zahl der Treffer hängt,
/// wackelt genau hier.
final class EingabezeileProbe: XCTestCase {
    func testMissDieEingabezeileBeimTippen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 20))
        feld.tapAndAwaitKeyboard(in: app)

        let fenster = app.windows.firstMatch.frame
        var rahmen: [(String, CGRect)] = [("leer", feld.frame)]
        attach(app, name: "zeile-00-leer")

        for (i, buchstabe) in ["v", "o", "l", "l", "x"].enumerated() {
            app.typeText(buchstabe)
            let jetzt = app.textFields["list.input"].frame
            rahmen.append((String(rahmen.count), jetzt))
            attach(app, name: String(format: "zeile-%02d-%@", i + 1, buchstabe))
        }

        // Und ein langes Wort: Ein Feld, das mit dem Text wächst oder schrumpft,
        // fällt erst hier auf.
        app.typeText("Ⅹ")   // wird verworfen, falls nicht tippbar
        app.typeText("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        let lang = app.textFields["list.input"].frame
        rahmen.append(("lang", lang))
        attach(app, name: "zeile-99-langer-text")

        print("PROBE fenster=\(Int(fenster.width))x\(Int(fenster.height))")
        for (name, r) in rahmen {
            print("PROBE \(name): x=\(r.minX) breite=\(r.width) hoehe=\(r.height)")
        }
        let breiten = Set(rahmen.map { Int($0.1.width.rounded()) })
        print("PROBE breiten=\(breiten.sorted())")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
