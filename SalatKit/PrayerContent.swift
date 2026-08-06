import Foundation

private final class SalatKitBundleToken {}

// MARK: - Model

public enum Posture: String, Codable, Sendable, CaseIterable {
    case standing
    case handsRaised = "hands_raised"
    case bowing
    case prostrating
    case sitting

    /// Which family the step belongs to, for grouping in the list.
    public var sectionKey: String {
        switch self {
        case .standing, .handsRaised: return "learn.section.standing"
        case .bowing:                 return "learn.section.bowing"
        case .prostrating:            return "learn.section.prostration"
        case .sitting:                return "learn.section.sitting"
        }
    }

    /// SF Symbol used when no illustration has been generated yet.
    public var symbol: String {
        switch self {
        case .standing:     return "figure.stand"
        case .handsRaised:  return "hands.and.sparkles"
        case .bowing:       return "figure.bowling"
        case .prostrating:  return "figure.flexibility"
        case .sitting:      return "figure.seated.side"
        }
    }
}

public struct PrayerStep: Identifiable, Hashable, Sendable {
    public let id: String
    public let order: Int
    public let image: String
    public let posture: Posture
    public let repetitions: Int
    public let spoken: Bool
    public let arabic: String

    public let name: String
    public let postureText: String
    public let phonetic: String
    public let translation: String
    public let note: String

    public init(id: String, order: Int, image: String, posture: Posture,
                repetitions: Int, spoken: Bool, arabic: String, name: String,
                postureText: String, phonetic: String, translation: String, note: String) {
        self.id = id
        self.order = order
        self.image = image
        self.posture = posture
        self.repetitions = repetitions
        self.spoken = spoken
        self.arabic = arabic
        self.name = name
        self.postureText = postureText
        self.phonetic = phonetic
        self.translation = translation
        self.note = note
    }

    /// Arabic is one text with newline-separated lines; views render them
    /// line by line so the phonetic and the translation stay aligned with it.
    public var arabicLines: [String] { arabic.components(separatedBy: "\n") }
    public var phoneticLines: [String] { phonetic.components(separatedBy: "\n") }
    public var translationLines: [String] { translation.components(separatedBy: "\n") }
}

// MARK: - Decoding shapes

private struct BaseFile: Decodable {
    struct Step: Decodable {
        let id: String
        let order: Int
        let image: String
        let posture: Posture
        let repetitions: Int
        let spoken: Bool
        let arabic: String
    }
    let steps: [Step]
}

private struct LocaleFile: Decodable {
    struct Step: Decodable {
        let name: String
        let posture: String
        let phonetic: String
        let translation: String
        let note: String
    }
    let steps: [String: Step]
}

// MARK: - Loader

public enum PrayerContent {
    private static var cache: [AppLanguage: [PrayerStep]] = [:]
    private static let lock = NSLock()

    public static func steps(for language: AppLanguage) -> [PrayerStep] {
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[language] { return hit }
        let built = build(language)
        cache[language] = built
        return built
    }

    public static func step(id: String, language: AppLanguage) -> PrayerStep? {
        steps(for: language).first { $0.id == id }
    }

    private static func build(_ language: AppLanguage) -> [PrayerStep] {
        guard let base: BaseFile = decode("steps.base") else { return [] }
        // English is the safety net: a locale file missing an entry falls back
        // to English rather than showing an empty card.
        let localized: LocaleFile? = decode("steps.\(language.rawValue)")
        let english: LocaleFile? = language == .en ? nil : decode("steps.en")

        return base.steps
            .sorted { $0.order < $1.order }
            .compactMap { s in
                guard let text = localized?.steps[s.id] ?? english?.steps[s.id] else { return nil }
                return PrayerStep(
                    id: s.id,
                    order: s.order,
                    image: s.image,
                    posture: s.posture,
                    repetitions: s.repetitions,
                    spoken: s.spoken,
                    arabic: s.arabic,
                    name: text.name,
                    postureText: text.posture,
                    phonetic: text.phonetic,
                    translation: text.translation,
                    note: text.note
                )
            }
    }

    private static func decode<T: Decodable>(_ resource: String) -> T? {
        let bundle = Bundle(for: SalatKitBundleToken.self)
        guard let url = bundle.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Progress

/// Where progress lives now: `StudyLog` in `StudyLog.swift`, which keeps three
/// states and the dates they were reached, instead of a flat list of ticks.
/// This shim is what is left of the two-state version — kept so nothing outside
/// has to know the shape changed.
public enum Progress {
    public static var learned: Set<String> { StudyLog.load().known }

    public static func reset() { StudyLog.clear() }
}
