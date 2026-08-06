import SwiftUI

@Observable
final class OnboardingManager {

    /// Stored, not computed. `@Observable` only tracks stored properties, so a
    /// computed passthrough to `UserDefaults` would change the defaults without
    /// ever telling SwiftUI — which left the onboarding sheet unable to close.
    /// The defaults are read once here and written on every set.
    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Key.hasSeen) }
    }

    #if DEBUG
    var alwaysShowOnboarding: Bool {
        didSet { UserDefaults.standard.set(alwaysShowOnboarding, forKey: Key.alwaysShow) }
    }
    let isDevMode = true
    #else
    let alwaysShowOnboarding = false
    let isDevMode = false
    #endif

    private enum Key {
        static let hasSeen = "hasSeenOnboarding"
        static let alwaysShow = "alwaysShowOnboarding"
    }

    init() {
        hasSeenOnboarding = UserDefaults.standard.bool(forKey: Key.hasSeen)
        #if DEBUG
        alwaysShowOnboarding = UserDefaults.standard.bool(forKey: Key.alwaysShow)
        if LaunchOptions.resetsOnboarding {
            hasSeenOnboarding = false
            alwaysShowOnboarding = false
        }
        #endif
    }

    var shouldShowOnboarding: Bool {
        #if DEBUG
        return alwaysShowOnboarding || !hasSeenOnboarding
        #else
        return !hasSeenOnboarding
        #endif
    }

    /// Finishing must always get you into the app. In a debug build the
    /// "always show" toggle would otherwise re-present the sheet immediately
    /// and there would be no way out, so finishing clears it too.
    func markSeen() {
        hasSeenOnboarding = true
        #if DEBUG
        alwaysShowOnboarding = false
        #endif
    }

    func reset() { hasSeenOnboarding = false }
}
