import Foundation

#if DEBUG

/// Puts the app back into its first-launch state — debug builds only.
///
/// Testing onboarding used to mean deleting the app from the simulator, which
/// is slow, easy to get wrong (a stale sandbox plist survives a `defaults
/// write`) and impossible on a device you also use normally. This does the same
/// job from inside the running app.
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
enum DebugReset {
    @MainActor
    static func everything(
        regions: RegionStore,
        profile: ProfileStore,
        list: ShoppingListStore,
        rejections: MatchRejectionStore
    ) {
        regions.resetAllData()
        profile.resetAllData()
        list.resetAllData()
        rejections.resetAllData()

        // Not owned by any store: the appearance override (a fresh install
        // follows the system) and the two caches that would otherwise make the
        // second run visibly faster than the first.
        AppDefaults.shared.removeObject(forKey: Theme.appearanceKey)
        try? OfferCache.shared?.deleteAll()
        URLCache.shared.removeAllCachedResponses()
    }
}

#endif
