import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StudyReminders.self) private var reminders
    @State private var selectedTab: AppTab = LaunchOptions.startTab

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper.ignoresSafeArea()
            StarLattice().ignoresSafeArea()

            Group {
                #if DEBUG
                if LaunchOptions.showsWidgetPreview {
                    WidgetPreviewView()
                } else {
                    tabContent
                }
                #else
                tabContent
                #endif
            }
            .transition(.opacity)

            VStack(spacing: 0) {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)
        }
        .localized(settings.localizer)
        // A tapped reminder lands on the step it named, so the notification and
        // the screen tell the same story. `LearnView` opens the sheet and
        // clears the flag.
        .onChange(of: reminders.pendingStepID) { _, id in
            if id != nil { withAnimation(Theme.spring) { selectedTab = .learn } }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .learn:    LearnView()
        case .practice: ReviseHubView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .environment(OnboardingManager())
        .environment(RecitationPlayer())
        .environment(VoiceRecorder())
        .environment(StudyReminders())
}
