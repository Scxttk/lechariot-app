import Foundation

/// The `UserDefaults` every store and every `@AppStorage` in the app writes to.
///
/// Normally this is `.standard`. Under `-uiTesting` it is a private suite that
/// gets emptied at launch, which is the only way to get a real first launch out
/// of the simulator: on iOS 26.2 neither `removePersistentDomain(forName:)` with
/// the app's own bundle identifier nor a key-by-key `removeObject` clears
/// `UserDefaults.standard` — the values are handed straight back on the next
/// read, so every UI journey started in the middle of the app instead of on the
/// welcome screen. Wiping a *named suite* does work, so the app persists into
/// one during test runs.
///
/// The stores take their defaults as an init parameter, so unit tests keep
/// passing their own throwaway instances and are unaffected by this.
enum AppDefaults {
    static let shared: UserDefaults = {
        #if DEBUG
        if let suite = UITestSupport.freshSuite() { return suite }
        #endif
        return .standard
    }()
}
