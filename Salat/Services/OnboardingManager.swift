import SwiftUI

@Observable
final class OnboardingManager {
    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    #if DEBUG
    var alwaysShowOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "alwaysShowOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "alwaysShowOnboarding") }
    }
    let isDevMode = true
    #else
    let alwaysShowOnboarding = false
    let isDevMode = false
    #endif

    var shouldShowOnboarding: Bool {
        #if DEBUG
        return alwaysShowOnboarding || !hasSeenOnboarding
        #else
        return !hasSeenOnboarding
        #endif
    }

    func markSeen() { hasSeenOnboarding = true }
    func reset()    { hasSeenOnboarding = false }
}
