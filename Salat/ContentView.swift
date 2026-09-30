import SwiftUI

/// Raised by a screen that needs the whole height — a drill round mid-flight.
/// The floating bar is drawn here, above every tab, so only a preference can
/// reach it from a pushed screen.
struct TabBarHiddenKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StudyReminders.self) private var reminders
    @State private var selectedTab: AppTab = LaunchOptions.startTab
    @State private var tabBarHidden = false

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
            .onPreferenceChange(TabBarHiddenKey.self) { hidden in
                withAnimation(Theme.spring) { tabBarHidden = hidden }
            }

            VStack(spacing: 0) {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)
            // Slid off rather than removed: coming back from a round, the bar
            // rises from where it left instead of popping into place.
            .offset(y: tabBarHidden ? 160 : 0)
            .allowsHitTesting(!tabBarHidden)
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
