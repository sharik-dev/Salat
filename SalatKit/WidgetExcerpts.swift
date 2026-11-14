import Foundation

/// Qur'an excerpts on the widget.
///
/// The reader composes a short list of **passages** (a run of verses inside
/// one surah) and the widget walks their verses, one a minute, the way it
/// walks the steps of the prayer.
///
/// The widget never opens the Qur'an itself. The fourteen `quran.*.json` weigh
/// seventeen megabytes and live in the app only; an extension is killed past
/// thirty. So the app **resolves** the passages into the handful of verses
/// they name (Arabic and the reader's translation, already looked up) and
/// leaves that small list in the shared suite. What the widget reads is text,
/// not references.

/// A run of verses inside one surah. What the reader picks.
public struct WidgetPassage: Codable, Hashable, Sendable, Identifiable {
    public let surah: Int
    public let from: Int
    public let to: Int

    /// Bounds are put in order and floored at verse 1 here rather than trusted:
    /// a passage read back from an older build must still mean something.
    public init(surah: Int, from: Int, to: Int) {
        let low = max(1, min(from, to))
        self.surah = surah
        self.from = low
        self.to = max(low, max(from, to))
    }

    public var id: String { "\(surah):\(from)-\(to)" }
    public var count: Int { to - from + 1 }

    /// "2:255", or "2:285-286" for a run. Digits and a colon: the one notation
    /// every language the app speaks already uses for a verse.
    public var reference: String {
        from == to ? "\(surah):\(from)" : "\(surah):\(from)-\(to)"
    }
}

/// One verse as the widget draws it, its text already looked up.
public struct WidgetVerse: Codable, Hashable, Sendable {
    public let surah: Int
    public let verse: Int
    /// The surah's name in Latin letters, as the Qur'an tab prints it.
    public let surahName: String
    public let arabic: String
    /// Empty in Arabic, where the text needs no translation.
    public let translation: String

    public init(surah: Int, verse: Int, surahName: String, arabic: String, translation: String) {
        self.surah = surah
        self.verse = verse
        self.surahName = surahName
        self.arabic = arabic
        self.translation = translation
    }

    public var reference: String { "\(surah):\(verse)" }
    /// What the widget prints where a prayer step prints its name.
    public var title: String { "\(surahName) \(reference)" }
}

public enum QuranExcerpts {

    /// What the widget shows the first time "Qur'an excerpts" is picked, so it
    /// never opens on an empty card: the Throne Verse and the three short
    /// surahs that close the book. A seed, not a decision, the list is the
    /// reader's from the first tap.
    public static let seed: [WidgetPassage] = [
        WidgetPassage(surah: 2, from: 255, to: 255),
        WidgetPassage(surah: 112, from: 1, to: 4),
        WidgetPassage(surah: 113, from: 1, to: 5),
        WidgetPassage(surah: 114, from: 1, to: 6)
    ]

    /// One-tap picks offered above the list of surahs. References only: the
    /// app names no passage itself, the text and the surah names all come from
    /// the Qur'an files.
    public static let suggestions: [WidgetPassage] = [
        WidgetPassage(surah: 1, from: 1, to: 7),
        WidgetPassage(surah: 2, from: 255, to: 255),
        WidgetPassage(surah: 2, from: 285, to: 286),
        WidgetPassage(surah: 59, from: 22, to: 24),
        WidgetPassage(surah: 94, from: 1, to: 8),
        WidgetPassage(surah: 103, from: 1, to: 3),
        WidgetPassage(surah: 112, from: 1, to: 4),
        WidgetPassage(surah: 113, from: 1, to: 5),
        WidgetPassage(surah: 114, from: 1, to: 6)
    ]

    // MARK: Resolving

    /// Passages into verses. Pure: the Qur'an is handed in (it lives in the
    /// app, not in the kit), so this can be tested without seventeen megabytes
    /// of fixtures.
    ///
    /// - `names`, `arabic` and `translation` are indexed by surah, 0-based,
    ///   as the files are.
    /// - A bound past the end of a surah is clamped, a surah that does not
    ///   exist is skipped: a stale pick must land somewhere, never crash.
    /// - A verse named by two passages appears once, where it first came up.
    ///   Twice would make the widget stay on it for two minutes in a row.
    public static func resolve(_ passages: [WidgetPassage],
                               names: [String],
                               arabic: [[String]],
                               translation: [[String]]?) -> [WidgetVerse] {
        var seen = Set<String>()
        var verses: [WidgetVerse] = []
        for passage in passages {
            let index = passage.surah - 1
            guard arabic.indices.contains(index), names.indices.contains(index),
                  !arabic[index].isEmpty else { continue }
            let last = min(passage.to, arabic[index].count)
            guard passage.from <= last else { continue }
            for number in passage.from...last {
                let key = "\(passage.surah):\(number)"
                guard seen.insert(key).inserted else { continue }
                var meaning = ""
                if let translation, translation.indices.contains(index),
                   translation[index].indices.contains(number - 1) {
                    meaning = translation[index][number - 1]
                }
                verses.append(WidgetVerse(surah: passage.surah, verse: number,
                                          surahName: names[index],
                                          arabic: arabic[index][number - 1],
                                          translation: meaning))
            }
        }
        return verses
    }

    // MARK: Storage (shared suite: the app writes, the widget reads)

    public static func passages() -> [WidgetPassage] {
        decode([WidgetPassage].self, SharedStore.Key.widgetPassages) ?? []
    }

    public static func savePassages(_ passages: [WidgetPassage]) {
        encode(passages, SharedStore.Key.widgetPassages)
    }

    public static func verses() -> [WidgetVerse] {
        decode([WidgetVerse].self, SharedStore.Key.widgetVerses) ?? []
    }

    /// `language` is stored beside the verses: the translation is baked in, so
    /// the app has to know which language it baked to tell when it went stale.
    public static func saveVerses(_ verses: [WidgetVerse], language: String) {
        encode(verses, SharedStore.Key.widgetVerses)
        SharedStore.defaults.set(language, forKey: SharedStore.Key.widgetVersesLanguage)
    }

    public static var versesLanguage: String? {
        SharedStore.defaults.string(forKey: SharedStore.Key.widgetVersesLanguage)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = SharedStore.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        SharedStore.defaults.set(data, forKey: key)
    }
}

// MARK: - The verse as a card

public extension PrayerStep {
    /// The image the widget shows beside a verse: the 3D Qur'an of the app's
    /// own tab, packed into the kit by `tools/pack_widget_art.py`.
    static let quranImage = "widget_quran"

    /// A verse dressed as a step, so the widget draws it with the very layout
    /// it already has: a title, the Arabic, the meaning. There is no phonetic
    /// (no transliteration ships with the Qur'an), which the card treats like
    /// any other empty text.
    init(verse: WidgetVerse) {
        self.init(id: "quran.\(verse.surah).\(verse.verse)", order: verse.verse,
                  image: PrayerStep.quranImage, posture: .standing,
                  repetitions: 1, spoken: true, arabic: verse.arabic,
                  name: verse.title, postureText: "", phonetic: "",
                  translation: verse.translation, note: "")
    }
}
