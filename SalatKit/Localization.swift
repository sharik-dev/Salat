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

    public var id: String { rawValue }

    /// Languages we actually ship content for. Adding one is a matter of
    /// dropping `steps.<code>.json` + `ui.<code>.json` in Resources and adding
    /// a case here — nothing else in the app knows about languages.
    public static var shipped: [AppLanguage] { [.en, .fr, .ar] }

    public var nativeName: String {
        switch self {
        case .system: return "—"
        case .en:     return "English"
        case .fr:     return "Français"
        case .ar:     return "العربية"
        }
    }

    public var flagless: String {
        switch self {
        case .system: return "globe"
        case .en:     return "EN"
        case .fr:     return "FR"
        case .ar:     return "ع"
        }
    }

    public var isRTL: Bool { self == .ar }

    /// What the device asks for, narrowed to what we ship, English otherwise.
    public static func resolvedFromSystem() -> AppLanguage {
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2)).lowercased()
            if let match = shipped.first(where: { $0.rawValue == code }) { return match }
        }
        return .en
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
        public static let learned  = "progress.learned"
        public static let stepSeconds = "practice.stepSeconds"
        public static let reciter = "audio.reciter"
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
