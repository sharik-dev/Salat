import XCTest
@testable import Salat

/// The widget's Qur'an excerpts. The widget never opens the Qur'an itself: the
/// app resolves the reader's passages into text and leaves it in the shared
/// suite. A slip here would not crash anything, it would put the meaning of
/// one verse under another on a home screen, so the pairing is held by tests.
final class WidgetExcerptTests: XCTestCase {

    private let names = ["One", "Two", "Three"]
    private let arabic = [["a1", "a2", "a3"], ["b1", "b2"], ["c1"]]
    private let meaning = [["m1", "m2", "m3"], ["n1", "n2"], ["o1"]]

    private func resolve(_ passages: [WidgetPassage], translated: Bool = true) -> [WidgetVerse] {
        QuranExcerpts.resolve(passages, names: names, arabic: arabic,
                              translation: translated ? meaning : nil)
    }

    func testAPassageBecomesItsVersesInOrderEachWithItsOwnMeaning() {
        let verses = resolve([WidgetPassage(surah: 1, from: 2, to: 3),
                              WidgetPassage(surah: 2, from: 1, to: 1)])
        XCTAssertEqual(verses.map(\.reference), ["1:2", "1:3", "2:1"])
        XCTAssertEqual(verses.map(\.arabic), ["a2", "a3", "b1"])
        XCTAssertEqual(verses.map(\.translation), ["m2", "m3", "n1"])
        XCTAssertEqual(verses.map(\.surahName), ["One", "One", "Two"])
        XCTAssertEqual(verses[0].title, "One 1:2")
    }

    /// A stale pick (an older build, a hand-edited default) must land
    /// somewhere, never crash and never invent a verse.
    func testBoundsAreClampedAndUnknownSurahsSkipped() {
        XCTAssertEqual(resolve([WidgetPassage(surah: 2, from: 2, to: 99)]).map(\.reference), ["2:2"])
        XCTAssertTrue(resolve([WidgetPassage(surah: 2, from: 5, to: 9)]).isEmpty)
        XCTAssertTrue(resolve([WidgetPassage(surah: 0, from: 1, to: 1),
                               WidgetPassage(surah: 4, from: 1, to: 1)]).isEmpty)
        // Bounds given backwards, or below 1, are put right by the passage.
        let passage = WidgetPassage(surah: 1, from: 3, to: 0)
        XCTAssertEqual(passage.from, 1)
        XCTAssertEqual(passage.to, 3)
        XCTAssertEqual(passage.reference, "1:1-3")
        XCTAssertEqual(WidgetPassage(surah: 2, from: 255, to: 255).reference, "2:255")
    }

    /// Twice in the list would hold the widget on one verse two minutes running.
    func testAVerseNamedByTwoPassagesAppearsOnce() {
        let verses = resolve([WidgetPassage(surah: 1, from: 1, to: 2),
                              WidgetPassage(surah: 1, from: 2, to: 3)])
        XCTAssertEqual(verses.map(\.reference), ["1:1", "1:2", "1:3"])
    }

    /// Arabic has no translation file: the verses still resolve, text only.
    func testWithoutATranslationTheArabicStandsAlone() {
        let verses = resolve([WidgetPassage(surah: 3, from: 1, to: 1)], translated: false)
        XCTAssertEqual(verses.map(\.arabic), ["c1"])
        XCTAssertEqual(verses.map(\.translation), [""])
    }

    // MARK: Against the real book

    func testTheSeedAndTheSuggestionsNameVersesThatExist() throws {
        let quran = try XCTUnwrap(Quran.shared)
        for passage in QuranExcerpts.seed + QuranExcerpts.suggestions {
            XCTAssertTrue((1...114).contains(passage.surah), passage.id)
            XCTAssertLessThanOrEqual(passage.to, quran.surah(passage.surah).verses,
                                     "\(passage.id) runs past the end of its surah")
        }
        XCTAssertEqual(Set(QuranExcerpts.suggestions).count, QuranExcerpts.suggestions.count)
    }

    func testTheSeedResolvesToTheRightVersesInEveryLanguage() throws {
        let quran = try XCTUnwrap(Quran.shared)
        let expected = QuranExcerpts.seed.reduce(0) { $0 + $1.count }
        for language in AppLanguage.shipped where language != .ar {
            let translation = try XCTUnwrap(QuranTranslation.load(code: language.rawValue),
                                            "quran.\(language.rawValue).json")
            let verses = QuranExcerpts.resolve(QuranExcerpts.seed,
                                               names: quran.surahs.map(\.latin),
                                               arabic: quran.arabic,
                                               translation: translation.verses)
            XCTAssertEqual(verses.count, expected, language.rawValue)
            XCTAssertFalse(verses.contains { $0.translation.isEmpty }, language.rawValue)
            // The first seed is the Throne Verse: its Arabic is the book's 2:255.
            XCTAssertEqual(verses[0].arabic, quran.arabic[1][254])
            XCTAssertEqual(verses[0].translation, translation.verses[1][254])
        }
    }

    // MARK: The rotation

    func testTheVersesRotateOneAMinuteInTheReadersOrder() {
        let verses = resolve([WidgetPassage(surah: 1, from: 1, to: 3)])
        XCTAssertNil(CarouselPlan.verseSlot(at: Date(), verses: []))

        let start = Date(timeIntervalSince1970: 3 * 60 * 1000)   // a tick that is a multiple of 3
        let seen = (0..<4).compactMap {
            CarouselPlan.verseSlot(at: start.addingTimeInterval(Double($0) * 60), verses: verses)
        }
        XCTAssertEqual(seen.map(\.verse.reference), ["1:1", "1:2", "1:3", "1:1"])
        XCTAssertEqual(seen.map(\.position), [1, 2, 3, 1])
        XCTAssertEqual(seen.map(\.total), [3, 3, 3, 3])
    }

    /// With the widget on the Qur'an but no verse to show, the prayer is the
    /// fallback: a widget is never an empty card.
    func testAnEmptyQuranScopeFallsBackToThePrayer() {
        let steps = PrayerContent.steps(for: .en)
        let prefs = WidgetPrefs(scope: .quran)
        XCTAssertEqual(CarouselPlan.cycle(steps, log: StudyLogState(), prefs: prefs),
                       CarouselPlan.cycle(steps, log: StudyLogState(), prefs: WidgetPrefs()))
    }

    // MARK: The card

    /// A verse has no phonetic. A reader whose widget led with the
    /// pronunciation gets the Arabic, never an empty lead.
    func testAVerseCardNeverLeadsWithAnEmptyPhonetic() {
        let verse = WidgetVerse(surah: 2, verse: 255, surahName: "Al-Baqara",
                                arabic: "آية", translation: "meaning")
        let localizer = Localizer(language: .en)
        let entry = CarouselEntry(date: Date(), verse: verse, position: 1, total: 1,
                                  localizer: localizer, focus: .phonetic)
        XCTAssertEqual(entry.focus, .arabic)
        XCTAssertEqual(entry.step.name, "Al-Baqara 2:255")
        XCTAssertEqual(entry.step.image, PrayerStep.quranImage)
        XCTAssertTrue(entry.step.spoken)
        XCTAssertFalse(entry.locked)
        XCTAssertEqual(CarouselEntry(date: Date(), verse: verse, position: 1, total: 1,
                                     localizer: localizer, focus: .translation).focus, .translation)
        XCTAssertTrue(CarouselEntry.locked(date: Date(), localizer: localizer).locked)
    }

    /// The widget draws these two from the kit's own bundle; without them the
    /// verse has no image and the locked card falls back to a glyph.
    func testTheWidgetsTwoObjectsAreInTheKit() {
        XCTAssertNotNil(PositionAsset.image(named: PrayerStep.quranImage))
        XCTAssertNotNil(PositionAsset.image(named: "widget_lock"))
    }

    // MARK: Premium

    /// Everything the paywall, the shortcuts and the locked widget say exists
    /// in the fourteen languages: a missing key prints its own name on screen.
    func testEveryPremiumAndExcerptStringIsTranslated() {
        let keys = ["premium.title", "premium.pitch", "premium.pitch.ads", "premium.benefit.widget",
                    "premium.benefit.quran", "premium.benefit.ads", "premium.benefit.sizes",
                    "premium.price", "premium.subscribe", "premium.restore", "premium.legal",
                    "premium.terms", "premium.privacy", "premium.active", "premium.active.body",
                    "premium.manage", "premium.unavailable", "premium.retry",
                    "premium.notice.none", "premium.notice.pending", "premium.notice.failed",
                    "premium.badge", "premium.card.body", "widget.unlock", "widget.locked.body",
                    "widget.show.quran", "widget.quran.title", "widget.quran.add",
                    "widget.quran.suggested", "widget.quran.from", "widget.quran.to",
                    "widget.quran.confirm", "widget.quran.empty", "widget.quran.how",
                    "widget.quran.liked"]
        let english = Localizer(language: .en)
        for language in AppLanguage.shipped {
            let localizer = Localizer(language: language)
            for key in keys {
                let text = localizer.t(key)
                XCTAssertNotEqual(text, key, "\(key) is missing in \(language.rawValue)")
                // Falling back to English is a missing translation too, except
                // for the names that are the same everywhere, and "Suggestions",
                // which French happens to spell like English.
                if language != .en,
                   !["premium.title", "premium.badge", "widget.quran.suggested"].contains(key) {
                    XCTAssertNotEqual(text, english.t(key),
                                      "\(key) is still English in \(language.rawValue)")
                }
            }
            XCTAssertTrue(localizer.t("premium.price").contains("%@"),
                          "premium.price has lost its price in \(language.rawValue)")
        }
    }

    /// Every scope the menu offers has its label.
    func testEveryWidgetScopeHasALabel() {
        let localizer = Localizer(language: .en)
        for scope in WidgetScope.allCases {
            let key = "widget.show.\(scope.rawValue)"
            XCTAssertNotEqual(localizer.t(key), key)
        }
    }
}
