import XCTest
@testable import Salat

/// The flashcard deck and the fading ladder are pure values; these tests are
/// what keeps a card from asking with its own answer showing, and a ladder
/// from re-hiding different words on every visit.
final class MemoryToolsTests: XCTestCase {

    private let steps = PrayerContent.steps(for: .en)
    private var everything: Set<String> { Set(steps.map(\.id)) }

    // MARK: Flashcards

    func testDeckOnlyDealsFromThePoolAndFromSpokenSteps() {
        for language in AppLanguage.shipped {
            let steps = PrayerContent.steps(for: language)
            let pool = Set(steps.prefix(5).map(\.id))
            let deck = Flashcards.deck(steps: steps, pool: pool, seed: 3)
            XCTAssertFalse(deck.isEmpty, "\(language.rawValue) dealt nothing")
            for card in deck {
                XCTAssertTrue(pool.contains(card.stepID),
                              "\(language.rawValue)/\(card.id): a card about an unread step")
                let step = steps.first { $0.id == card.stepID }
                XCTAssertEqual(step?.spoken, true,
                               "\(language.rawValue)/\(card.id): a silent step has nothing to recall")
            }
        }
    }

    func testEveryCardHasAFrontAndABack() {
        for language in AppLanguage.shipped {
            let steps = PrayerContent.steps(for: language)
            let deck = Flashcards.deck(steps: steps, pool: Set(steps.map(\.id)), seed: 11)
            for card in deck {
                XCTAssertFalse(card.arabic.isEmpty, "\(language.rawValue)/\(card.id)")
                XCTAssertGreaterThan(card.meaning.count, 3, "\(language.rawValue)/\(card.id)")
                // The reading either exists or is the Arabic itself — never an
                // empty string standing where the check should be.
                if let reading = card.reading {
                    XCTAssertFalse(reading.trimmingCharacters(in: .whitespaces).isEmpty,
                                   "\(language.rawValue)/\(card.id)")
                }
            }
        }
    }

    func testArabicCardsNeverRepeatTheBackOnTheirReading() {
        let steps = PrayerContent.steps(for: .ar)
        let deck = Flashcards.deck(steps: steps, pool: Set(steps.map(\.id)), seed: 5)
        XCTAssertFalse(deck.isEmpty)
        for card in deck {
            XCTAssertNil(card.reading,
                         "\(card.id): in Arabic the reading is the Arabic; printing it twice says nothing")
        }
    }

    func testSameSeedSameDeck() {
        let a = Flashcards.deck(steps: steps, pool: everything, seed: 42)
        let b = Flashcards.deck(steps: steps, pool: everything, seed: 42)
        XCTAssertEqual(a, b, "a deck that cannot be re-dealt cannot be tested")
        let c = Flashcards.deck(steps: steps, pool: everything, seed: 43)
        XCTAssertNotEqual(a.map(\.id), c.map(\.id), "the seed changes nothing")
    }

    func testDeckIsCapped() {
        let deck = Flashcards.deck(steps: steps, pool: everything, seed: 1)
        XCTAssertLessThanOrEqual(deck.count, Flashcards.deckSize)
    }

    // MARK: The fading ladder

    func testLadderStartsFullAndEndsEmpty() {
        for step in steps.filter(\.spoken) {
            for (i, line) in step.readingLines.enumerated() {
                let words = line.split(separator: " ").count
                XCTAssertTrue(Fade.hiddenWords(stepID: step.id, lineIndex: i,
                                               wordCount: words, level: 0).isEmpty,
                              "\(step.id)/\(i): level 0 must show everything")
                XCTAssertEqual(Fade.hiddenWords(stepID: step.id, lineIndex: i,
                                                wordCount: words, level: Fade.levels - 1),
                               Set(0..<words),
                               "\(step.id)/\(i): the last rung must hide everything")
            }
        }
    }

    func testAHiddenWordStaysHidden() {
        for step in steps.filter(\.spoken) {
            for (i, line) in step.readingLines.enumerated() {
                let words = line.split(separator: " ").count
                for level in 1..<Fade.levels {
                    let before = Fade.hiddenWords(stepID: step.id, lineIndex: i,
                                                  wordCount: words, level: level - 1)
                    let after = Fade.hiddenWords(stepID: step.id, lineIndex: i,
                                                 wordCount: words, level: level)
                    XCTAssertTrue(before.isSubset(of: after),
                                  "\(step.id)/\(i): a word came back on the way up")
                    XCTAssertGreaterThanOrEqual(after.count, before.count)
                }
            }
        }
    }

    func testEveryRungHidesSomethingNewOnRealLines() {
        // On any line of two or more words, each rung must bite: a rung that
        // hides nothing more is a button that does nothing.
        for step in steps.filter(\.spoken) {
            for (i, line) in step.readingLines.enumerated() {
                let words = line.split(separator: " ").count
                guard words >= Fade.levels - 1 else { continue }
                for level in 1..<Fade.levels {
                    let before = Fade.hiddenWords(stepID: step.id, lineIndex: i,
                                                  wordCount: words, level: level - 1)
                    let after = Fade.hiddenWords(stepID: step.id, lineIndex: i,
                                                 wordCount: words, level: level)
                    XCTAssertGreaterThan(after.count, before.count,
                                         "\(step.id)/\(i): rung \(level) hides nothing more")
                }
            }
        }
    }

    func testTheLadderIsStableAcrossCalls() {
        // `String.hashValue` is randomised per launch; the ladder must not be.
        let a = Fade.hiddenWords(stepID: "fatiha", lineIndex: 2, wordCount: 8, level: 1)
        let b = Fade.hiddenWords(stepID: "fatiha", lineIndex: 2, wordCount: 8, level: 1)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Fade.seed("fatiha"), Fade.seed("fatiha"))
        XCTAssertNotEqual(Fade.seed("fatiha"), Fade.seed("surah"))
    }

    // MARK: The chosen run

    func testAFocusedRunOnlyDealsItsOwnKind() {
        let pool = everything
        for focus in DrillFocus.gallery {
            let run = DrillRun(focus: focus)
            let exercises = Drill.run(run, steps: steps, pool: pool, seed: 9)
            XCTAssertFalse(exercises.isEmpty, "\(focus) dealt nothing on the full pool")
            for exercise in exercises {
                switch (focus, exercise) {
                case (.kind(let k), .choice(let q)):
                    XCTAssertEqual(q.kind, k, "\(focus) dealt a stray kind")
                case (.pairs, .pairs), (.order, .order):
                    break
                default:
                    XCTFail("\(focus) dealt \(exercise.id)")
                }
            }
        }
    }

    func testTheSubjectFilterNarrowsEveryFocus() {
        let pool = everything
        for step in steps.filter(\.spoken).prefix(3) {
            for focus in DrillFocus.gallery + [.mixed] {
                let run = DrillRun(focus: focus, subject: step.id)
                for exercise in Drill.run(run, steps: steps, pool: pool, seed: 4) {
                    XCTAssertEqual(exercise.stepID, step.id,
                                   "\(focus) asked about \(exercise.stepID) under the \(step.id) filter")
                }
            }
        }
    }

    func testTheDefaultRunIsTheDealtRound() {
        // The picker's first card and the hub button must open the exact
        // session the old screen dealt — same seed, same round.
        let dealt = Drill.round(steps: steps, pool: everything, seed: 21)
        let chosen = Drill.run(DrillRun(), steps: steps, pool: everything, seed: 21)
        XCTAssertEqual(dealt, chosen)
    }

    func testAvailabilityMatchesWhatTheDoorOpensOn() {
        // A card showing a count and an empty run behind it is the lie the
        // gallery exists to avoid.
        for focus in DrillFocus.gallery {
            let run = DrillRun(focus: focus)
            let count = Drill.available(run, steps: steps, pool: everything)
            XCTAssertGreaterThan(count, 0, "\(focus) advertises nothing on the full pool")
        }
        let empty = DrillRun(focus: .kind(.posture), subject: "niyyah")
        XCTAssertEqual(Drill.available(empty, steps: steps, pool: everything),
                       Drill.run(empty, steps: steps, pool: everything,
                                 count: Int.max, seed: 0xA11).count)
    }

    // MARK: The hub speaks every language

    func testEveryToolKeyIsTranslatedEverywhere() {
        for language in AppLanguage.shipped {
            let loc = Localizer(language: language)
            for key in ["revise.tool.flash.title", "revise.tool.flash.body",
                        "revise.tool.fade.title", "revise.tool.fade.body",
                        "flash.reveal", "flash.know", "flash.again",
                        "flash.done.title", "flash.done.body", "flash.restart",
                        "fade.hint", "fade.hide", "fade.show",
                        "drill.picker.subtitle", "drill.picker.mixed.title",
                        "drill.picker.mixed.body", "drill.filter.all"] {
                XCTAssertNotEqual(loc.t(key), key,
                                  "\(language.rawValue) has no string for \(key)")
            }
        }
    }
}
