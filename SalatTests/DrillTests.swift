import XCTest
@testable import Salat

/// The drill writes its own questions, so nothing but a test stands between a
/// reader and a question with two right answers.
final class DrillTests: XCTestCase {

    private let steps = PrayerContent.steps(for: .en)
    private var everything: Set<String> { Set(steps.map(\.id)) }

    // MARK: The shape of a question

    func testEveryQuestionHasFourDistinctOptionsAndOneAnswer() {
        for language in AppLanguage.shipped {
            let steps = PrayerContent.steps(for: language)
            let pool = Set(steps.map(\.id))
            let questions = Drill.session(steps: steps, pool: pool, count: 40, seed: 7)
            XCTAssertFalse(questions.isEmpty, "\(language.rawValue) produced no questions at all")

            for q in questions {
                XCTAssertEqual(q.options.count, Drill.optionCount, "\(language.rawValue)/\(q.id)")
                XCTAssertEqual(Set(q.options).count, Drill.optionCount,
                               "\(language.rawValue)/\(q.id): the same option appears twice, so two answers are right")
                XCTAssertTrue(q.options.indices.contains(q.answer), "\(language.rawValue)/\(q.id)")
                XCTAssertFalse(q.correctOption.trimmingCharacters(in: .whitespaces).isEmpty,
                               "\(language.rawValue)/\(q.id): the right answer is blank")
                XCTAssertFalse(q.options.contains(q.subject),
                               "\(language.rawValue)/\(q.id): the question is one of its own options")
            }
        }
    }

    func testEveryPromptKeyIsTranslatedEverywhere() {
        for language in AppLanguage.shipped {
            let loc = Localizer(language: language)
            for kind in DrillQuestion.Kind.allCases {
                let key = "drill.q.\(kind.rawValue)"
                XCTAssertNotEqual(loc.t(key), key, "\(language.rawValue) has no string for \(key)")
            }
            for key in ["tab.memorize", "memorize.start", "memorize.ready",
                        "memorize.strength.title", "revise.tool.drill.title",
                        "revise.tool.drill.body", "drill.right", "drill.wrong",
                        "drill.next", "drill.done.title", "drill.done.score",
                        "drill.done.again", "drill.empty",
                        "drill.q.pairs", "drill.q.order",
                        "drill.check", "drill.answer"] {
                XCTAssertNotEqual(loc.t(key), key, "\(language.rawValue) has no string for \(key)")
            }
        }
    }

    // MARK: What it is allowed to ask

    /// A step nobody has read is never the subject of a question — that is the
    /// whole difference between an exercise and a guess.
    func testItOnlyAsksAboutStepsThatWereRead() {
        let pool: Set<String> = ["fatiha", "ruku", "sujud", "tashahhud"]
        let questions = Drill.session(steps: steps, pool: pool, count: 40, seed: 3)
        XCTAssertFalse(questions.isEmpty)
        for q in questions {
            XCTAssertTrue(pool.contains(q.stepID), "\(q.id) asks about a step that was never opened")
        }
    }

    func testNothingReadMeansNoRound() {
        XCTAssertTrue(Drill.session(steps: steps, pool: [], seed: 1).isEmpty)
        XCTAssertTrue(Drill.session(steps: steps, pool: ["ruku"], seed: 1).isEmpty)
    }

    /// Four steps share the standing drawing: asking "which words go here" over
    /// it would have four right answers.
    func testThePostureQuestionOnlyUsesIllustrationsThatBelongToOneStep() {
        let shared = Dictionary(grouping: steps, by: \.image)
            .filter { $0.value.count > 1 }
            .map(\.key)
        let questions = Drill.session(steps: steps, pool: everything, count: 60, seed: 11)
            .filter { $0.kind == .posture }
        XCTAssertFalse(questions.isEmpty, "no posture question was produced at all")
        for q in questions {
            let step = steps.first { $0.id == q.stepID }!
            XCTAssertFalse(shared.contains(step.image),
                           "\(q.id) shows a drawing that fits several steps")
        }
    }

    /// The hidden word has to come from the line it was cut out of, and the
    /// Arabic must not be printed next to the gap — it is the answer, in full.
    func testTheBlankHidesARealWordAndNeverShowsTheAnswer() {
        let questions = Drill.session(steps: steps, pool: everything, count: 60, seed: 5)
            .filter { $0.kind == .blank }
        XCTAssertFalse(questions.isEmpty, "no fill-in question was produced at all")
        for q in questions {
            XCTAssertNil(q.arabic, "\(q.id) prints the Arabic of the line it is hiding a word from")
            XCTAssertTrue(q.subject.contains("•"), "\(q.id) has no gap in it")
            let step = steps.first { $0.id == q.stepID }!
            let line = step.readingLines.first {
                $0.split(separator: " ").contains(Substring(q.correctOption))
            }
            XCTAssertNotNil(line, "\(q.id): the missing word is in none of the step's lines")
        }
    }

    /// Arabic writes no phonetic — the drill reads the Arabic itself there
    /// rather than eight questions over an empty string.
    func testArabicDrawsItsLinesFromTheArabicText() {
        for step in PrayerContent.steps(for: .ar) where step.spoken {
            XCTAssertEqual(step.readingLines, step.arabicLines, step.id)
        }
        for step in PrayerContent.steps(for: .fr) where step.spoken {
            XCTAssertEqual(step.readingLines, step.phoneticLines, step.id)
        }
    }

    // MARK: Rounds

    func testTheSameSeedGivesTheSameRound() {
        let a = Drill.session(steps: steps, pool: everything, seed: 42)
        let b = Drill.session(steps: steps, pool: everything, seed: 42)
        let c = Drill.session(steps: steps, pool: everything, seed: 43)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertNotEqual(a.map(\.id), c.map(\.id), "two seeds gave the same eight questions")
    }

    func testARoundIsEightQuestionsOfSeveralKinds() {
        let round = Drill.session(steps: steps, pool: everything, seed: 9)
        XCTAssertEqual(round.count, Drill.sessionLength)
        XCTAssertGreaterThanOrEqual(Set(round.map(\.kind)).count, 3,
                                    "a whole round of one kind of question is a form to fill in")
        XCTAssertEqual(Set(round.map(\.id)).count, round.count, "a question was asked twice")
    }

    /// What you keep missing comes back first. Without this the drill is a
    /// random quiz, and a random quiz teaches whatever it happens to land on.
    func testTheStepsYouMissComeBackFirst() {
        let scores = ["fatiha": DrillScore(asked: 4, right: 1, lastMissed: Date()),
                      "ruku": DrillScore(asked: 4, right: 4)]
        let order = DrillLog.priority(["ruku", "surah", "fatiha"], scores: scores)
        XCTAssertEqual(order.first, "fatiha", "the missed step is not asked first")
        XCTAssertEqual(order.last, "ruku", "the step you always get right is not asked last")

        let round = Drill.session(steps: steps, pool: ["fatiha", "ruku", "surah"],
                                  priority: order, count: 3, seed: 2)
        XCTAssertEqual(round.first?.stepID, "fatiha")
    }

    // MARK: The boards

    /// The mixed round: same seed same round, opens on a familiar
    /// multiple-choice, and carries at least one of each new board.
    func testAMixedRoundIsReplayableAndNeverOpensOnABoard() {
        let round = Drill.round(steps: steps, pool: everything, seed: 9)
        XCTAssertEqual(round.count, Drill.sessionLength)
        XCTAssertEqual(round.map(\.id), Drill.round(steps: steps, pool: everything, seed: 9).map(\.id))
        XCTAssertEqual(Set(round.map(\.id)).count, round.count, "an exercise was dealt twice")

        if case .choice = round[0] {} else { XCTFail("a round opens on a board, not on a question") }
        XCTAssertTrue(round.contains { if case .pairs = $0 { true } else { false } },
                      "no matching board in a full round")
        XCTAssertTrue(round.contains { if case .order = $0 { true } else { false } },
                      "no word-order exercise in a full round")
        for exercise in round {
            XCTAssertTrue(everything.contains(exercise.stepID))
        }
    }

    func testAMixedRoundOnlyAsksAboutStepsThatWereRead() {
        let pool: Set<String> = ["fatiha", "ruku", "sujud", "tashahhud"]
        let round = Drill.round(steps: steps, pool: pool, seed: 3)
        XCTAssertFalse(round.isEmpty)
        for exercise in round {
            XCTAssertTrue(pool.contains(exercise.stepID),
                          "\(exercise.id) asks about a step that was never opened")
        }
        XCTAssertTrue(Drill.round(steps: steps, pool: [], seed: 1).isEmpty)
        XCTAssertTrue(Drill.round(steps: steps, pool: ["ruku"], seed: 1).isEmpty)
    }

    /// A matching board is four pairs from one step, both sides distinct, and
    /// the two columns never dealt level — level columns solve every row by
    /// its neighbour.
    func testAMatchingBoardIsFourHonestPairsFromOneStep() {
        var rng = SeededRandom(seed: 4)
        let boards = Drill.pairsCandidates(asked: steps, rng: &rng)
        XCTAssertFalse(boards.isEmpty, "no step can afford a matching board at all")
        for board in boards {
            let step = steps.first { $0.id == board.stepID }!
            XCTAssertEqual(board.pairs.count, Drill.pairCount)
            XCTAssertEqual(Set(board.pairs.map(\.reading)).count, Drill.pairCount,
                           "\(board.id): a reading appears twice, so two matches are right")
            XCTAssertEqual(Set(board.pairs.map(\.meaning)).count, Drill.pairCount,
                           "\(board.id): a meaning appears twice, so two matches are right")
            XCTAssertEqual(board.readingOrder.sorted(), Array(board.pairs.indices))
            XCTAssertEqual(board.meaningOrder.sorted(), Array(board.pairs.indices))
            XCTAssertNotEqual(board.readingOrder, board.meaningOrder,
                              "\(board.id): the columns are level, every row answers itself")
            for pair in board.pairs {
                XCTAssertTrue(step.readingLines.contains { $0.trimmingCharacters(in: .whitespaces) == pair.reading },
                              "\(board.id): a reading is not a line of its step")
                XCTAssertTrue(step.translationLines.contains { $0.trimmingCharacters(in: .whitespaces) == pair.meaning },
                              "\(board.id): a meaning is not a translation of its step")
            }
        }
    }

    /// The word bank is the line itself — same words, never in prayer order.
    func testTheWordBankIsTheLineShuffled() {
        var rng = SeededRandom(seed: 4)
        let exercises = Drill.orderCandidates(asked: steps, rng: &rng)
        XCTAssertFalse(exercises.isEmpty, "no line can afford a word-order exercise at all")
        for exercise in exercises {
            XCTAssertEqual(exercise.bank.sorted(), exercise.answer.sorted(),
                           "\(exercise.id): the bank is not the line's own words")
            XCTAssertNotEqual(exercise.bank, exercise.answer,
                              "\(exercise.id): the bank is dealt already in order")
            XCTAssertGreaterThanOrEqual(exercise.answer.count, 4)
            XCTAssertFalse(exercise.meaning.isEmpty)
        }
    }

    /// In Arabic the reading *is* the Arabic: printing the line above the bank
    /// would hand over the answer, so there the prompt is the meaning alone.
    func testArabicWordOrderNeverPrintsTheLineItAsksFor() {
        var rng = SeededRandom(seed: 1)
        let arabic = Drill.orderCandidates(asked: PrayerContent.steps(for: .ar), rng: &rng)
        XCTAssertFalse(arabic.isEmpty)
        for exercise in arabic { XCTAssertNil(exercise.arabic, exercise.id) }

        var rng2 = SeededRandom(seed: 1)
        let french = Drill.orderCandidates(asked: PrayerContent.steps(for: .fr), rng: &rng2)
        XCTAssertTrue(french.contains { $0.arabic?.isEmpty == false },
                      "the French exercises never show the Arabic they rebuild")
    }

    func testATallyGoesUpOnlyWhenTheAnswerIsRight() {
        let now = Date()
        var score = DrillLog.updated(DrillScore(), correct: true, at: now)
        XCTAssertEqual(score.asked, 1)
        XCTAssertEqual(score.right, 1)
        XCTAssertNil(score.lastMissed)

        score = DrillLog.updated(score, correct: false, at: now)
        XCTAssertEqual(score.asked, 2)
        XCTAssertEqual(score.right, 1)
        XCTAssertEqual(score.lastMissed, now)
        XCTAssertEqual(score.recall, 0.5)
    }

    /// Two lucky answers are not mastery, and a full row of pips after one
    /// question would be a lie told in pictures.
    func testPipsStayEmptyUntilThereIsSomethingToShow() {
        XCTAssertEqual(DrillScore(asked: 1, right: 1).pips, 0)
        XCTAssertEqual(DrillScore(asked: 2, right: 2).pips, 2)
        XCTAssertEqual(DrillScore(asked: 8, right: 8).pips, 5)
        XCTAssertEqual(DrillScore(asked: 8, right: 0).pips, 0)
    }
}
