import SwiftUI

@main
struct SalatApp: App {
    @State private var settings = AppSettings()
    @State private var onboarding = OnboardingManager()
    // One player and one recorder for the whole app: two screens each holding
    // their own would let a reciter and a playback of the user run at once.
    @State private var player = RecitationPlayer()
    @State private var recorder = VoiceRecorder()
    @State private var reminders = StudyReminders()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // The Taptic engine and the two sounds are woken here: a cold
        // generator answers a hundred milliseconds late, which is exactly long
        // enough for the first buzz of the session to land after the button.
        Theme.registerPixelFont()
        Haptic.warmUp()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(onboarding)
                .environment(player)
                .environment(recorder)
                .environment(reminders)
                .tint(Theme.gold)
                // Rewritten at every return to the app rather than only when
                // the switch is touched: the plan names steps that are still
                // unlearned, and that changes as the user learns them.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await reminders.sync(with: settings) }
                }
                // Ads (consent form, then tracking prompt) wait for onboarding
                // to be gone: two system sheets over the first page would be
                // the app's first impression.
                .onChange(of: onboarding.shouldShowOnboarding, initial: true) { _, showing in
                    if !showing { Ads.shared.start() }
                }
                // A two-way binding, so dismissing the sheet — by the button or
                // by any route iOS offers — actually records that it was seen.
                // `.constant` here meant the sheet could never close.
                .sheet(isPresented: Binding(
                    get: { onboarding.shouldShowOnboarding },
                    set: { showing in if !showing { onboarding.markSeen() } }
                )) {
                    OnboardingView()
                        .environment(onboarding)
                        // The first page picks the language, so the sheet needs
                        // the settings the rest of the app writes to.
                        .environment(settings)
                        .localized(settings.localizer)
                }
        }
    }
}
