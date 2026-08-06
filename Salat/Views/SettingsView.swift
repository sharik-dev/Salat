import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(OnboardingManager.self) private var onboarding
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(\.loc) private var loc

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
    }

    // MARK: Language

    private var languageBlock: some View {
        @Bindable var settings = settings

        return block(loc.t("settings.language"), icon: "globe") {
            VStack(spacing: 8) {
                languageRow(.system, label: loc.t("settings.language.system"))
                ForEach(AppLanguage.shipped) { language in
                    languageRow(language, label: language.nativeName)
                }
            }
        }
    }

    private func languageRow(_ language: AppLanguage, label: String) -> some View {
        let isOn = settings.languagePreference == language
        return Button {
            withAnimation(Theme.spring) { settings.languagePreference = language }
        } label: {
            HStack {
                Text(label)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
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
                ForEach(Recitations.reciters) { reciter in
                    reciterRow(reciter)
                }

                Text(loc.t("settings.audio.credits"))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

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
                    if reciter.isTeaching {
                        Text(loc.t("audio.style.teaching"))
                            .font(Theme.label(10))
                            .foregroundStyle(Theme.gold)
                    }
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
