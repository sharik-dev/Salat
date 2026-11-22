import XCTest
@testable import Salat

/// When the app asks for a rating on its own. "Rare" and "at a good moment"
/// are the whole feature, so they are what is tested: a rating asked after a
/// bad round, or twice in a day, is a bug, even though nothing crashes.
///
/// Since 22/11/2026 there is no Premium offer at a pause any more (the app is
/// behind a hard paywall) and no ads: the rating is all the planner decides.
final class NudgeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day = NudgePlanner.day

    /// Someone engaged: a week of use, half the prayer opened.
    private func context(days: Int = 7, steps: Int = 7, version: String = "1.4") -> NudgeContext {
        NudgeContext(now: now, version: version, studyDays: days, studiedSteps: steps, knownSteps: 2)
    }

    private func decide(_ moment: NudgeMoment, _ state: NudgeState = NudgeState(),
                        _ context: NudgeContext? = nil) -> Nudge {
        NudgePlanner.decide(moment, state: state, context: context ?? self.context())
    }

    func testARatingIsAskedOnAWinAndOnlyOnAWin() {
        XCTAssertEqual(decide(.stepAcquired), .review)
        XCTAssertEqual(decide(.roundFinished(right: 6, total: 8)), .review)
        XCTAssertEqual(decide(.roundFinished(right: 8, total: 8)), .review)
        // A round that went badly, or a page simply closed, never asks.
        XCTAssertEqual(decide(.roundFinished(right: 5, total: 8)), .none)
        XCTAssertEqual(decide(.roundFinished(right: 1, total: 8)), .none)
        XCTAssertEqual(decide(.stepClosed), .none)
    }

    func testARatingWaitsForSomeoneWhoHasComeBack() {
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), context(days: 1)), .none)
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), context(days: 2, steps: 2)), .none)
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), context(days: 3, steps: 3)), .review)
    }

    func testARatingIsAskedOncePerVersionAndNotWithinTwoMonths() {
        let sameVersion = NudgeState(lastReview: now.addingTimeInterval(-200 * day),
                                     lastReviewVersion: "1.4")
        XCTAssertEqual(decide(.stepAcquired, sameVersion), .none)

        let recent = NudgeState(lastReview: now.addingTimeInterval(-30 * day),
                                lastReviewVersion: "1.3")
        XCTAssertEqual(decide(.stepAcquired, recent), .none)

        let old = NudgeState(lastReview: now.addingTimeInterval(-61 * day),
                             lastReviewVersion: "1.3")
        XCTAssertEqual(decide(.stepAcquired, old), .review)
    }

    func testOneInterruptionADay() {
        var state = NudgeState()
        state.lastNudge = now.addingTimeInterval(-2 * 3600)
        XCTAssertEqual(decide(.stepAcquired, state), .none)

        state.lastNudge = now.addingTimeInterval(-21 * 3600)
        XCTAssertEqual(decide(.stepAcquired, state), .review)
    }

    /// A state saved by 1.6 (with the paywall's fields) still decodes: an
    /// update must not forget that a rating was already asked.
    func testAnOlderStateStillDecodes() throws {
        let json = #"{"autoPaywalls":2,"lastReviewVersion":"1.6","lastPaywall":800000000}"#
        let state = try JSONDecoder().decode(NudgeState.self, from: Data(json.utf8))
        XCTAssertEqual(state.lastReviewVersion, "1.6")
    }

    /// A whole first week, played forward: what a new reader actually meets.
    func testAFirstWeekIsNotAnAssault() {
        var state = NudgeState()
        var shown: [Nudge] = []
        for dayIndex in 0..<7 {
            // Four pauses a day: three pages closed, one decent round.
            for (slot, moment) in [NudgeMoment.stepClosed, .stepClosed,
                                   .roundFinished(right: 6, total: 8), .stepClosed].enumerated() {
                let at = now.addingTimeInterval(Double(dayIndex) * day + Double(slot) * 600)
                let context = NudgeContext(now: at, version: "1.4",
                                           studyDays: dayIndex + 1, studiedSteps: (dayIndex + 1) * 2,
                                           knownSteps: dayIndex)
                let decision = NudgePlanner.decide(moment, state: state, context: context)
                guard decision == .review else { continue }
                state.lastReview = at
                state.lastReviewVersion = "1.4"
                state.lastNudge = at
                shown.append(decision)
            }
        }
        // One rating request in the whole week, and nothing else.
        XCTAssertEqual(shown, [.review])
    }
}

/// The welcome's one number: the reader's hours a day, as days a year. Plain
/// arithmetic, never a statistic.
final class WelcomeReckoningTests: XCTestCase {
    func testHoursADayBecomeDaysAYear() {
        XCTAssertEqual(OnboardingManager.daysPerYear(hours: 1), 15)
        XCTAssertEqual(OnboardingManager.daysPerYear(hours: 4), 61)
        XCTAssertEqual(OnboardingManager.daysPerYear(hours: 8), 122)
        XCTAssertEqual(OnboardingManager.daysPerYear(hours: 0), 0)
    }
}
