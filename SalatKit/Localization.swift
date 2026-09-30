import SwiftUI

/// Bundle token — resolves to the app bundle in the app and to the extension
/// bundle in the widget, both of which carry their own copy of the resources.
private final class SalatKitBundleToken {}

// MARK: - Languages

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case en
    case fr
    case ar
    case es
    case pt
    case de
    case it
    case nl
    case tr
    case id
    case ms
    case ru
    case ur
    case bn

    public var id: String { rawValue }

    /// Languages we actually ship content for. Adding one is a matter of
    /// dropping `steps.<code>.json` + `ui.<code>.json` in Resources and adding
    /// a case here — nothing else in the app knows about languages.
    /// The order is the order of the picker: the two languages the app was
    /// written in first, then the rest by how many people pray in them.
    public static var shipped: [AppLanguage] {
        [.en, .fr, .ar, .id, .ms, .ur, .bn, .tr, .ru, .es, .pt, .de, .it, .nl]
    }

    public var nativeName: String {
        switch self {
        case .system: return "—"
        case .en:     return "English"
        case .fr:     return "Français"
        case .ar:     return "العربية"
        case .es:     return "Español"
        case .pt:     return "Português"
        case .de:     return "Deutsch"
        case .it:     return "Italiano"
        case .nl:     return "Nederlands"
        case .tr:     return "Türkçe"
        case .id:     return "Bahasa Indonesia"
        case .ms:     return "Bahasa Melayu"
        case .ru:     return "Русский"
        case .ur:     return "اردو"
        case .bn:     return "বাংলা"
        }
    }

    public var flagless: String {
        switch self {
        case .system: return "globe"
        case .ar:     return "ع"
        case .ur:     return "ار"
        case .bn:     return "বা"
        case .ru:     return "РУ"
        default:      return rawValue.uppercased()
        }
    }

    /// Arabic and Urdu are written right to left. Persian would join them the
    /// day it ships; Bengali would not.
    public var isRTL: Bool { self == .ar || self == .ur }

    /// What the device asks for, narrowed to what we ship, English otherwise.
    /// The whole preferred list is walked, not just the first entry: someone
    /// whose phone is in Norwegian with Turkish second gets Turkish rather
    /// than the English fallback.
    public static func resolvedFromSystem() -> AppLanguage {
        for identifier in devicePreferredLanguages {
            // `fr-CA`, `pt-BR`, `zh-Hans-CN`: only the language subtag matters,
            // and `Locale` extracts it more reliably than `prefix(2)` does.
            guard let code = Locale(identifier: identifier).language.languageCode?.identifier
                    .lowercased() else { continue }
            if let match = shipped.first(where: { $0.rawValue == code }) { return match }
            // Indonesian still travels under its pre-1989 code in some places.
            if code == "in" { return .id }
        }
        return .en
    }

    /// The languages the phone is actually set to, in the user's own order.
    ///
    /// Not `Locale.preferredLanguages`: iOS narrows that list to the
    /// localizations the *bundle* declares, and this app ships none — its
    /// content is JSON, not `.lproj`. A phone set to Turkish therefore reported
    /// English, and the whole detection collapsed onto the fallback. The raw
    /// `AppleLanguages` list is the unfiltered one.
    static var devicePreferredLanguages: [String] {
        UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
    }
}

// MARK: - Shared storage (app ⇄ widget)

public enum SharedStore {
    public static let suiteName = "group.com.salat"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public enum Key {
        public static let language = "app.language"
        /// The two-state list of the first version. Still written, never read
        /// except to migrate — see `StudyLog`.
        public static let learned  = "progress.learned"
        public static let studyLog = "progress.log"
        public static let stepSeconds = "practice.stepSeconds"
        public static let reciter = "audio.reciter"
        public static let remindersOn = "reminders.on"
        public static let reminderHour = "reminders.hour"
        public static let reminderMinute = "reminders.minute"
        public static let widgetScope = "widget.scope"
        public static let widgetPinnedStep = "widget.pinnedStep"
        public static let widgetFocus = "widget.focus"
    }

    public static var language: AppLanguage {
        get {
            let raw = defaults.string(forKey: Key.language) ?? AppLanguage.system.rawValue
            let stored = AppLanguage(rawValue: raw) ?? .system
            return stored == .system ? .resolvedFromSystem() : stored
        }
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    public static var storedLanguagePreference: AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system
    }
}

// MARK: - Localizer

/// A value, not a singleton: the language can change at runtime and every view
/// that holds one re-renders. `%d` is the only placeholder we support.
public struct Localizer: Equatable, Sendable {
    public let language: AppLanguage
    private let strings: [String: String]
    private let fallback: [String: String]

    public init(language: AppLanguage) {
        self.language = language
        self.strings = Localizer.load(language.rawValue)
        self.fallback = language == .en ? [:] : Localizer.load("en")
    }

    public func callAsFunction(_ key: String) -> String { t(key) }

    public func t(_ key: String) -> String {
        strings[key] ?? fallback[key] ?? key
    }

    public func t(_ key: String, _ number: Int) -> String {
        String(format: t(key), number)
    }

    public func t(_ key: String, _ a: Int, _ b: Int) -> String {
        String(format: t(key), a, b)
    }

    /// `%@` filled by hand rather than through `String(format:)`: the argument
    /// is always a step name coming from our own content files, and a format
    /// string translated by a human is exactly where a stray `%` shows up.
    public func t(_ key: String, _ text: String) -> String {
        t(key).replacingOccurrences(of: "%@", with: text)
    }

    public var layoutDirection: LayoutDirection { language.isRTL ? .rightToLeft : .leftToRight }

    public var locale: Locale { Locale(identifier: language.rawValue) }

    private static func load(_ code: String) -> [String: String] {
        let bundle = Bundle(for: SalatKitBundleToken.self)
        guard let url = bundle.url(forResource: "ui.\(code)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }
}

// MARK: - Environment

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue = Localizer(language: SharedStore.language)
}

public extension EnvironmentValues {
    var loc: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}

public extension View {
    /// Applies the language *and* everything that follows from it: text
    /// direction and locale-aware formatting.
    func localized(_ localizer: Localizer) -> some View {
        self.environment(\.loc, localizer)
            .environment(\.layoutDirection, localizer.layoutDirection)
            .environment(\.locale, localizer.locale)
    }
}
