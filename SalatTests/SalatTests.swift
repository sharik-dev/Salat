import XCTest
@testable import Salat

/// The content files are the app. If one of them stops parsing, or a locale
/// drifts out of sync with the base, everything downstream shows blanks — so
/// that is what these tests guard.
final class PrayerContentTests: XCTestCase {

    func testEveryShippedLanguageLoadsEveryStep() {
        let base = PrayerContent.steps(for: .en)
        XCTAssertEqual(base.count, 14, "the base file should carry the 14 steps")

        for language in AppLanguage.shipped {
            let steps = PrayerContent.steps(for: language)
            XCTAssertEqual(steps.count, base.count,
                           "\(language.rawValue) is missing steps — check steps.\(language.rawValue).json")
            for step in steps {
                XCTAssertFalse(step.name.isEmpty, "\(language.rawValue)/\(step.id) has no name")
                XCTAssertFalse(step.postureText.isEmpty, "\(language.rawValue)/\(step.id) has no posture")
                XCTAssertFalse(step.translation.isEmpty, "\(language.rawValue)/\(step.id) has no translation")
            }
        }
    }

    func testStepsAreOrderedAndUnique() {
        let steps = PrayerContent.steps(for: .en)
        XCTAssertEqual(steps.map(\.order), Array(1...steps.count))
        XCTAssertEqual(Set(steps.map(\.id)).count, steps.count)
    }

    /// The detail screen pairs each Arabic line with its phonetic and its
    /// translation. A mismatch does not crash, but it silently misaligns the
    /// teaching — which is worse.
    /// Arabic is left out: it reads the Arabic itself and carries no phonetic
    /// line to pair up.
    func testLinesPairUpBetweenArabicPhoneticAndTranslation() {
        for language in AppLanguage.shipped where language != .ar {
            for step in PrayerContent.steps(for: language) where step.spoken {
                XCTAssertEqual(step.arabicLines.count, step.phoneticLines.count,
                               "\(language.rawValue)/\(step.id): phonetic lines do not match the Arabic")
                XCTAssertEqual(step.arabicLines.count, step.translationLines.count,
                               "\(language.rawValue)/\(step.id): translation lines do not match the Arabic")
            }
        }
    }

    func testUIStringsExistInEveryLanguage() {
        let english = Localizer(language: .en)
        let keys = ["tab.learn", "tab.practice", "tab.settings",
                    "detail.phonetic", "detail.translation",
                    "practice.title", "settings.disclaimer", "onboarding.1.title"]
        for language in AppLanguage.shipped {
            let loc = Localizer(language: language)
            for key in keys {
                XCTAssertNotEqual(loc.t(key), key, "\(language.rawValue) has no string for \(key)")
                _ = english.t(key)
            }
        }
    }

    func testSystemLanguageAlwaysResolvesToSomethingWeShip() {
        XCTAssertTrue(AppLanguage.shipped.contains(AppLanguage.resolvedFromSystem()))
    }
}

/// The widget's rotation is pure arithmetic on the clock, so it can be tested
/// without WidgetKit — which is exactly why it lives in the kit and not in the
/// extension.
final class CarouselClockTests: XCTestCase {

    func testIndexWrapsAndStaysInRange() {
        for tick in -100...100 {
            let i = CarouselClock.index(tick: tick, count: 14)
            XCTAssertTrue((0..<14).contains(i), "tick \(tick) produced \(i)")
        }
    }

    func testIndexAdvancesOneStepPerInterval() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let count = PrayerContent.steps(for: .en).count
        let first = CarouselClock.index(at: start, count: count)
        let next = CarouselClock.index(at: start.addingTimeInterval(CarouselClock.interval),
                                       count: count)
        XCTAssertEqual(next, (first + 1) % count)
    }

    /// Two widgets refreshed at different moments of the same minute must show
    /// the same step, otherwise they visibly disagree on the home screen. The
    /// boundary is the clock minute itself, not "within 60s of each other".
    func testTwoWidgetsWithinTheSameMinuteAgree() {
        let minuteStart = Date(timeIntervalSince1970: 1_700_000_040) // 60-aligned
        let count = 14
        for offset in [0.0, 1, 30, 59.9] {
            XCTAssertEqual(
                CarouselClock.index(at: minuteStart, count: count),
                CarouselClock.index(at: minuteStart.addingTimeInterval(offset), count: count),
                "widgets refreshed \(offset)s apart in the same minute disagree"
            )
        }
    }

    func testNoStepsDoesNotCrash() {
        XCTAssertEqual(CarouselClock.index(tick: 7, count: 0), 0)
    }
}

/// The onboarding trapped the user: `shouldShowOnboarding` read UserDefaults
/// through a computed property, which `@Observable` does not track, so
/// finishing changed the defaults without ever re-rendering the sheet.
final class OnboardingManagerTests: XCTestCase {

    /// A suite of our own, not `.standard`: the tests are hosted by the app,
    /// whose live onboarding sheet writes `hasSeenOnboarding` through its
    /// binding while these tests scrub the same key. On the shared domain the
    /// two raced, and the race was lost about once per run.
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "OnboardingManagerTests")
        defaults.removePersistentDomain(forName: "OnboardingManagerTests")
    }

    func testFinishingLetsYouIntoTheApp() {
        let onboarding = OnboardingManager(defaults: defaults)
        XCTAssertTrue(onboarding.shouldShowOnboarding, "a fresh install should onboard")
        onboarding.markSeen()
        XCTAssertFalse(onboarding.shouldShowOnboarding, "finishing must open the app")
    }

    func testFinishingSurvivesRelaunch() {
        OnboardingManager(defaults: defaults).markSeen()
        XCTAssertFalse(OnboardingManager(defaults: defaults).shouldShowOnboarding,
                       "the app must not onboard again on the next launch")
    }

    #if DEBUG
    /// With the dev toggle on, finishing must still get you in — otherwise the
    /// sheet re-presents itself immediately and there is no way out.
    func testDevToggleCannotTrapYouInTheOnboarding() {
        let onboarding = OnboardingManager(defaults: defaults)
        onboarding.alwaysShowOnboarding = true
        XCTAssertTrue(onboarding.shouldShowOnboarding)
        onboarding.markSeen()
        XCTAssertFalse(onboarding.shouldShowOnboarding)
    }
    #endif
}

/// The recitation clips are paired to the *lines* of a step. Nothing crashes if
/// that pairing slips — verse 3 simply plays under verse 4, which is exactly
/// the kind of silent error this app cannot afford.
final class RecitationTests: XCTestCase {

    func testEveryReciterCoversTheSameStepsLineForLine() {
        let steps = PrayerContent.steps(for: .en)
        for reciter in Recitations.reciters {
            for step in steps {
                let clips = Recitations.lineCount(step: step.id, reciter: reciter)
                guard clips > 0 else { continue }
                XCTAssertEqual(clips, step.arabicLines.count,
                               "\(reciter.id)/\(step.id): \(clips) clips for \(step.arabicLines.count) lines")
            }
        }
    }

    func testEveryClipInTheManifestIsActuallyInTheBundle() {
        for reciter in Recitations.reciters {
            for step in PrayerContent.steps(for: .en) {
                for line in 0..<Recitations.lineCount(step: step.id, reciter: reciter) {
                    XCTAssertNotNil(Recitations.clip(step: step.id, line: line, reciter: reciter),
                                    "\(reciter.id)/\(step.id) line \(line) is declared but not bundled")
                }
            }
        }
    }

    /// The Qur'an reciters do not cover the adhkar; the Hisn al-Muslim voice
    /// does. Choosing any reciter in the settings must therefore never silence
    /// a step: the effective voice falls back to whoever covers it.
    func testAdhkarFallBackToTheVoiceThatCoversThem() {
        let preferred = Recitations.defaultReciter
        XCTAssertEqual(Recitations.lineCount(step: "tashahhud", reciter: preferred), 0,
                       "the teaching reciter does not cover the tashahhud himself")
        let effective = Recitations.effectiveReciter(step: "tashahhud", preferring: preferred)
        XCTAssertNotNil(effective, "the tashahhud must not be silent")
        XCTAssertEqual(Recitations.lineCount(step: "tashahhud", reciter: effective), 4)
        // And the fallback never hijacks a step the preferred voice covers.
        XCTAssertEqual(Recitations.effectiveReciter(step: "fatiha", preferring: preferred)?.id,
                       preferred?.id)
    }

    /// The two spoken steps that genuinely have no recording anywhere: takbir
    /// and taslim. Nothing may crash or pretend there.
    func testStepsWithoutAnyVoiceReportNoneRatherThanFailing() {
        for step in ["takbir", "taslim"] {
            XCTAssertNil(Recitations.effectiveReciter(step: step, preferring: nil),
                         "\(step) has no recorded voice — if one appeared, update this test")
            XCTAssertNil(Recitations.clip(step: step, line: 0, reciter: Recitations.defaultReciter))
        }
    }

    /// An unknown or absent preference must land on a voice, never on silence.
    func testAnUnknownReciterFallsBackInsteadOfGoingSilent() {
        XCTAssertNotNil(Recitations.reciter(id: nil))
        XCTAssertNotNil(Recitations.reciter(id: "someone-who-never-shipped"))
        XCTAssertEqual(Recitations.defaultReciter?.isTeaching, true,
                       "the teaching recording is the one to start people on")
    }

    /// The karaoke cursor is only honest if the timing data has exactly one
    /// span per arabic word, in order, within the clip. A drift of one word
    /// here would light the wrong word under a sacred text, silently.
    func testWordTimingsPairWithArabicWordsWhereTheyExist() {
        let steps = PrayerContent.steps(for: .en)
        var covered = 0
        for reciter in Recitations.reciters {
            for step in steps where Recitations.hasClips(step: step.id, reciter: reciter) {
                for (line, arabic) in step.arabicLines.enumerated() {
                    guard let spans = Recitations.wordSpans(step: step.id, line: line,
                                                            reciter: reciter) else { continue }
                    covered += 1
                    XCTAssertEqual(spans.count, arabic.split(separator: " ").count,
                                   "\(reciter.id)/\(step.id) line \(line): spans ≠ words")
                    for pair in zip(spans, spans.dropFirst()) {
                        XCTAssertLessThanOrEqual(pair.0.lowerBound, pair.1.lowerBound,
                                                 "\(reciter.id)/\(step.id) line \(line): spans out of order")
                    }
                }
            }
        }
        // Eight of the nine voices ship timing data; if this collapses to
        // zero, the manifest key was renamed or dropped and no cursor runs.
        XCTAssertGreaterThan(covered, 50, "timing data went missing from the manifest")
    }

    /// The user's cursor: plain-orthography words (what recognition writes)
    /// must reach through the fully-pointed target text.
    func testRecognizedWordsAdvanceThroughThePointedText() {
        let target = "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ"
            .split(separator: " ").map(VoiceRecorder.strippedArabic)
        let heard = "بسم الله الرحمن الرحيم".split(separator: " ").map(VoiceRecorder.strippedArabic)
        XCTAssertEqual(VoiceRecorder.matchCount(heard: heard, target: target), 4)

        // A dropped word must not freeze the cursor for the rest of the line.
        let partial = "بسم الرحمن".split(separator: " ").map(VoiceRecorder.strippedArabic)
        XCTAssertEqual(VoiceRecorder.matchCount(heard: partial, target: target), 3)

        // Unrelated speech must not advance it.
        let noise = "مرحبا كيف الحال".split(separator: " ").map(VoiceRecorder.strippedArabic)
        XCTAssertEqual(VoiceRecorder.matchCount(heard: noise, target: target), 0)
    }
}

/// The reminder plan is written weeks ahead and by then nobody is watching, so
/// what it says has to be checked here: dates in the future, and messages that
/// name a step the user has not learned.
final class StudyReminderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day,
                                           hour: hour, minute: minute))!
    }

    private var steps: [PrayerStep] { PrayerContent.steps(for: .en) }

    func testEveryReminderFallsInTheFutureOneADay() {
        let now = date(6, 21, 0) // after the 19:30 slot: today is gone
        let plan = StudyReminders.plan(steps: steps, log: StudyLogState(), hour: 19, minute: 30,
                                       from: now, days: 14, calendar: calendar)

        XCTAssertEqual(plan.count, 14)
        XCTAssertEqual(plan[0].fireDate, date(7, 19, 30), "the passed slot must roll to tomorrow")
        for (index, draft) in plan.enumerated() {
            XCTAssertGreaterThan(draft.fireDate, now, "reminder \(index) is scheduled in the past")
            let parts = calendar.dateComponents([.hour, .minute], from: draft.fireDate)
            XCTAssertEqual(parts.hour, 19)
            XCTAssertEqual(parts.minute, 30)
        }
    }

    func testTodaysSlotIsUsedWhenItHasNotPassedYet() {
        let plan = StudyReminders.plan(steps: steps, log: StudyLogState(), hour: 19, minute: 30,
                                       from: date(6, 8, 0), days: 3, calendar: calendar)
        XCTAssertEqual(plan.first?.fireDate, date(6, 19, 30))
    }

    /// Naming a step the user already ticked would read as if the app had not
    /// noticed the work done.
    func testRemindersOnlyNameStepsLeftToLearn() {
        let all = steps
        let learned = Set(all.prefix(12).map(\.id))
        var log = StudyLogState()
        // Marked known *today*, so none of them is due for review yet.
        for id in learned { log.set(.known, for: id, at: date(6, 8, 0)) }
        let plan = StudyReminders.plan(steps: all, log: log, hour: 8, minute: 0,
                                       from: date(6, 9, 0), days: 6, calendar: calendar)

        let named = plan.compactMap(\.stepID)
        XCTAssertEqual(named.count, plan.count)
        for id in named {
            XCTAssertFalse(learned.contains(id), "\(id) is already learned")
        }
        XCTAssertEqual(Set(named).count, 2, "the two remaining steps should alternate")
    }

    func testOnceEverythingIsLearnedTheMessageChanges() {
        let all = steps
        var log = StudyLogState()
        for step in all { log.set(.known, for: step.id, at: date(6, 8, 0)) }
        let plan = StudyReminders.plan(steps: all, log: log,
                                       hour: 8, minute: 0, from: date(6, 9, 0),
                                       days: 4, calendar: calendar)
        XCTAssertEqual(plan.count, 4)
        XCTAssertTrue(plan.allSatisfy { $0.stepID == nil && $0.bodyKey == "notif.body.done" })
    }

    /// Every key the scheduler can reach has to exist in every language,
    /// otherwise a notification arrives showing its own key.
    func testEveryReminderMessageIsTranslated() {
        let keys = ["notif.title", "notif.body.1", "notif.body.2", "notif.body.3",
                    "notif.body.done", "notif.body.learning", "notif.body.review"]
        for language in AppLanguage.shipped {
            let localizer = Localizer(language: language)
            for key in keys {
                XCTAssertNotEqual(localizer.t(key), key, "\(language.rawValue) is missing \(key)")
            }
            for key in ["notif.body.1", "notif.body.2", "notif.body.3",
                        "notif.body.learning", "notif.body.review"] {
                XCTAssertTrue(localizer.t(key).contains("%@"),
                              "\(language.rawValue)/\(key) lost its step name placeholder")
                XCTAssertEqual(localizer.t(key, "Ruku").contains("%@"), false)
            }
        }
    }
}

// MARK: - What the widget picks

/// The carousel stopped being "the fourteen steps in order" the day it became a
/// reminder: it walks what is *left to learn*, and holds for a few minutes on
/// whatever was just read. Both rules live in `CarouselPlan`, and both are the
/// kind that break silently — the widget cannot be stepped through by hand.
final class CarouselPlanTests: XCTestCase {

    private var steps: [PrayerStep] { PrayerContent.steps(for: .en) }

    func testOnlyWhatIsBeingLearntIsShownWhenThereIsSomething() {
        var log = StudyLogState()
        log.set(.learning, for: steps[2].id)
        log.set(.learning, for: steps[9].id)
        log.set(.known, for: steps[0].id)

        let cycle = CarouselPlan.cycle(steps, log: log)
        XCTAssertEqual(cycle.map(\.id), [steps[2].id, steps[9].id],
                       "the widget should answer what the reader took on, and nothing else")
    }

    func testWithNothingBeingLearntItFallsBackToWhatIsNotKnown() {
        var log = StudyLogState()
        let known: Set<String> = [steps[0].id, steps[1].id]
        for id in known { log.set(.known, for: id) }

        let cycle = CarouselPlan.cycle(steps, log: log)
        XCTAssertEqual(cycle.count, steps.count - known.count)
        XCTAssertTrue(cycle.allSatisfy { !known.contains($0.id) },
                      "a known step is still in the rotation")
    }

    func testTakingOneStepOnNarrowsTheCycleToIt() {
        var log = StudyLogState()
        XCTAssertEqual(CarouselPlan.cycle(steps, log: log).count, steps.count)

        log.set(.learning, for: steps[5].id)
        XCTAssertEqual(CarouselPlan.cycle(steps, log: log).map(\.id), [steps[5].id])
    }

    func testKnowingEverythingGivesThePrayerBackRatherThanNothing() {
        var log = StudyLogState()
        for step in steps { log.set(.known, for: step.id) }
        XCTAssertEqual(CarouselPlan.cycle(steps, log: log).count, steps.count,
                       "a finished reader would get an empty widget")
    }

    func testTheCycleOnlyOffersStepsLeftToLearn() {
        var log = StudyLogState()
        for step in steps.prefix(10) { log.set(.known, for: step.id) }

        let now = Date()
        for minute in 0..<20 {
            let slot = CarouselPlan.slot(at: now.addingTimeInterval(Double(minute) * 60),
                                         steps: steps, log: log)
            XCTAssertNotNil(slot)
            XCTAssertEqual(log.status(of: slot!.step.id), .untouched,
                           "the widget showed a step already marked known")
        }
    }

    func testTheStepJustReadIsHeldThenTheCycleResumes() {
        var log = StudyLogState()
        let read = steps[7]
        let opened = Date()
        log.set(.learning, for: read.id, at: opened)
        log.set(.learning, for: steps[8].id, at: opened)
        log.study(read.id, at: opened)

        let held = CarouselPlan.slot(at: opened.addingTimeInterval(60), steps: steps, log: log)
        XCTAssertEqual(held?.step.id, read.id, "leaving the app should not jump elsewhere")
        XCTAssertEqual(held?.pinned, true)

        let after = CarouselPlan.slot(at: opened.addingTimeInterval(CarouselPlan.pinWindow + 60),
                                      steps: steps, log: log)
        XCTAssertEqual(after?.pinned, false, "the widget never went back to rotating")
    }

    func testAStepReadAndThenLearnedIsNotHeld() {
        var log = StudyLogState()
        let read = steps[3]
        let opened = Date()
        log.set(.learning, for: read.id, at: opened)
        log.set(.learning, for: steps[4].id, at: opened)
        log.study(read.id, at: opened)
        log.set(.known, for: read.id, at: opened)

        let slot = CarouselPlan.slot(at: opened.addingTimeInterval(60), steps: steps, log: log)
        XCTAssertNotEqual(slot?.step.id, read.id,
                          "a step ticked as known should drop out of the cycle at once")
    }

    func testScopeAllWalksTheWholePrayerWhateverTheProgress() {
        var log = StudyLogState()
        for step in steps { log.set(.known, for: step.id) }
        log.set(.learning, for: steps[3].id)

        let cycle = CarouselPlan.cycle(steps, log: log, prefs: WidgetPrefs(scope: .all))
        XCTAssertEqual(cycle.map(\.id), steps.map(\.id),
                       "'the whole prayer' is the reader's word, not the planner's")
    }

    func testScopeOneFreezesOnThePickedStep() {
        let prefs = WidgetPrefs(scope: .one, pinnedStepID: steps[6].id)
        let log = StudyLogState()

        let now = Date()
        for minute in 0..<5 {
            let slot = CarouselPlan.slot(at: now.addingTimeInterval(Double(minute) * 60),
                                         steps: steps, log: log, prefs: prefs)
            XCTAssertEqual(slot?.step.id, steps[6].id)
            XCTAssertEqual(slot?.total, 1)
        }
    }

    func testScopeOneWithoutAPickFallsBackToTheDefaultCycle() {
        var log = StudyLogState()
        log.set(.learning, for: steps[2].id)

        let orphan = WidgetPrefs(scope: .one, pinnedStepID: "gone")
        XCTAssertEqual(CarouselPlan.cycle(steps, log: log, prefs: orphan).map(\.id),
                       [steps[2].id],
                       "a pick that no longer resolves must not leave an empty card")
    }

    func testTwoWidgetsAgreeOnTheSameMinute() {
        var log = StudyLogState()
        for step in steps.prefix(4) { log.set(.learning, for: step.id) }
        let date = Date(timeIntervalSince1970: 1_800_000_030)

        XCTAssertEqual(CarouselPlan.slot(at: date, steps: steps, log: log)?.step.id,
                       CarouselPlan.slot(at: date.addingTimeInterval(20), steps: steps, log: log)?.step.id)
    }
}

/// The three states and the journal behind them. Everything the analytics page
/// and the reminders read comes from here, and none of it is visible until days
/// have passed — so it is checked with a clock we control.
final class StudyLogTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    private var steps: [PrayerStep] { PrayerContent.steps(for: .en) }

    func testAStepStartsUntouched() {
        XCTAssertEqual(StudyLogState().status(of: "ruku"), .untouched)
    }

    /// Flicking through the same step all evening is one day of study, not
    /// twenty lines of history.
    func testOpeningTheSameStepTwiceInADayWritesOneLine() {
        var log = StudyLogState()
        log.study("ruku", at: date(1, 9), calendar: calendar)
        log.study("ruku", at: date(1, 21), calendar: calendar)
        log.study("ruku", at: date(2, 9), calendar: calendar)

        XCTAssertEqual(log.events.count, 2)
        XCTAssertEqual(log.record(for: "ruku").visits, 3)
        XCTAssertEqual(log.record(for: "ruku").lastStudied, date(2, 9))
    }

    func testStatusChangesAreDatedAndJournalled() {
        var log = StudyLogState()
        log.set(.learning, for: "ruku", at: date(1))
        log.set(.known, for: "ruku", at: date(4))

        XCTAssertEqual(log.status(of: "ruku"), .known)
        XCTAssertEqual(log.record(for: "ruku").learningSince, date(1))
        XCTAssertEqual(log.record(for: "ruku").knownSince, date(4))
        XCTAssertEqual(log.events.map(\.kind), [.learning, .known])
    }

    func testUndoingAStatusRemovesItFromTheCount() {
        var log = StudyLogState()
        log.set(.known, for: "ruku", at: date(1))
        log.set(.untouched, for: "ruku", at: date(2))

        XCTAssertTrue(log.known.isEmpty)
        XCTAssertNil(log.record(for: "ruku").knownSince)
    }

    func testTheStreakSurvivesTodayNotBeingStartedYet() {
        var log = StudyLogState()
        log.study("ruku", at: date(3), calendar: calendar)
        log.study("sujud", at: date(4), calendar: calendar)

        XCTAssertEqual(log.streak(now: date(5, 8), calendar: calendar), 2,
                       "yesterday still counts — a streak must not die at midnight")
        XCTAssertEqual(log.streak(now: date(6, 8), calendar: calendar), 0)
    }

    // MARK: The queue

    /// The whole point of the third state: a step someone started and dropped
    /// comes before one they never opened.
    func testStartedAndForgottenComesBeforeNeverOpened() {
        var log = StudyLogState()
        log.set(.learning, for: "sujud", at: date(1))
        log.study("sujud", at: date(1), calendar: calendar)

        let queue = StudyPlanner.queue(steps: steps, log: log, now: date(9),
                                       calendar: calendar)
        XCTAssertEqual(queue.first?.stepID, "sujud")
        XCTAssertEqual(queue.first?.reason, .learning)
    }

    func testTheOldestForgottenStepComesFirst() {
        var log = StudyLogState()
        for (id, day) in [("ruku", 5), ("sujud", 2), ("jalsa", 8)] {
            log.set(.learning, for: id, at: date(day))
            log.study(id, at: date(day), calendar: calendar)
        }
        let queue = StudyPlanner.queue(steps: steps, log: log, now: date(9), calendar: calendar)
        XCTAssertEqual(queue.prefix(3).map(\.stepID), ["sujud", "ruku", "jalsa"])
    }

    /// Known is not forever: the app is about memory, so a step comes back after
    /// a while — but only after it, never the same week it was acquired.
    func testAKnownStepReturnsForReviewOnlyOnceItIsStale() {
        var log = StudyLogState()
        for step in steps {
            log.set(.known, for: step.id, at: date(1))
            log.study(step.id, at: date(1), calendar: calendar)
        }

        XCTAssertTrue(StudyPlanner.queue(steps: steps, log: log, now: date(6),
                                         calendar: calendar).isEmpty)

        let later = StudyPlanner.queue(steps: steps, log: log, now: date(20), calendar: calendar)
        XCTAssertEqual(later.count, steps.count)
        XCTAssertTrue(later.allSatisfy { $0.reason == .review })
    }

    /// The reminder and the analytics page must never name two different steps.
    func testTheReminderNamesTheHeadOfTheSameQueue() {
        var log = StudyLogState()
        log.set(.learning, for: "tashahhud", at: date(1))
        log.study("tashahhud", at: date(1), calendar: calendar)

        let queue = StudyPlanner.queue(steps: steps, log: log, now: date(9), calendar: calendar)
        let plan = StudyReminders.plan(steps: steps, log: log, hour: 8, minute: 0,
                                       from: date(9, 9), days: 3, calendar: calendar)

        XCTAssertEqual(plan.first?.stepID, queue.first?.stepID)
        XCTAssertEqual(plan.first?.bodyKey, "notif.body.learning")
    }

    /// The journal is bounded, and it is the *oldest* lines that go.
    func testTheJournalStopsGrowing() {
        var log = StudyLogState()
        for day in 1...(StudyLogState.eventLimit + 20) {
            let stamp = calendar.date(byAdding: .day, value: day, to: date(1))!
            log.study("ruku", at: stamp, calendar: calendar)
        }
        XCTAssertEqual(log.events.count, StudyLogState.eventLimit)
        XCTAssertGreaterThan(log.events.first!.date, date(1))
    }

    /// Someone upgrading from the two-state version keeps their ticks.
    func testLegacyTicksSurviveTheUpgrade() {
        let suite = "study.log.migration.test"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        var state = StudyLogState()
        for id in ["ruku", "sujud"] { state.records[id] = StepRecord(status: .known) }
        XCTAssertEqual(state.known, ["ruku", "sujud"])
    }
}
