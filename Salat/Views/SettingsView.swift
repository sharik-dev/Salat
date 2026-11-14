import SwiftUI

/// Settings as a handful of rows. Everything that used to unfold on this page
/// — fourteen languages, nine reciters, three paragraphs of credits — now sits
/// behind the row that names it, so the page fits a screen and each row says
/// its current value at a glance.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(OnboardingManager.self) private var onboarding
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(StudyReminders.self) private var reminders
    @Environment(Store.self) private var store
    @Environment(\.loc) private var loc
    @State private var showLanguages = false
    @State private var showReciters = false
    @State private var showAbout = false

    var body: some View {
        VStack(spacing: 0) {
            Banner(title: loc.t("tab.settings"),
                   subtitle: nil, subtitleAction: nil, subtitleID: nil, back: nil) {
                LofiIcon(.gear, size: 96, interval: 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    premiumCard
                    preferencesCard
                    remindersCard
                    if recordingCount > 0 { recordingsCard }
                    aboutCard

                    #if DEBUG
                    developerCard
                    #endif
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            if LaunchOptions.opensLanguages { showLanguages = true }
            if LaunchOptions.opensReciters { showReciters = true }
            if LaunchOptions.opensAbout { showAbout = true }
        }
        .sheet(isPresented: $showLanguages) { sheet { LanguagePickerView() } }
        .sheet(isPresented: $showReciters) { sheet { ReciterPickerView() } }
        .sheet(isPresented: $showAbout) { sheet { AboutView() } }
    }

    private func sheet<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .localized(settings.localizer)
            .environment(settings)
    }

    // MARK: Salat Premium

    /// The offer while it is one; once subscribed, a row that says so and
    /// leads to the same screen, where the subscription is managed.
    @ViewBuilder
    private var premiumCard: some View {
        if store.isPremium {
            SettingsRow(icon: .sparkle, title: loc.t("premium.title"),
                        value: loc.t("premium.active"), valueTint: Theme.primaryDeep) {
                store.showsPaywall = true
            }
            .card(padding: 0)
            .accessibilityIdentifier("settings.premium.active")
        } else {
            PremiumShortcut(place: "settings.premium")
        }
    }

    // MARK: Language and voice

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            SettingsRow(icon: .globe, title: loc.t("settings.language"),
                        value: settings.resolvedLanguage.nativeName,
                        // Following the phone is a setting, not a language:
                        // without this line you could not tell which of the two
                        // is ticked.
                        note: settings.languagePreference == .system ? loc.t("settings.language.system") : nil) {
                showLanguages = true
            }
            .accessibilityIdentifier("settings.language.open")

            RowDivider().padding(.leading, 78)

            SettingsRow(icon: .headphones, title: loc.t("audio.reciter"),
                        value: Recitations.reciter(id: settings.reciterID)?.name ?? "") {
                showReciters = true
            }
            .accessibilityIdentifier("settings.reciter.open")
        }
        .card(padding: 0)
    }

    // MARK: Reminders

    private var remindersCard: some View {
        @Bindable var settings = settings

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                IconTile(icon: .bell, animated: settings.remindersOn)
                Toggle(isOn: $settings.remindersOn) {
                    Text(loc.t("settings.reminders.toggle"))
                        .font(Theme.rounded(16.5, .heavy))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.primary)
                .accessibilityIdentifier("settings.reminders.toggle")
                // The permission is asked here, at the moment the user says
                // yes, and never at launch. A refusal puts the switch back
                // rather than leaving it on over a system that will post
                // nothing.
                .onChange(of: settings.remindersOn) { _, on in
                    Task {
                        if on, reminders.authorization == .notDetermined {
                            _ = await reminders.requestAuthorization()
                        }
                        if on, reminders.authorization != .authorized {
                            settings.remindersOn = false
                        }
                        await reminders.sync(with: settings)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if settings.remindersOn {
                RowDivider().padding(.leading, 78)

                HStack {
                    Text(loc.t("settings.reminders.time"))
                        .font(Theme.rounded(16, .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    DatePicker("", selection: $settings.reminderTime,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Theme.primary)
                        .onChange(of: settings.reminderHour) { _, _ in resync() }
                        .onChange(of: settings.reminderMinute) { _, _ in resync() }
                }
                .padding(.leading, 78)
                .padding(.trailing, 14)
                .padding(.vertical, 10)

                // Said once the switch is on: it describes what is about to
                // happen, and before that it is a paragraph about nothing.
                Text(loc.t("settings.reminders.hint"))
                    .font(Theme.rounded(13, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }

            if reminders.authorization == .denied {
                RowDivider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc.t("settings.reminders.denied"))
                        .font(Theme.rounded(13.5, .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(loc.t("settings.reminders.open"))
                    }
                    .buttonStyle(.cta(.secondary, height: 46, haptic: .tap))
                }
                .padding(16)
            }
        }
        .card(padding: 0)
        .animation(Theme.spring, value: settings.remindersOn)
    }

    private func resync() {
        Task { await reminders.sync(with: settings) }
    }

    // MARK: Recordings

    /// Only offered when there is something to delete: a button that does
    /// nothing still makes the user wonder what it did.
    private var recordingsCard: some View {
        SettingsRow(icon: .mic, title: loc.t("settings.audio.recordings", recordingCount),
                    value: loc.t("settings.audio.clear"), valueTint: Theme.danger, chevron: false) {
            recorder.deleteAll()
        }
        .card(padding: 0)
    }

    /// Read through `recorder.revision` so the count drops the moment the files
    /// go — the filesystem is invisible to SwiftUI on its own.
    private var recordingCount: Int {
        _ = recorder.revision
        return VoiceRecorder.count
    }

    // MARK: About

    private var aboutCard: some View {
        VStack(spacing: 0) {
            SettingsRow(icon: .scroll, title: loc.t("settings.about")) { showAbout = true }
                .accessibilityIdentifier("settings.about.open")

            // GDPR: users in the EU must be able to change their ad consent.
            if Ads.shared.privacyOptionsNeeded {
                RowDivider().padding(.leading, 78)
                SettingsRow(icon: .shield, title: loc.t("settings.ad_privacy")) {
                    Ads.shared.showPrivacyOptions()
                }
            }

            RowDivider().padding(.leading, 78)

            SettingsRow(icon: .trash, title: loc.t("settings.reset_progress"), chevron: false) {
                withAnimation(Theme.spring) { settings.resetProgress() }
            }
            .accessibilityIdentifier("settings.reset")
        }
        .card(padding: 0)
    }

    // MARK: Developer

    #if DEBUG
    private var developerCard: some View {
        @Bindable var onboarding = onboarding

        return VStack(spacing: 14) {
            Toggle(isOn: $onboarding.alwaysShowOnboarding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("settings.always_onboarding"))
                        .font(Theme.rounded(15.5, .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(loc.t("settings.developer"))
                        .font(Theme.rounded(12, .heavy))
                        .foregroundStyle(Theme.goldDeep)
                }
            }
            .tint(Theme.primary)
            .onChange(of: onboarding.alwaysShowOnboarding) { _, on in
                if on { onboarding.reset() }
            }

            RowDivider()

            // Premium without the App Store: the only way to see the unlocked
            // widget on a real phone before the subscription can be bought.
            Toggle(isOn: Binding(get: { store.isPremium },
                                 set: { store.setDebugPremium($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("premium.title"))
                        .font(Theme.rounded(15.5, .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(loc.t("settings.developer"))
                        .font(Theme.rounded(12, .heavy))
                        .foregroundStyle(Theme.goldDeep)
                }
            }
            .tint(Theme.primary)
            .accessibilityIdentifier("settings.debug.premium")
        }
        .card()
    }
    #endif
}

// MARK: - Row

/// A settings row: the object, the name of the setting, and — when it has one —
/// its current value underneath, so nothing has to be opened just to be read.
private struct SettingsRow: View {
    let icon: Icon3D
    let title: String
    var value: String?
    var valueTint: Color = Theme.inkSoft
    var note: String?
    var chevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(icon: icon)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.rounded(16.5, .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if let value, !value.isEmpty {
                        Text(value)
                            .font(Theme.rounded(14, .heavy))
                            .foregroundStyle(valueTint)
                            .lineLimit(1)
                    }
                    if let note {
                        Text(note)
                            .font(Theme.rounded(12, .heavy))
                            .foregroundStyle(Theme.goldDeep)
                    }
                }

                Spacer(minLength: 0)

                if chevron {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .simultaneousGesture(TapGesture().onEnded { Haptic.tap.play() })
    }
}
