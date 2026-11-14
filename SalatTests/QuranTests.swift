import XCTest
@testable import Salat

/// The Qur'an feed pairs three things by position: the Arabic, its translation
/// and the reciter's file. Nothing crashes when one of them slips by a verse —
/// the wrong meaning simply sits under the wrong verse — so the counts are
/// held here.
final class QuranTests: XCTestCase {

    private var quran: Quran { Quran.shared! }

    func testTheBookIsWhole() throws {
        let quran = try XCTUnwrap(Quran.shared, "quran.base.json is not in the bundle")
        XCTAssertEqual(quran.surahs.count, 114)
        XCTAssertEqual(quran.arabic.reduce(0) { $0 + $1.count }, 6236)
        XCTAssertEqual(quran.surahs.map(\.number), Array(1...114))
        for (surah, verses) in zip(quran.surahs, quran.arabic) {
            XCTAssertEqual(surah.verses, verses.count, "surah \(surah.number)")
            XCTAssertFalse(verses.contains { $0.isEmpty }, "surah \(surah.number) has an empty verse")
        }
    }

    /// The reciters' files hold verse 1 without the basmala, so the text must
    /// too: otherwise the screen shows four words more than the voice says.
    func testTheBasmalaIsItsOwnPageNotPartOfVerseOne() {
        XCTAssertEqual(quran.arabic[0][0], quran.basmala,
                       "the Fatiha's first verse is the basmala itself")
        for surah in quran.surahs where surah.hasBasmala {
            XCTAssertFalse(quran.arabic[surah.number - 1][0].hasPrefix(quran.basmala),
                           "surah \(surah.number) still carries the basmala in verse 1")
        }
        XCTAssertEqual(quran.surahs.filter(\.hasBasmala).count, 112)
        XCTAssertFalse(quran.surah(9).hasBasmala)
    }

    func testTheFeedIsEverySurahOpeningThenItsVersesInOrder() {
        XCTAssertEqual(quran.pages.map(\.id), Array(0..<quran.pages.count),
                       "a page's id is its rank: the scroll view tracks it")
        XCTAssertEqual(quran.pages.filter(\.isOpening).count, 114)
        XCTAssertEqual(quran.pages.filter { !$0.isOpening && $0.isFirstPart }.count, 6236,
                       "every verse starts exactly one screen")
        XCTAssertTrue(quran.pages[0].isOpening)
        XCTAssertEqual(quran.pages[1].verse, 1)
        XCTAssertEqual(quran.pages.last?.surah, 114)
        XCTAssertEqual(quran.pages.last?.verse, 6)

        // Never backwards, never a gap: surah, then verse, then excerpt.
        for (before, after) in zip(quran.pages, quran.pages.dropFirst()) {
            if after.isOpening {
                XCTAssertEqual(after.surah, before.surah + 1)
                XCTAssertEqual(before.part, before.parts - 1, "a surah ended mid-verse")
            } else if after.part > 0 {
                XCTAssertEqual(after.verse, before.verse)
                XCTAssertEqual(after.part, before.part + 1)
                XCTAssertEqual(after.parts, before.parts)
            } else {
                XCTAssertEqual(after.verse, before.verse + 1)
            }
        }
    }

    // MARK: Excerpts

    /// The one promise of the cut: nothing is dropped, nothing is moved.
    func testTheExcerptsOfAVerseAreTheVerse() {
        for (surah, verses) in quran.arabic.enumerated() {
            for (verse, text) in verses.enumerated() {
                let parts = quran.excerpts[surah][verse]
                XCTAssertEqual(parts.joined(separator: " "), text, "\(surah + 1):\(verse + 1)")
                XCTAssertFalse(parts.contains { $0.isEmpty }, "\(surah + 1):\(verse + 1)")
            }
        }
    }

    func testAShortVerseIsOneScreenAndALongOneIsSeveralShortOnes() {
        XCTAssertEqual(quran.excerpts[111][0].count, 1, "112:1 is four words")
        XCTAssertGreaterThan(quran.excerpts[1][254].count, 3, "the Throne verse is long")
        XCTAssertGreaterThan(quran.excerpts[1][281].count, 8, "2:282 is the longest verse")
        let longest = quran.excerpts.joined().joined()
            .map { $0.split(separator: " ").count }.max() ?? 0
        XCTAssertLessThanOrEqual(longest, 22, "an excerpt is a breath, not a paragraph")
    }

    /// ۙ means "do not stop here": no screen may end on it.
    func testNoExcerptEndsWhereStoppingIsForbidden() {
        for parts in quran.excerpts.joined() where parts.count > 1 {
            for part in parts.dropLast() {
                XCTAssertNotEqual(part.last, "\u{06D9}", part)
            }
        }
    }

    func testTheSpansOfAVerseCoverItsRecordingWithoutGapOrOverlap() {
        let first = quran.pageID(surah: 2, verse: 282)
        let parts = quran.pages[first].parts
        var cursor = 0.0
        for offset in 0..<parts {
            let span = quran.span(quran.pages[first + offset])
            XCTAssertEqual(span.from, cursor, accuracy: 1e-9)
            XCTAssertGreaterThan(span.to, span.from)
            cursor = span.to
        }
        XCTAssertEqual(cursor, 1, accuracy: 1e-9)
        let short = quran.span(quran.pages[quran.pageID(surah: 112, verse: 1)])
        XCTAssertEqual(short.from, 0)
        XCTAssertEqual(short.to, 1)
    }

    /// The translation is cut on the Arabic's proportions. Whatever the cut,
    /// the parts in order must still be the translator's sentence.
    func testACutTranslationIsStillTheTranslation() throws {
        for language in [AppLanguage.en, .fr, .ur, .bn, .ru] {
            let translation = try XCTUnwrap(QuranTranslation.load(code: language.rawValue))
            for (surah, verse) in [(2, 255), (2, 282), (4, 12), (24, 35), (73, 20)] {
                let first = quran.pages[quran.pageID(surah: surah, verse: verse)]
                let weights = quran.weights(first)
                let whole = try XCTUnwrap(translation.text(first))
                let parts = QuranExcerpt.split(whole, weights: weights)
                XCTAssertEqual(parts.count, weights.count)
                XCTAssertFalse(parts.contains { $0.isEmpty }, "\(language.rawValue) \(surah):\(verse)")
                XCTAssertEqual(parts.joined(separator: " "),
                               whole.split(separator: " ").joined(separator: " "),
                               "\(language.rawValue) \(surah):\(verse)")
            }
        }
    }

    /// Two words cannot be cut in three: the whole meaning stays on each screen
    /// rather than leaving one empty.
    func testATranslationTooShortToCutIsShownWhole() {
        XCTAssertEqual(QuranExcerpt.split("Alif Lam Mim", weights: [3, 3, 3]),
                       ["Alif Lam Mim", "Alif Lam Mim", "Alif Lam Mim"])
        XCTAssertEqual(QuranExcerpt.split("anything", weights: [5]), ["anything"])
    }

    // MARK: Hearts and notes

    func testAHeartAndANoteBelongToTheVerse() {
        let journal = QuranJournal()
        let ref = VerseRef(surah: 2, verse: 255)
        let hadLike = journal.isLiked(ref)
        let before = journal.notes(for: ref)
        defer {
            // Leave the simulator's own marks as they were found.
            if journal.isLiked(ref) != hadLike { journal.toggleLike(ref) }
            for note in journal.notes(for: ref) where !before.contains(note) {
                journal.deleteNote(note, from: ref)
            }
        }

        if hadLike { journal.toggleLike(ref) }
        XCTAssertFalse(journal.isLiked(ref))
        journal.like(ref)
        journal.like(ref)
        XCTAssertEqual(journal.likes.filter { $0 == ref }.count, 1, "a heart is given once")
        XCTAssertEqual(QuranLikes.all().first, ref, "the widget reads the same hearts")
        XCTAssertTrue(journal.marked.contains(ref))

        journal.addNote("   ", to: ref)
        XCTAssertEqual(journal.notes(for: ref).count, before.count, "a blank note is not a note")
        journal.addNote("  ayat al-kursi  ", to: ref)
        XCTAssertEqual(journal.notes(for: ref).last?.text, "ayat al-kursi")
        XCTAssertEqual(VerseRef(key: ref.key), ref)
        XCTAssertNil(VerseRef(key: "not a verse"))
    }

    func testAVerseFindsItsPageAndBack() {
        for (surah, verse) in [(1, 0), (1, 7), (2, 255), (9, 1), (36, 1), (114, 6)] {
            let page = quran.page(quran.pageID(surah: surah, verse: verse))
            XCTAssertEqual(page.surah, surah)
            XCTAssertEqual(page.verse, verse)
        }
    }

    /// A bookmark written by an older build, or by hand, must land somewhere.
    func testAStaleBookmarkIsClampedNotCrashed() {
        XCTAssertEqual(quran.page(quran.pageID(surah: 0, verse: 0)).surah, 1)
        XCTAssertEqual(quran.page(quran.pageID(surah: 500, verse: 3)).surah, 114)
        XCTAssertEqual(quran.page(quran.pageID(surah: 1, verse: 99)).verse, 7)
        XCTAssertEqual(quran.page(nil).id, 0)
        XCTAssertEqual(quran.page(1_000_000).id, quran.pages.count - 1)
    }

    func testEveryTranslationRunsVerseForVerseWithTheArabic() throws {
        for language in AppLanguage.shipped where language != .ar {
            let translation = try XCTUnwrap(QuranTranslation.load(code: language.rawValue),
                                            "no Qur'an translation for \(language.rawValue)")
            XCTAssertFalse(translation.translator.isEmpty, language.rawValue)
            XCTAssertEqual(translation.verses.count, 114, language.rawValue)
            for (surah, verses) in zip(quran.surahs, translation.verses) {
                XCTAssertEqual(verses.count, surah.verses,
                               "\(language.rawValue), surah \(surah.number)")
                XCTAssertFalse(verses.contains { $0.isEmpty },
                               "\(language.rawValue), surah \(surah.number) has an empty verse")
            }
        }
    }

    /// In Arabic the text is its own meaning: no file, and no second line.
    func testArabicHasNoTranslation() {
        XCTAssertNil(QuranTranslation.load(code: "ar"))
    }

    /// Every voice the reciter list offers must be one the feed can fetch.
    func testEveryQuranReciterHasASecureSource() throws {
        let reciters = Recitations.reciters(covering: "fatiha")
        XCTAssertFalse(reciters.isEmpty)
        for reciter in reciters {
            let url = try XCTUnwrap(QuranAudio.remote(reciter: reciter, surah: 2, verse: 255),
                                    "\(reciter.id) has no https source")
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.lastPathComponent, "002255.mp3")
        }
    }
}
