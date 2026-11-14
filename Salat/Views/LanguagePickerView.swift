import SwiftUI

/// Fourteen languages plus "match my device" was half of the settings for a
/// choice made once. The list lives in its own sheet; the settings keep a row.
struct LanguagePickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    var body: some View {
        SheetScaffold(title: loc.t("settings.language"), icon: .globe) {
            row(.system, label: loc.t("settings.language.system"))
            ForEach(AppLanguage.shipped) { language in
                row(language, label: language.nativeName)
            }
        }
    }

    private func row(_ language: AppLanguage, label: String) -> some View {
        ChoiceRow(title: label, selected: settings.languagePreference == language) {
            LanguageCode(language: language)
        } action: {
            settings.languagePreference = language
        }
        // The code stays on the left even in Arabic: it is a column of
        // landmarks, not a sentence.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityIdentifier("settings.language.\(language.rawValue)")
    }
}

/// The Qur'anic voices. Only those there is a choice between: the adhkar are
/// carried by a single voice (Hisn al-Muslim), and a "choice" of one row would
/// just be noise.
struct ReciterPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    var body: some View {
        SheetScaffold(title: loc.t("audio.reciter"), icon: .headphones) {
            ForEach(Recitations.reciters(covering: "fatiha")) { reciter in
                ChoiceRow(
                    title: reciter.name,
                    // The style, always: Al-Husary is here twice (his teaching
                    // set and his murattal), and two rows carrying the same
                    // name and nothing else make the choice unreadable.
                    subtitle: loc.t(reciter.isTeaching ? "audio.style.teaching" : "audio.style.murattal"),
                    subtitleTint: reciter.isTeaching ? Theme.goldDeep : Theme.inkSoft,
                    selected: Recitations.reciter(id: settings.reciterID)?.id == reciter.id
                ) {
                    settings.reciterID = reciter.id
                }
                .accessibilityIdentifier("settings.reciter.\(reciter.id)")
            }
        }
    }
}

/// What the app is, and where its voices come from. The three credit lines
/// used to sit in the middle of the settings, under nine reciters; they are a
/// thing you read once, so they have a page.
struct AboutView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @State private var translator: String?

    var body: some View {
        SheetScaffold(title: loc.t("settings.about"), icon: .scroll) {
            Text(loc.t("settings.disclaimer"))
                .font(Theme.rounded(15.5, .semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

            SectionLabel(loc.t("settings.audio"))
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 12) {
                // Where each voice comes from, and the CC BY debt for the word
                // timings, paid where it counts: in the shipped app.
                ForEach(["settings.audio.credits", "settings.audio.adhkar", "settings.audio.timing"], id: \.self) { key in
                    Text(loc.t(key))
                        .font(Theme.rounded(14, .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()

            SectionLabel(loc.t("tab.quran"))
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 12) {
                Text(loc.t("settings.quran.text"))
                // A translation is somebody's reading of the text: the reader
                // is owed the name of whoever wrote the one on screen.
                if let translator {
                    Text(loc.t("settings.quran.translation", translator))
                }
            }
            .font(Theme.rounded(14, .semibold))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .task {
            let code = settings.resolvedLanguage.rawValue
            translator = await Task.detached { QuranTranslation.load(code: code)?.translator }.value
        }
    }
}
