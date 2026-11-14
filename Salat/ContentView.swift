import SwiftUI

/// Raised by a screen that needs the whole height — a drill round mid-flight.
/// The tab bar is laid out here, under every tab, so only a preference can
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
    @Environment(OnboardingManager.self) private var onboarding
    @Environment(Store.self) private var store
    @State private var selectedTab: AppTab = LaunchOptions.startTab
    @State private var tabBarHidden = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onPreferenceChange(TabBarHiddenKey.self) { hidden in
                    withAnimation(Theme.spring) { tabBarHidden = hidden }
                }

                // Docked, not floating: the page ends where the bar begins, so
                // nothing ever has to scroll out from underneath it.
                if !tabBarHidden {
                    NavBar(selectedTab: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .ignoresSafeArea(.keyboard)
            // While the welcome covers the app, the app is not there for
            // VoiceOver either — nor for a UI test waiting on a tab.
            .accessibilityHidden(onboarding.shouldShowOnboarding)

            // An overlay rather than a sheet, like SelfTransfer's: the welcome
            // owns the whole screen, sky included, and leaves by sliding down.
            if onboarding.shouldShowOnboarding {
                OnboardingView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.1), value: onboarding.shouldShowOnboarding)
        .localized(settings.localizer)
        // A tapped reminder lands on the step it named, so the notification and
        // the screen tell the same story. `LearnView` opens the sheet and
        // clears the flag.
        .onChange(of: reminders.pendingStepID) { _, id in
            if id != nil { withAnimation(Theme.spring) { selectedTab = .learn } }
        }
        // `-openPaywall 1`. Raised once the view is on screen and not from
        // `Store.init`: a sheet asked for before there is a window to present
        // it from is sometimes simply dropped.
        .task {
            if LaunchOptions.opensPaywall {
                try? await Task.sleep(for: .seconds(0.4))
                store.present(LaunchOptions.paywallReason ?? .manual)
            }
        }
        // `-forceNudge paywall|review`: the forced decision normally waits for
        // a pause, and a pause needs a finger (a page closed, a round played).
        // Nobody is here to tap, so one is declared shortly after launch.
        .task {
            if LaunchOptions.forcedNudge != nil, !onboarding.shouldShowOnboarding {
                try? await Task.sleep(for: .seconds(1.5))
                Nudges.shared.pause(.stepClosed)
            }
        }
        // Seen by hand or offered, the paywall resets the wait before the app
        // offers it again on its own.
        .onChange(of: store.showsPaywall) { _, shown in
            if shown { Nudges.shared.paywallSeen() }
        }
        // Salat Premium. One sheet for the whole app, raised by `Store`: the
        // shortcuts of three tabs and a tap on the locked widget all end here.
        .sheet(isPresented: paywallShown) {
            PaywallView()
                .localized(settings.localizer)
                .environment(settings)
                .environment(store)
                .presentationDragIndicator(.visible)
        }
        // A locked widget on the home screen opens the app on its paywall
        // (`Premium.unlockURL`). Someone who has subscribed since has nothing
        // to be sold: the app simply opens.
        .onOpenURL { url in
            if url == Premium.unlockURL, !store.isPremium { store.showsPaywall = true }
        }
    }

    /// Never over the welcome: the first screen of the app is not a price.
    private var paywallShown: Binding<Bool> {
        Binding(get: { store.showsPaywall && !onboarding.shouldShowOnboarding },
                set: { store.showsPaywall = $0 })
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .learn:    LearnView()
        case .quran:    QuranView()
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
        .environment(Store())
}
