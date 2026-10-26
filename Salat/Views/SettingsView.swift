import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(OnboardingManager.self) private var onboarding
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(StudyReminders.self) private var reminders
    @Environment(\.loc) private var loc
    @State private var showLanguages = false

    var body: some View {
        @Bindable var settings = settings
        @Bindable var onboarding = onboarding

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(loc.t("tab.settings"))
                    .font(Theme.title(30))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                languageBlock
                remindersBlock
                audioBlock
                widgetBlock
                aboutBlock

                #if DEBUG
                developerBlock
                #endif

                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .task { if LaunchOptions.opensLanguages { showLanguages = true } }
        .sheet(isPresented: $showLanguages) {
            LanguagePickerView()
                .localized(settings.localizer)
                .environment(settings)
        }
    }

    // MARK: Language

    /// Quinze lignes empilées ici poussaient tout le reste des réglages sous
    /// la ligne de flottaison, pour un choix qu'on fait une fois. Le bloc ne
    /// garde que la langue en cours ; la liste vit dans `LanguagePickerView`.
    private var languageBlock: some View {
        block(loc.t("settings.language"), icon: "globe") {
            Button {
                showLanguages = true
            } label: {
                HStack(spacing: 12) {
                    Text(settings.resolvedLanguage.flagless)
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 30, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.resolvedLanguage.nativeName)
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                        // Suivre le téléphone est un réglage, pas une langue :
                        // sans cette ligne on ne saurait plus lequel des deux
                        // est coché.
                        if settings.languagePreference == .system {
                            Text(loc.t("settings.language.system"))
                                .font(Theme.label(10))
                                .foregroundStyle(Theme.gold)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .chunky(Theme.sand, depth: 4, haptic: .select)
            .accessibilityIdentifier("settings.language.open")
        }
    }

    // MARK: Reminders

    private var remindersBlock: some View {
        @Bindable var settings = settings

        return block(loc.t("settings.reminders"), icon: "bell") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.remindersOn) {
                    Text(loc.t("settings.reminders.toggle"))
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.gold)
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

                if settings.remindersOn {
                    HStack {
                        Text(loc.t("settings.reminders.time"))
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        DatePicker("", selection: $settings.reminderTime,
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Theme.gold)
                            .onChange(of: settings.reminderHour) { _, _ in resync() }
                            .onChange(of: settings.reminderMinute) { _, _ in resync() }
                    }
                }

                Text(loc.t("settings.reminders.hint"))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if reminders.authorization == .denied {
                    Text(loc.t("settings.reminders.denied"))
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(loc.t("settings.reminders.open"))
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                    }
                    .chunky(Theme.sand, depth: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func resync() {
        Task { await reminders.sync(with: settings) }
    }

    // MARK: Widget

    private var widgetBlock: some View {
        block(loc.t("settings.widget.title"), icon: "square.grid.2x2") {
            Text(loc.t("settings.widget.hint"))
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Audio

    private var audioBlock: some View {
        @Bindable var settings = settings

        return block(loc.t("settings.audio"), icon: "waveform") {
            VStack(alignment: .leading, spacing: 10) {
                // Only the voices there is a choice between — the Qur'anic
                // reciters. The adhkar are carried by a single voice (Hisn
                // al-Muslim), and a "choice" of one row would just be noise.
                ForEach(Recitations.reciters(covering: "fatiha")) { reciter in
                    reciterRow(reciter)
                }

                Text(loc.t("settings.audio.credits"))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                // Where the adhkar voice comes from — a different source than
                // the Qur'anic verses, so it gets its own sentence.
                Text(loc.t("settings.audio.adhkar"))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                // The CC BY debt for the word timings, paid where it counts:
                // in the shipped app, not in a repo markdown file.
                Text(loc.t("settings.audio.timing"))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                // Only offered when there is something to delete: a button that
                // does nothing still makes the user wonder what it did.
                if recordingCount > 0 {
                    Divider().background(Theme.border)
                    Text(loc.t("settings.audio.recordings", recordingCount))
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSoft)
                    Button {
                        recorder.deleteAll()
                    } label: {
                        Text(loc.t("settings.audio.clear"))
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                    }
                    .chunky(Theme.sand, depth: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Read through `recorder.revision` so the count drops the moment the files
    /// go — the filesystem is invisible to SwiftUI on its own.
    private var recordingCount: Int {
        _ = recorder.revision
        return VoiceRecorder.count
    }

    private func reciterRow(_ reciter: Reciter) -> some View {
        let isOn = Recitations.reciter(id: settings.reciterID)?.id == reciter.id
        return Button {
            withAnimation(Theme.spring) { settings.reciterID = reciter.id }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reciter.name)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                    // The style, always: Al-Husary is here twice (his teaching
                    // set and his murattal), and two rows carrying the same
                    // name and nothing else make the choice unreadable.
                    Text(loc.t(reciter.isTeaching ? "audio.style.teaching" : "audio.style.murattal"))
                        .font(Theme.label(10))
                        .foregroundStyle(reciter.isTeaching ? Theme.gold : Theme.inkSoft)
                }
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .chunky(isOn ? Theme.goldSoft : Theme.sand, depth: isOn ? 4 : 0, haptic: .select)
    }

    // MARK: About

    private var aboutBlock: some View {
        block(loc.t("settings.about"), icon: "info.circle") {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc.t("settings.disclaimer"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    withAnimation(Theme.spring) { settings.resetProgress() }
                } label: {
                    Text(loc.t("settings.reset_progress"))
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                }
                .chunky(Theme.sand, depth: 4)

                // GDPR: users in the EU must be able to change their ad consent.
                if Ads.shared.privacyOptionsNeeded {
                    Button { Ads.shared.showPrivacyOptions() } label: {
                        Text(loc.t("settings.ad_privacy"))
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                    }
                    .chunky(Theme.sand, depth: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Developer

    #if DEBUG
    private var developerBlock: some View {
        @Bindable var onboarding = onboarding

        return block(loc.t("settings.developer"), icon: "hammer.fill") {
            VStack(spacing: 12) {
                HStack {
                    Text(loc.t("settings.devmode"))
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("ACTIVE")
                        .font(Theme.label(10))
                        .foregroundStyle(Theme.gold)
                }
                Toggle(isOn: $onboarding.alwaysShowOnboarding) {
                    Text(loc.t("settings.always_onboarding"))
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.gold)
                .onChange(of: onboarding.alwaysShowOnboarding) { _, on in
                    if on { onboarding.reset() }
                }
            }
        }
    }
    #endif

    // MARK: Block chrome

    private func block<Content: View>(_ title: String, icon: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title.uppercased()).font(Theme.label(9)).tracking(0.8)
            }
            .foregroundStyle(Theme.gold)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
