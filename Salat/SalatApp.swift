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
                // A two-way binding, so dismissing the sheet — by the button or
                // by any route iOS offers — actually records that it was seen.
                // `.constant` here meant the sheet could never close.
                .sheet(isPresented: Binding(
                    get: { onboarding.shouldShowOnboarding },
                    set: { showing in if !showing { onboarding.markSeen() } }
                )) {
                    OnboardingView()
                        .environment(onboarding)
                        .localized(settings.localizer)
                }
        }
    }
}
