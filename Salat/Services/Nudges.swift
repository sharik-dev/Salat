import StoreKit
import SwiftUI

/// The two things the app asks of its reader on its own initiative: to look at
/// Salat Premium, and to rate the app. Both are interruptions, so both are
/// rare, both wait for a moment when nothing is being read or recited, and the
/// decision is a pure value (`NudgePlanner`) so "rare" and "well timed" are
/// held by tests and not by hope.
///
/// They only ever happen at a **pause**, the same two the ads use: a step page
/// closed, a round of exercises finished. A pause shows one thing at most: the
/// rating request, or the Premium offer, or (neither being due) the ad's own
/// count moves on. Never two in a row.

// MARK: - What is remembered

struct NudgeState: Codable, Equatable {
    /// The last time the app interrupted on its own, whichever of the two.
    var lastNudge: Date?
    /// The last time the paywall was on screen, opened by hand or not: someone
    /// who went to look at the offer this morning is not shown it tonight.
    var lastPaywall: Date?
    /// How many times the offer came up uninvited. Each one widens the gap
    /// before the next.
    var autoPaywalls = 0
    var lastReview: Date?
    /// One request per version at most: asked again for the same build, the
    /// answer has not changed.
    var lastReviewVersion: String?
}

/// A pause, and what kind.
enum NudgeMoment: Equatable {
    case stepClosed
    /// A step page closed right after the step was marked acquired.
    case stepAcquired
    case roundFinished(right: Int, total: Int)
}

enum Nudge: Equatable {
    case none
    case review
    case paywall(PaywallReason)
}

/// Why the paywall is on screen, which decides the argument it leads with.
enum PaywallReason: String, Equatable {
    /// The reader tapped their way in.
    case manual
    /// Offered at a pause to someone who has not met the ads yet: the widget.
    case widget
    /// Offered at a pause to someone who has: no more ads.
    case ads
}

/// Everything the decision reads, gathered by the caller.
struct NudgeContext {
    var now: Date
    var version: String
    var isPremium: Bool
    /// Days on which a step was studied, steps ever opened, steps acquired.
    var studyDays: Int
    var studiedSteps: Int
    var knownSteps: Int
    /// Ads shown since install, and when the last one was.
    var adsSeen: Int
    var lastAd: Date?
}

// MARK: - The decision

enum NudgePlanner {
    static let day: TimeInterval = 24 * 3600

    /// One interruption of ours per day, whichever it is.
    static let quiet: TimeInterval = 20 * 3600
    /// Nothing right after an ad: two full screens back to back is a wall.
    static let afterAd: TimeInterval = 120

    /// A rating is asked of someone who has come back on three different days
    /// and has opened at least three steps: an opinion needs something to be
    /// about. Then never more than once every two months, once per version.
    /// (iOS itself shows the sheet three times a year at most, whatever is
    /// asked of it.)
    static let reviewDays = 3
    static let reviewSteps = 3
    static let reviewGap: TimeInterval = 60 * day

    /// The offer waits for the second day and the third step: on the first
    /// day the app has not shown what it is yet. Then the gap widens each time
    /// it was declined: three days, a week, two weeks, then monthly.
    static let paywallDays = 2
    static let paywallSteps = 3
    static let paywallGaps: [TimeInterval] = [3 * day, 7 * day, 14 * day, 30 * day]

    static func paywallGap(after shown: Int) -> TimeInterval {
        paywallGaps[min(max(shown - 1, 0), paywallGaps.count - 1)]
    }

    static func decide(_ moment: NudgeMoment, state: NudgeState, context c: NudgeContext) -> Nudge {
        // Shared by both: not twice in a day, and never on the heels of an ad.
        if let last = state.lastNudge, c.now.timeIntervalSince(last) < quiet { return .none }
        if let ad = c.lastAd, c.now.timeIntervalSince(ad) < afterAd { return .none }

        if isHappy(moment), reviewIsDue(state: state, context: c) { return .review }
        if offerFits(moment), offerIsDue(state: state, context: c) {
            return .paywall(c.adsSeen > 0 ? .ads : .widget)
        }
        return .none
    }

    /// A rating is asked on a win and only on a win: a step just acquired, or
    /// a round with three answers in four right. Asked after a bad round, the
    /// reader rates the round.
    static func isHappy(_ moment: NudgeMoment) -> Bool {
        switch moment {
        case .stepAcquired: return true
        case .roundFinished(let right, let total): return total >= 4 && right * 4 >= total * 3
        case .stepClosed: return false
        }
    }

    /// The offer comes at an ordinary pause. Not on a step just acquired (that
    /// moment belongs to the celebration), and not after a round that went
    /// badly: half right at least, nobody buys on a defeat.
    static func offerFits(_ moment: NudgeMoment) -> Bool {
        switch moment {
        case .stepClosed: return true
        case .stepAcquired: return false
        case .roundFinished(let right, let total): return total > 0 && right * 2 >= total
        }
    }

    static func reviewIsDue(state: NudgeState, context c: NudgeContext) -> Bool {
        guard c.studyDays >= reviewDays, c.studiedSteps >= reviewSteps else { return false }
        guard state.lastReviewVersion != c.version else { return false }
        if let last = state.lastReview, c.now.timeIntervalSince(last) < reviewGap { return false }
        return true
    }

    static func offerIsDue(state: NudgeState, context c: NudgeContext) -> Bool {
        guard !c.isPremium else { return false }
        guard c.studyDays >= paywallDays, c.studiedSteps >= paywallSteps else { return false }
        if let last = state.lastPaywall,
           c.now.timeIntervalSince(last) < paywallGap(after: state.autoPaywalls) { return false }
        return true
    }
}

// MARK: - Ads seen

/// How many ads this install has shown. Kept apart from `Ads` so the planner
/// can read it in a build where the ad SDK is not linked.
enum AdTally {
    private static let key = "ads.shownCount"
    static var shown: Int { UserDefaults.standard.integer(forKey: key) }
    static func bump() { UserDefaults.standard.set(shown + 1, forKey: key) }
}

// MARK: - The pauses

@MainActor
final class Nudges {
    static let shared = Nudges()

    private static let key = "nudges.state"
    private var state: NudgeState
    private weak var store: Store?
    /// Set when a step is marked acquired; consumed by the close that follows.
    private var pendingWin = false
    #if DEBUG
    private var forced = LaunchOptions.forcedNudge
    #endif

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(NudgeState.self, from: data) {
            state = stored
        } else {
            state = NudgeState()
        }
    }

    func attach(_ store: Store) { self.store = store }

    /// A step was just marked acquired: its page is about to close on a win.
    func stepAcquired() { pendingWin = true }

    /// The paywall came on screen, by hand or not.
    func paywallSeen() {
        state.lastPaywall = Date()
        save()
    }

    /// A pause just happened. Shows the rating request or the Premium offer if
    /// one is due, and otherwise hands the pause to the ads.
    func pause(_ moment: NudgeMoment) {
        var moment = moment
        if moment == .stepClosed, pendingWin { moment = .stepAcquired }
        pendingWin = false

        let now = Date()
        var decision = NudgePlanner.decide(moment, state: state, context: context(at: now))
        #if DEBUG
        // `-forceNudge paywall|review`: the next pause, whatever the history.
        if let forced {
            decision = forced == "review" ? .review : .paywall(AdTally.shown > 0 ? .ads : .widget)
            self.forced = nil
        }
        #endif

        switch decision {
        case .none:
            Ads.shared.breakPoint()

        case .review:
            state.lastNudge = now
            state.lastReview = now
            state.lastReviewVersion = Self.version
            save()
            // After the sheet has slid away and the celebration has gone: the
            // system's card over a moving screen is easy to dismiss by reflex.
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                guard UIApplication.shared.applicationState == .active,
                      let scene = Self.activeScene() else { return }
                AppStore.requestReview(in: scene)
            }

        case .paywall(let reason):
            state.lastNudge = now
            state.autoPaywalls += 1
            save()
            Task {
                try? await Task.sleep(for: .seconds(0.7))
                guard UIApplication.shared.applicationState == .active,
                      let store, !store.isPremium else { return }
                store.present(reason)
            }
        }
    }

    private func context(at now: Date) -> NudgeContext {
        let log = StudyLog.load()
        let last = Ads.shared.lastAd
        return NudgeContext(now: now,
                            version: Self.version,
                            isPremium: store?.isPremium ?? Premium.isActive,
                            studyDays: log.studyDays().count,
                            studiedSteps: log.records.values.filter { $0.lastStudied != nil }.count,
                            knownSteps: log.known.count,
                            adsSeen: AdTally.shown,
                            lastAd: last == .distantPast ? nil : last)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private static func activeScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
