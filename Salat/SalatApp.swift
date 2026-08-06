import SwiftUI

@main
struct SalatApp: App {
    @State private var settings = AppSettings()
    @State private var onboarding = OnboardingManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(onboarding)
                .tint(Theme.gold)
                .sheet(isPresented: .constant(onboarding.shouldShowOnboarding)) {
                    OnboardingView()
                        .environment(onboarding)
                        .localized(settings.localizer)
                        .interactiveDismissDisabled()
                }
        }
    }
}
