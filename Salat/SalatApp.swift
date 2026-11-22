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
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // The Taptic engine and the two sounds are woken here: a cold
        // generator answers a hundred milliseconds late, which is exactly long
        // enough for the first buzz of the session to land after the button.
        Theme.registerPixelFont()
        Haptic.warmUp()
        Telemetry.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(onboarding)
                .environment(player)
                .environment(recorder)
                .environment(reminders)
                .environment(store)
                .tint(Theme.primary)
                .task { store.start() }
                // Rewritten at every return to the app rather than only when
                // the switch is touched: the plan names steps that are still
                // unlearned, and that changes as the user learns them.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await reminders.sync(with: settings) }
                    // A renewal, a refund or a cancellation happens while the
                    // app is away: the App Store is asked again at each return.
                    Task { await store.refresh() }
                }
                // Pubs en pause (`Ads.enabled`, 22/11/2026) : ces deux appels ne
                // font rien tant qu'elles sont coupées, ils restent pour les rallumer.
                .onChange(of: onboarding.shouldShowOnboarding, initial: true) { _, showing in
                    if !showing { Ads.shared.start() }
                }
                .onChange(of: store.isPremium) { _, premium in
                    if !premium, !onboarding.shouldShowOnboarding { Ads.shared.start() }
                }
        }
    }
}
