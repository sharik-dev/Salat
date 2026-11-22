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
        if !hasSeenOnboarding { Telemetry.shared.track("onboarding_done") }
        hasSeenOnboarding = true
        #if DEBUG
        alwaysShowOnboarding = false
        #endif
    }

    func reset() { hasSeenOnboarding = false }

    // MARK: The welcome's question

    /// The reader's answer to "how many hours a day on your phone?", kept on
    /// this phone only (never sent with the telemetry). Nil when skipped.
    static var phoneHours: Int? {
        get {
            let value = UserDefaults.standard.integer(forKey: "onboarding.phoneHours")
            return value > 0 ? value : nil
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "onboarding.phoneHours") }
    }

    /// Hours a day, as full days in a year: plain arithmetic on the answer,
    /// never a statistic. 4 h a day → 61 days.
    static func daysPerYear(hours: Int) -> Int {
        Int((Double(max(hours, 0)) * 365 / 24).rounded())
    }
}
