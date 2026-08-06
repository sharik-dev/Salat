import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
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
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .learn:    LearnView()
        case .practice: PracticeView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .environment(OnboardingManager())
}
