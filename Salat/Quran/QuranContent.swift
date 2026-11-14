import Foundation

/// The text behind the *Qur'an* tab. Everything here is data written by
/// `tools/fetch-quran.py` (`quran.base.json`, `quran.<code>.json`); nothing in
/// the app edits a verse, cuts one or joins two.

struct Surah: Identifiable, Hashable, Decodable, Sendable {
    let number: Int
    /// As printed in a mushaf, "سورة" included.
    let name: String
    /// The name in Latin letters. One spelling for the fourteen languages: a
    /// surah's name is a proper noun, not a word to translate.
    let latin: String
    let meccan: Bool
    let verses: Int

    var id: Int { number }

    /// Every surah opens on the basmala except the Fatiha, where it *is* the
    /// first verse, and at-Tawba, which has none.
    var hasBasmala: Bool { number != 1 && number != 9 }

    /// The name alone, for a list where "surah" is already the title.
    var shortName: String {
        name.split(separator: " ").dropFirst().joined(separator: " ")
    }
}

/// One screen of the feed: a surah's opening, a verse, or — when the verse is
/// long — one excerpt of it.
struct QuranPage: Identifiable, Hashable, Sendable {
    /// Its rank in the feed, which is also what the scroll view tracks.
    let id: Int
    let surah: Int
    /// 1-based; 0 is the opening page.
    let verse: Int
    /// Which excerpt of the verse this screen shows, and out of how many.
    /// A short verse is one excerpt.
    var part = 0
    var parts = 1

    var isOpening: Bool { verse == 0 }
    var isFirstPart: Bool { part == 0 }
}

struct Quran: Sendable {
    let basmala: String
    let surahs: [Surah]
    /// Surah by surah, verse by verse.
    let arabic: [[String]]
    /// The same verses cut into the excerpts the feed shows (`QuranExcerpt`):
    /// surah, verse, excerpt. Joined back with spaces, an entry is its verse.
    let excerpts: [[[String]]]
    /// The whole book as one list of screens: for each surah, its opening and
    /// then its verses, a long verse taking several screens. One list rather
    /// than one per surah, so the thumb goes from the last verse of a surah
    /// into the next without meeting an edge.
    let pages: [QuranPage]
    /// Where each surah's opening sits in `pages`.
    private let starts: [Int]
    /// Where each verse's first excerpt sits in `pages`: surah, verse.
    private let verseStarts: [[Int]]

    private struct File: Decodable {
        let basmala: String
        let surahs: [Surah]
        let verses: [[String]]
    }

    /// Nil only if the file is missing from the bundle, which the tests catch.
    static let shared: Quran? = {
        guard let url = Bundle.main.url(forResource: "quran.base", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data),
              file.surahs.count == file.verses.count else { return nil }
        return Quran(basmala: file.basmala, surahs: file.surahs, arabic: file.verses)
    }()

    init(basmala: String, surahs: [Surah], arabic: [[String]]) {
        self.basmala = basmala
        self.surahs = surahs
        self.arabic = arabic
        let excerpts = arabic.map { $0.map(QuranExcerpt.parts(of:)) }
        self.excerpts = excerpts
        var pages: [QuranPage] = []
        var starts: [Int] = []
        var verseStarts: [[Int]] = []
        for (index, surah) in surahs.enumerated() {
            starts.append(pages.count)
            pages.append(QuranPage(id: pages.count, surah: surah.number, verse: 0))
            var firsts: [Int] = []
            for (verse, parts) in excerpts[index].enumerated() {
                firsts.append(pages.count)
                for part in parts.indices {
                    pages.append(QuranPage(id: pages.count, surah: surah.number, verse: verse + 1,
                                           part: part, parts: parts.count))
                }
            }
            verseStarts.append(firsts)
        }
        self.pages = pages
        self.starts = starts
        self.verseStarts = verseStarts
    }

    func surah(_ number: Int) -> Surah { surahs[min(max(number, 1), surahs.count) - 1] }

    /// The feed rank of a verse's first screen (verse 0 is the surah's
    /// opening), clamped to what exists: a stale bookmark must land
    /// somewhere, never crash.
    func pageID(surah: Int, verse: Int) -> Int {
        let s = min(max(surah, 1), surahs.count)
        let v = min(max(verse, 0), arabic[s - 1].count)
        return v == 0 ? starts[s - 1] : verseStarts[s - 1][v - 1]
    }

    func page(_ id: Int?) -> QuranPage {
        pages[min(max(id ?? 0, 0), pages.count - 1)]
    }

    /// What this screen shows: the verse, or the excerpt of it.
    func arabic(_ page: QuranPage) -> String {
        page.isOpening ? "" : excerpts[page.surah - 1][page.verse - 1][page.part]
    }

    /// The whole verse a screen belongs to, for sharing and for lists.
    func verse(_ page: QuranPage) -> String {
        page.isOpening ? "" : arabic[page.surah - 1][page.verse - 1]
    }

    /// How much of the verse each of its excerpts weighs, in letters. The
    /// translation and the recitation are both cut on these proportions.
    func weights(_ page: QuranPage) -> [Int] {
        page.isOpening ? [1] : excerpts[page.surah - 1][page.verse - 1].map(QuranExcerpt.letters(in:))
    }

    /// Where this screen's excerpt starts and ends in the verse's recording,
    /// as fractions of it. An estimate (letters are not seconds), good enough
    /// to turn the page about when the voice gets there.
    func span(_ page: QuranPage) -> (from: Double, to: Double) {
        guard page.parts > 1 else { return (0, 1) }
        let weights = weights(page)
        let total = Double(max(weights.reduce(0, +), 1))
        let before = Double(weights[..<page.part].reduce(0, +))
        let through = before + Double(weights[page.part])
        return (before / total, page.part == page.parts - 1 ? 1 : through / total)
    }
}

/// The meaning of every verse in one language, verse for verse with the Arabic.
struct QuranTranslation: Decodable, Sendable {
    let edition: String
    /// Who wrote it. Shown in the credits: a translation of the Qur'an is
    /// somebody's reading of it, and the reader is owed the name.
    let translator: String
    let verses: [[String]]

    /// The whole verse, translated.
    func text(_ page: QuranPage) -> String? {
        guard !page.isOpening,
              verses.indices.contains(page.surah - 1),
              verses[page.surah - 1].indices.contains(page.verse - 1) else { return nil }
        return verses[page.surah - 1][page.verse - 1]
    }

    /// The part of the translation that goes with this screen's excerpt, cut
    /// on the Arabic's proportions (`weights`, from `Quran.weights`).
    func text(_ page: QuranPage, weights: [Int]) -> String? {
        guard let whole = text(page) else { return nil }
        let parts = QuranExcerpt.split(whole, weights: weights)
        return parts.indices.contains(page.part) ? parts[page.part] : whole
    }

    /// Nil in Arabic, where the text needs no translation, and for a language
    /// whose file did not ship. A megabyte or two to decode: call it off the
    /// main thread.
    static func load(code: String) -> QuranTranslation? {
        guard let url = Bundle.main.url(forResource: "quran.\(code)", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(QuranTranslation.self, from: data)
    }
}

/// Where the reader was. Two numbers rather than a feed rank: a rank would
/// point at another verse the day the feed gains or loses a kind of page.
enum QuranBookmark {
    private static let surahKey = "quran.bookmark.surah"
    private static let verseKey = "quran.bookmark.verse"

    static func load() -> (surah: Int, verse: Int) {
        let defaults = UserDefaults.standard
        let surah = defaults.integer(forKey: surahKey)
        return surah > 0 ? (surah, defaults.integer(forKey: verseKey)) : (1, 0)
    }

    static func save(_ page: QuranPage) {
        UserDefaults.standard.set(page.surah, forKey: surahKey)
        UserDefaults.standard.set(page.verse, forKey: verseKey)
    }
}

// MARK: - Excerpts

/// Cuts a long verse into screens the size of a breath (Sharik, 14/11/2026:
/// a verse shrunk to fit one screen was unreadable, and nothing like a feed).
///
/// **Nothing is removed and nothing is reordered**: the excerpts of a verse,
/// joined back with spaces, are the verse. A test holds that for the 6236.
///
/// The cuts fall on the mushaf's own pause signs wherever there are any, since
/// that is where a reciter may stop. A stretch with no pause sign that is still
/// too long is cut between two words, in even pieces: a cut for the eye only,
/// the recitation runs through it.
enum QuranExcerpt {
    /// A verse of this many words or fewer is shown whole.
    static let whole = 14
    /// What an excerpt aims for.
    static let target = 12

    /// The signs after which stopping is allowed. Deliberately without ۙ
    /// ("do not stop here") and without ۛ (stop at one of two, never both).
    private static let pauses: Set<Character> = ["\u{06D6}", "\u{06D7}", "\u{06D8}", "\u{06DA}"]

    /// A token made of Qur'anic annotation signs only: it is not a word.
    private static func isSign(_ token: Substring) -> Bool {
        token.unicodeScalars.allSatisfy { (0x06D6...0x06ED).contains($0.value) }
    }

    private static func words(_ tokens: [Substring]) -> Int {
        tokens.reduce(0) { $0 + (isSign($1) ? 0 : 1) }
    }

    /// Arabic letters, without their vowel marks: a fair measure of how long a
    /// stretch takes to say.
    static func letters(in text: String) -> Int {
        max(text.unicodeScalars.reduce(0) { $0 + ((0x0621...0x064A).contains($1.value) ? 1 : 0) }, 1)
    }

    static func parts(of verse: String) -> [String] {
        let tokens = verse.split(separator: " ")
        guard words(tokens) > whole else { return [verse] }

        // 1. Stretches that end on a pause sign.
        var stretches: [[Substring]] = [[]]
        for token in tokens {
            stretches[stretches.count - 1].append(token)
            if token.count == 1, let sign = token.first, pauses.contains(sign) { stretches.append([]) }
        }
        stretches.removeAll { $0.isEmpty }

        // 2. A stretch still too long is cut between words, evenly.
        var pieces: [[Substring]] = []
        for stretch in stretches {
            let count = words(stretch)
            guard count > target + 3 else { pieces.append(stretch); continue }
            let chunks = Int((Double(count) / Double(target)).rounded(.up))
            let size = Int((Double(count) / Double(chunks)).rounded(.up))
            var current: [Substring] = []
            for token in stretch {
                // A sign stays with the word it follows.
                if words(current) >= size, !isSign(token) {
                    pieces.append(current)
                    current = []
                }
                current.append(token)
            }
            if !current.isEmpty { pieces.append(current) }
        }

        // 3. Short neighbours share a screen.
        var merged: [[Substring]] = []
        for piece in pieces {
            if let last = merged.last, words(last) + words(piece) <= target {
                merged[merged.count - 1] = last + piece
            } else {
                merged.append(piece)
            }
        }
        // A two-word tail is not a screen: it goes back with what precedes it.
        if merged.count > 1, let tail = merged.last, words(tail) < 4,
           words(merged[merged.count - 2]) + words(tail) <= target + 5 {
            merged.removeLast()
            merged[merged.count - 1] += tail
        }
        return merged.map { $0.joined(separator: " ") }
    }

    private static let closers: Set<Character> = [".", ",", ";", ":", "!", "?", "…", "»", "”", ")", "؛", "،", "۔", "।"]

    /// Cuts a translation into as many parts as the Arabic has excerpts, on
    /// the same proportions, preferring to cut after punctuation.
    ///
    /// This is an **approximation**, and the only one on this screen: nothing
    /// in a translation says which of its words answer which Arabic words. A
    /// translator follows the verse clause by clause, so cutting both at the
    /// same proportion keeps the meaning beside its Arabic, give or take a
    /// few words at the seam. Nothing is dropped: the parts joined back are
    /// the translation.
    static func split(_ text: String, weights: [Int]) -> [String] {
        let count = weights.count
        guard count > 1 else { return [text] }
        let words = text.split(separator: " ")
        // Too short to cut: the whole meaning stays on every screen.
        guard words.count >= count * 2 else { return Array(repeating: text, count: count) }

        // Where each word ends, in characters.
        var ends: [Int] = []
        var position = 0
        for word in words {
            position += word.count + 1
            ends.append(position)
        }
        let total = Double(position)
        let weightSum = Double(max(weights.reduce(0, +), 1))
        let bonus = total / Double(count) * 0.35

        var cuts: [Int] = []          // number of words before each cut
        var running = 0.0
        var previous = 0
        for part in 0..<(count - 1) {
            running += Double(weights[part])
            let aim = total * running / weightSum
            let lowest = previous + 1
            let highest = words.count - (count - 1 - part)
            var best = lowest
            var bestCost = Double.infinity
            for candidate in lowest...max(lowest, highest) {
                var cost = abs(Double(ends[candidate - 1]) - aim)
                if let last = words[candidate - 1].last, closers.contains(last) { cost -= bonus }
                if cost < bestCost { bestCost = cost; best = candidate }
            }
            cuts.append(best)
            previous = best
        }

        var parts: [String] = []
        var start = 0
        for cut in cuts + [words.count] {
            parts.append(words[start..<cut].joined(separator: " "))
            start = cut
        }
        return parts
    }
}
