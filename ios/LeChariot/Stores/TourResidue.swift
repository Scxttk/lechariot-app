import Foundation

/// **Was der Rundgang auf fremden Geräten hinterlassen hat.**
///
/// Bis zum 09.08. legte er Milch, Butter und Kaffee selbst auf die Liste und
/// schrieb sie unter `tutorial.seededItems` auf Platte, damit ein abgeschossener
/// Rundgang sie beim nächsten Start wieder abräumen kann. Gesät wird seit dem
/// 09.08. nichts mehr, und seit dem Abriss gibt es den Rundgang gar nicht mehr
/// — die drei Artikel liegen aber weiter auf jedem Gerät, das ihn damals
/// erwischt hat, und niemand wüsste, woher sie kommen.
///
/// Deshalb steht das Aufräumen als eigenes, kleines Stück da statt als Rest in
/// einem Store: **Es ist vollständig löschbar**, sobald kein Gerät die
/// Schlüssel mehr trägt.
///
/// `tutorial.hasSeen` fällt gleich mit. Er steuerte, ob der Assistent den
/// Rundgang anbietet; ohne Rundgang liest ihn niemand mehr, und ein Merker, den
/// niemand liest, ist ein Kommentar (Merksatz vom 2026-08-02, damals in die
/// andere Richtung gelernt).
enum TourResidue {
    private static let seededKey = "tutorial.seededItems"
    private static let seenKey = "tutorial.hasSeen"

    static let keys = [seededKey, seenKey]

    /// Nimmt die geliehenen Artikel des alten Rundgangs von der Liste und
    /// räumt seine Schlüssel ab. Ohne Rückstand passiert nichts.
    @MainActor
    static func sweep(from list: ShoppingListStore,
                      defaults: UserDefaults = AppDefaults.shared) {
        defer { for key in keys { defaults.removeObject(forKey: key) } }
        guard let data = defaults.data(forKey: seededKey),
              let seeded = try? JSONDecoder().decode([ShoppingItem].self, from: data),
              !seeded.isEmpty else { return }
        for item in seeded { list.remove(item) }
    }
}
