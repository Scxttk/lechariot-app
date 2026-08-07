import XCTest
@testable import LeChariot

/// Die Testnaht des Vervollständigers, ohne Netz.
@MainActor
final class AddressCompleterTests: XCTestCase {
    private let key = "uiTestingAddressSuggestions"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testTheStubIsParsedIntoSuggestions() {
        UserDefaults.standard.set(
            "Karl-Laux-Straße 6|01219 Dresden;Karl-Laux-Straße 12|01219 Dresden",
            forKey: key
        )
        let completer = AddressCompleter()
        completer.update(query: "Karl")

        XCTAssertEqual(completer.suggestions.map(\.title),
                       ["Karl-Laux-Straße 6", "Karl-Laux-Straße 12"])
        XCTAssertEqual(completer.suggestions.first?.query,
                       "Karl-Laux-Straße 6, 01219 Dresden")
    }

    /// **Erst ab drei Zeichen.** Auf „D" antwortet Apple mit Dutzenden Orten in
    /// zufälliger Ordnung; das liest niemand, und es kostet bei jedem Anschlag
    /// eine Abfrage.
    func testTwoLettersAreNotAQuestion() {
        UserDefaults.standard.set("Dresden|Sachsen", forKey: key)
        let completer = AddressCompleter()
        completer.update(query: "Dr")
        XCTAssertTrue(completer.suggestions.isEmpty)
    }

    /// Drei reichen: Eine Vorschlagsliste, die den halben Bildschirm nimmt,
    /// verdeckt genau das Feld, in das man gerade tippt.
    func testAtMostThreeSuggestions() {
        UserDefaults.standard.set("A|1;B|2;C|3;D|4;E|5", forKey: key)
        let completer = AddressCompleter()
        completer.update(query: "Str")
        XCTAssertEqual(completer.suggestions.count, 3)
    }
}
