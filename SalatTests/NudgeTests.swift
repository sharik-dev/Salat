import XCTest
@testable import Salat

/// When the app offers Premium or asks for a rating on its own. "Rare" and
/// "at a good moment" are the whole feature, so they are what is tested: an
/// offer on the first day, a rating asked after a bad round, or two full
/// screens back to back are bugs, even though nothing crashes.
final class NudgeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day = NudgePlanner.day

    /// Someone engaged: a week of use, half the prayer opened, no ad yet.
    private func context(premium: Bool = false, days: Int = 7, steps: Int = 7,
                         ads: Int = 0, lastAd: Date? = nil,
                         version: String = "1.4") -> NudgeContext {
        NudgeContext(now: now, version: version, isPremium: premium,
                     studyDays: days, studiedSteps: steps, knownSteps: 2,
                     adsSeen: ads, lastAd: lastAd)
    }

    /// Already asked for a rating on this version: only the offer is left.
    private var rated: NudgeState {
        NudgeState(lastReview: now.addingTimeInterval(-90 * day), lastReviewVersion: "1.4")
    }

    private func decide(_ moment: NudgeMoment, _ state: NudgeState = NudgeState(),
                        _ context: NudgeContext? = nil) -> Nudge {
        NudgePlanner.decide(moment, state: state, context: context ?? self.context())
    }

    // MARK: The rating

    func testARatingIsAskedOnAWinAndOnlyOnAWin() {
        XCTAssertEqual(decide(.stepAcquired), .review)
        XCTAssertEqual(decide(.roundFinished(right: 6, total: 8)), .review)
        XCTAssertEqual(decide(.roundFinished(right: 8, total: 8)), .review)
        // A round that went badly, or a page simply closed, never asks.
        XCTAssertNotEqual(decide(.roundFinished(right: 5, total: 8)), .review)
        XCTAssertNotEqual(decide(.roundFinished(right: 1, total: 8)), .review)
        XCTAssertNotEqual(decide(.stepClosed), .review)
    }

    func testARatingWaitsForSomeoneWhoHasComeBack() {
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), context(days: 1)), .none)
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), context(days: 2, steps: 2)), .none)
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), context(days: 3, steps: 3)), .review)
    }

    func testARatingIsAskedOncePerVersionAndNotWithinTwoMonths() {
        let sameVersion = NudgeState(lastReview: now.addingTimeInterval(-200 * day),
                                     lastReviewVersion: "1.4")
        XCTAssertNotEqual(decide(.stepAcquired, sameVersion), .review)

        let recent = NudgeState(lastReview: now.addingTimeInterval(-30 * day),
                                lastReviewVersion: "1.3")
        XCTAssertNotEqual(decide(.stepAcquired, recent), .review)

        let old = NudgeState(lastReview: now.addingTimeInterval(-61 * day),
                             lastReviewVersion: "1.3")
        XCTAssertEqual(decide(.stepAcquired, old), .review)
    }

    /// A subscriber is still asked: paying is not a reason to be left out.
    func testASubscriberCanStillBeAskedToRate() {
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), context(premium: true)), .review)
    }

    // MARK: The offer

    func testTheOfferComesAtAnOrdinaryPauseForSomeoneEngaged() {
        XCTAssertEqual(decide(.stepClosed, rated), .paywall(.widget))
        XCTAssertEqual(decide(.roundFinished(right: 4, total: 8), rated), .paywall(.widget))
    }

    func testTheOfferNeverComesOnTheFirstDayNorToASubscriber() {
        XCTAssertEqual(decide(.stepClosed, rated, context(days: 1)), .none)
        XCTAssertEqual(decide(.stepClosed, rated, context(days: 5, steps: 2)), .none)
        XCTAssertEqual(decide(.stepClosed, rated, context(premium: true)), .none)
    }

    /// Not on a step just acquired (the celebration's moment), and not after a
    /// round lost: nobody buys on a defeat.
    func testTheOfferStaysOutOfTheWrongMoments() {
        XCTAssertEqual(decide(.stepAcquired, rated), .none)
        XCTAssertEqual(decide(.roundFinished(right: 3, total: 8), rated), .none)
    }

    func testTheArgumentFollowsWhatTheReaderHasLivedWith() {
        XCTAssertEqual(decide(.stepClosed, rated, context(ads: 0)), .paywall(.widget))
        XCTAssertEqual(decide(.stepClosed, rated, context(ads: 3)), .paywall(.ads))
    }

    func testEachDeclinedOfferWidensTheWaitBeforeTheNext() {
        func due(shown: Int, daysAgo: Double) -> Bool {
            var state = rated
            state.autoPaywalls = shown
            state.lastPaywall = now.addingTimeInterval(-daysAgo * day)
            return decide(.stepClosed, state) != .none
        }
        XCTAssertFalse(due(shown: 1, daysAgo: 2))
        XCTAssertTrue(due(shown: 1, daysAgo: 3.1))
        XCTAssertFalse(due(shown: 2, daysAgo: 6))
        XCTAssertTrue(due(shown: 2, daysAgo: 7.1))
        XCTAssertFalse(due(shown: 3, daysAgo: 13))
        XCTAssertTrue(due(shown: 3, daysAgo: 14.1))
        // And then monthly, for good: it never becomes daily again.
        XCTAssertFalse(due(shown: 4, daysAgo: 29))
        XCTAssertFalse(due(shown: 40, daysAgo: 29))
        XCTAssertTrue(due(shown: 40, daysAgo: 30.1))
    }

    /// Someone who opened the paywall by hand this morning is not shown it
    /// again tonight: a visit counts as having seen it.
    func testAPaywallOpenedByHandAlsoResetsTheWait() {
        var state = rated
        state.lastPaywall = now.addingTimeInterval(-3600)
        XCTAssertEqual(decide(.stepClosed, state), .none)
    }

    // MARK: Never a wall

    func testNothingComesUpRightAfterAnAd() {
        let justNow = context(ads: 1, lastAd: now.addingTimeInterval(-30))
        XCTAssertEqual(decide(.stepAcquired, NudgeState(), justNow), .none)
        XCTAssertEqual(decide(.stepClosed, rated, justNow), .none)

        let earlier = context(ads: 1, lastAd: now.addingTimeInterval(-600))
        XCTAssertEqual(decide(.stepClosed, rated, earlier), .paywall(.ads))
    }

    func testOneInterruptionADayWhicheverItIs() {
        var state = NudgeState()
        state.lastNudge = now.addingTimeInterval(-2 * 3600)
        XCTAssertEqual(decide(.stepAcquired, state), .none)
        XCTAssertEqual(decide(.stepClosed, state), .none)

        state.lastNudge = now.addingTimeInterval(-21 * 3600)
        XCTAssertEqual(decide(.stepAcquired, state), .review)
    }

    /// When both are due at the same pause, the rating wins: it costs the
    /// reader nothing, and the offer will still be due tomorrow.
    func testTheRatingGoesBeforeTheOffer() {
        XCTAssertEqual(decide(.roundFinished(right: 7, total: 8)), .review)
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
                let context = NudgeContext(now: at, version: "1.4", isPremium: false,
                                           studyDays: dayIndex + 1, studiedSteps: (dayIndex + 1) * 2,
                                           knownSteps: dayIndex, adsSeen: dayIndex, lastAd: nil)
                let decision = NudgePlanner.decide(moment, state: state, context: context)
                switch decision {
                case .none: continue
                case .review:
                    state.lastReview = at
                    state.lastReviewVersion = "1.4"
                case .paywall:
                    state.autoPaywalls += 1
                    state.lastPaywall = at
                }
                state.lastNudge = at
                shown.append(decision)
            }
        }
        // Nothing on day one, one rating request, and two offers in the week
        // (day two, then three days later), never two things the same day.
        XCTAssertEqual(shown.filter { $0 == .review }.count, 1)
        XCTAssertEqual(shown.filter { $0 != .review }.count, 2)
        XCTAssertEqual(shown.count, 3)
    }
}
