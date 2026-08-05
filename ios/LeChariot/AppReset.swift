import Foundation

/// Puts the app back into its first-launch state.
///
/// Testing onboarding used to mean deleting the app from the simulator, which
/// is slow, easy to get wrong (a stale sandbox plist survives a `defaults
/// write`) and impossible on a device you also use normally. This does the same
/// job from inside the running app.
///
/// **Ab 2026-07-30 auch im Release-Build**, und das ist der Grund, warum dieser
/// Typ nicht mehr `DebugReset` heißt und nicht mehr unter `Debug/` liegt: Die
/// App liegt seit dem 30.07. bei Testern ohne Xcode — Scotts Großeltern haben
/// sie geschenkt bekommen. Wer feststeckte, hatte bis hierher genau einen
/// Ausweg, nämlich löschen und neu installieren. Das ist keiner, den man am
/// Telefon erklären kann.
///
/// The contract is *exactness*: after `everything()` no store holds state in
/// memory, no UserDefaults key of ours exists on disk, the offer cache is empty
/// and cached thumbnails are gone. `ContentView` observes
/// `RegionStore.isOnboardingComplete`, so the switch back to the welcome screen
/// happens on the same run loop — no restart, and repeating the reset ten times
/// in a row produces ten identical runs.
///
/// Every store owns its own wipe (`resetAllData()`); this type only knows the
/// list of stores, so adding one is a one-line change here rather than a hunt
/// through the app for forgotten keys.
enum AppReset {
    @MainActor
    static func everything(
        regions: RegionStore,
        profile: ProfileStore,
        list: ShoppingListStore,
        rejections: MatchRejectionStore,
        feedback: MatchFeedbackStore,
        tutorial: TutorialStore,
        tips: ContextTipStore,
        areaRequests: AreaRequestStore,
        branchRequests: BranchRequestStore,
        history: PurchaseHistoryStore,
        placeNames: PlaceNameStore
    ) {
        regions.resetAllData()
        profile.resetAllData()
        list.resetAllData()
        rejections.resetAllData()
        feedback.resetAllData()
        tutorial.resetAllData()
        // Die Einmal-Tipps und die Ernährungsfrage. Ohne dies wüsste eine
        // „neue" Installation noch, was der alten schon gezeigt wurde — und
        // der Reset wäre nicht mehr exakt.
        tips.resetAllData()
        // Ohne dies überlebt die Liste der bereits angekündigten Gebiete den
        // Reset, und ein erneutes Onboarding fordert dasselbe Gebiet nie
        // wieder an — der Reset wäre nicht mehr exakt.
        areaRequests.resetAllData()
        // Dasselbe eine Ebene tiefer: Bliebe der Zustand der Filial-
        // Anforderungen stehen, hielte die App Filialen für „schon geholt",
        // die nach dem Reset gar nicht mehr gewählt sind.
        branchRequests.resetAllData()
        // Die Kaufhistorie. Sie hat als einziger Speicher **auch** einen
        // eigenen Knopf („Vorschläge vergessen"), weil man sie loswerden
        // können soll, ohne alles aufzugeben — hier wird sie trotzdem
        // mitgelöscht, sonst wäre der Reset nicht exakt.
        history.resetAllData()
        // Abgeleitet, aber nicht harmlos: Der Zwischenspeicher nennt die Orte,
        // an denen jemand eingecheckt hat.
        placeNames.resetAllData()

        // Not owned by any store: the appearance override (a fresh install
        // follows the system) and the two caches that would otherwise make the
        // second run visibly faster than the first.
        AppDefaults.shared.removeObject(forKey: Theme.appearanceKey)
        try? OfferCache.shared?.deleteAll()
        URLCache.shared.removeAllCachedResponses()
        OfferImageLoader.shared.reset()
    }
}
