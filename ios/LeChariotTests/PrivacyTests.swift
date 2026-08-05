import XCTest
@testable import LeChariot

/// **Auskunft und Löschung** ([UI-4], 01.08.).
///
/// Der Kern dieser Tests ist nicht, dass es funktioniert, sondern dass die App
/// **nichts behauptet, was nicht passiert ist**. Ein anon-DELETE auf die drei
/// Tabellen schlägt nicht fehl — RLS filtert die Zeilen weg und PostgREST
/// meldet 204. Wer daraus „gelöscht" macht, hat genau den Fehler gebaut, an
/// dem dieses Projekt schon dreimal hing.
@MainActor
final class PrivacyStoreTests: XCTestCase {

    func testDeletingReportsWhatActuallyDisappeared() async {
        let repo = MockPrivacyRepository()
        repo.rows = DeletedRows(profiles: 3, feedback: 7)
        let store = PrivacyStore(repository: repo)

        let id = UUID()
        await store.deleteUploadedData(installId: id)

        XCTAssertEqual(repo.deleted, [id])
        XCTAssertEqual(store.deletion, .done("Gelöscht: 3 Profile und 7 Rückmeldungen."))
    }

    /// **Null ist kein Erfolg, sondern eine Auskunft.** Eine Installation, die
    /// nie zugestimmt hat, hat nichts hochgeladen — und der Satz muss das
    /// sagen, statt ein Löschen zu behaupten, das keins war.
    func testNothingUploadedSaysSoInsteadOfClaimingADeletion() async {
        let repo = MockPrivacyRepository()
        repo.rows = DeletedRows(profiles: 0, feedback: 0)
        let store = PrivacyStore(repository: repo)

        await store.deleteUploadedData(installId: UUID())

        XCTAssertEqual(
            store.deletion,
            .done("Auf dem Server lag nichts zu dieser Installations-ID.")
        )
    }

    /// **Fehlende Migration ist kein Netzwerkfehler.** Solange
    /// `migration_v25_dsgvo.sql` nicht eingespielt ist, muss der Bildschirm den
    /// Weg über die Mail nennen — „Verbindungsproblem" schickt den Nutzer
    /// stattdessen in die Flugmodus-Einstellungen.
    func testAMissingFunctionNamesTheOtherWay() async {
        let repo = MockPrivacyRepository()
        repo.failure = SupabaseError.functionMissing(name: "delete_installation")
        let store = PrivacyStore(repository: repo)

        await store.deleteUploadedData(installId: UUID())

        guard case let .failed(message) = store.deletion else {
            return XCTFail("Ein fehlender Server-Weg muss als Fehler stehen, nicht als Erfolg")
        }
        XCTAssertTrue(message.contains("delete_installation"))
        XCTAssertTrue(message.contains("@"), "Ohne den anderen Weg ist die Meldung eine Sackgasse")
    }

    /// Ohne Rückweg zum Server (Mock-Lauf, keine Schlüssel) gibt es nichts zu
    /// löschen — und die App sagt das, statt einen toten Knopf anzubieten.
    func testWithoutAServerThereIsNothingToDelete() async {
        let store = PrivacyStore(repository: nil)
        XCTAssertFalse(store.canReachServer)

        await store.deleteUploadedData(installId: UUID())

        XCTAssertEqual(store.deletion, .done("Diese Installation hat nie etwas hochgeladen."))
    }

    // MARK: Export

    /// **Der Serverteil darf fehlen, der Gerätteil nie.** Ein Export, der
    /// wegen eines Funklochs gar nichts liefert, hilft niemandem — und der
    /// größere Teil der Daten hat den Server ohnehin nie gesehen.
    func testTheExportSurvivesAServerThatIsNotThere() async throws {
        let repo = MockPrivacyRepository()
        repo.failure = SupabaseError.functionMissing(name: "export_installation")
        let store = PrivacyStore(repository: repo)

        await store.buildExport(local: Self.beispiel)

        let file = try XCTUnwrap(store.exportFile)
        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(text.contains("Vollmilch"), "Der Gerätteil fehlt")
        XCTAssertTrue(text.contains("hinweis_server"), "Das Fehlen des Serverteils wird verschwiegen")
        XCTAssertTrue(text.contains("\"auf_dem_server\": null"))
    }

    func testTheExportCarriesBothHalves() async throws {
        let store = PrivacyStore(repository: MockPrivacyRepository())

        await store.buildExport(local: Self.beispiel)

        let file = try XCTUnwrap(store.exportFile)
        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(text.contains("auf_dem_geraet"))
        XCTAssertTrue(text.contains("match_feedback"), "Der Serverteil fehlt")
        // Und die Datei ist gültiges JSON — von Hand zusammengesetzt ist sie
        // genau die Sorte Text, die sich still verbiegt.
        let daten = try XCTUnwrap(text.data(using: .utf8))
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: daten))
    }

    /// Ein Hinweistext mit Anführungszeichen darin darf die Datei nicht
    /// zerreißen — er kommt aus einer Fehlermeldung und ist damit nicht unter
    /// Kontrolle dieser Stelle.
    func testAQuoteInTheNoteDoesNotBreakTheFile() throws {
        let url = try DataExportFile.write(
            local: Self.beispiel,
            serverJSON: nil,
            serverNote: "Der Server kennt \"export_installation\" nicht.\nZeilenumbruch dazu."
        )
        let daten = try Data(contentsOf: url)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: daten))
    }

    private static var beispiel: LocalDataExport {
        LocalDataExport(
            installId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            firstName: "Scott",
            householdSize: 2,
            tripsPerWeek: 1,
            weeklyBudget: 60,
            dietTags: ["bio"],
            likedChains: ["EDEKA"],
            hasConsentedToSync: true,
            regions: ["01219"],
            branches: [LocalDataExport.Branch(
                chain: "Lidl", name: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219"
            )],
            shoppingList: [LocalDataExport.Item(
                text: "Vollmilch", isChecked: false, addedAt: .init(timeIntervalSince1970: 0),
                detail: ["1 l"], pinnedProducts: [], pinnedMarkets: []
            )],
            purchaseWeights: ["milch": 2.5]
        )
    }
}
