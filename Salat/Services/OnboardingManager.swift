import SwiftUI

@Observable
final class OnboardingManager {

    /// Stored, not computed. `@Observable` only tracks stored properties, so a
    /// computed passthrough to `UserDefaults` would change the defaults without
    /// ever telling SwiftUI — which left the onboarding sheet unable to close.
    /// The defaults are read once here and written on every set.
    var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: Key.hasSeen) }
    }

    #if DEBUG
    var alwaysShowOnboarding: Bool {
        didSet { defaults.set(alwaysShowOnboarding, forKey: Key.alwaysShow) }
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

    private let defaults: UserDefaults

    /// Injected so tests can run on their own suite. The tests are hosted by
    /// the app (`TEST_HOST`), whose onboarding sheet writes to `.standard`
    /// through its binding *while* a test scrubs the same key — on a shared
    /// domain the two race, and the race was lost about once per run.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasSeenOnboarding = defaults.bool(forKey: Key.hasSeen)
        #if DEBUG
        alwaysShowOnboarding = defaults.bool(forKey: Key.alwaysShow)
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
