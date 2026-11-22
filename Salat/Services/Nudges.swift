import StoreKit
import SwiftUI

/// The one thing the app asks of its reader on its own initiative: to rate
/// it. An interruption, so it is rare, it waits for a moment when nothing is
/// being read or recited, and the decision is a pure value (`NudgePlanner`) so
/// "rare" and "well timed" are held by tests and not by hope.
///
/// It only ever happens at a **pause**: a step page closed, a round of
/// exercises finished. Since 22/11/2026 the app has no ads and no Premium
/// offer to push (the whole app is for subscribers, behind a hard paywall):
/// the rating request is all that is left here.

// MARK: - What is remembered

struct NudgeState: Codable, Equatable {
    /// The last time the app interrupted on its own.
    var lastNudge: Date?
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
}

/// Everything the decision reads, gathered by the caller.
struct NudgeContext {
    var now: Date
    var version: String
    /// Days on which a step was studied, steps ever opened, steps acquired.
    var studyDays: Int
    var studiedSteps: Int
    var knownSteps: Int
}

// MARK: - The decision

enum NudgePlanner {
    static let day: TimeInterval = 24 * 3600

    /// One interruption of ours per day.
    static let quiet: TimeInterval = 20 * 3600

    /// A rating is asked of someone who has come back on three different days
    /// and has opened at least three steps: an opinion needs something to be
    /// about. Then never more than once every two months, once per version.
    /// (iOS itself shows the sheet three times a year at most, whatever is
    /// asked of it.)
    static let reviewDays = 3
    static let reviewSteps = 3
    static let reviewGap: TimeInterval = 60 * day

    static func decide(_ moment: NudgeMoment, state: NudgeState, context c: NudgeContext) -> Nudge {
        if let last = state.lastNudge, c.now.timeIntervalSince(last) < quiet { return .none }
        if isHappy(moment), reviewIsDue(state: state, context: c) { return .review }
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

    static func reviewIsDue(state: NudgeState, context c: NudgeContext) -> Bool {
        guard c.studyDays >= reviewDays, c.studiedSteps >= reviewSteps else { return false }
        guard state.lastReviewVersion != c.version else { return false }
        if let last = state.lastReview, c.now.timeIntervalSince(last) < reviewGap { return false }
        return true
    }
}

// MARK: - The pauses

@MainActor
final class Nudges {
    static let shared = Nudges()

    private static let key = "nudges.state"
    private var state: NudgeState
    /// Set when a step is marked acquired; consumed by the close that follows.
    private var pendingWin = false
    #if DEBUG
    private var forced = LaunchOptions.forcedNudge
    #endif

    private init() {
        // An older state (with the paywall fields of 1.6 and before) decodes
        // too: unknown keys are ignored.
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(NudgeState.self, from: data) {
            state = stored
        } else {
            state = NudgeState()
        }
    }

    /// A step was just marked acquired: its page is about to close on a win.
    func stepAcquired() { pendingWin = true }

    /// A pause just happened. Asks for a rating if one is due.
    func pause(_ moment: NudgeMoment) {
        var moment = moment
        if moment == .stepClosed, pendingWin { moment = .stepAcquired }
        pendingWin = false

        let now = Date()
        var decision = NudgePlanner.decide(moment, state: state, context: context(at: now))
        #if DEBUG
        // `-forceNudge review`: the next pause, whatever the history.
        if forced == "review" {
            decision = .review
            forced = nil
        }
        #endif

        // Pas de demande de note : la pause revient aux pubs (en pause tant
        // que `Ads.enabled` est faux).
        guard decision == .review else { Ads.shared.breakPoint(); return }
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
    }

    private func context(at now: Date) -> NudgeContext {
        let log = StudyLog.load()
        return NudgeContext(now: now,
                            version: Self.version,
                            studyDays: log.studyDays().count,
                            studiedSteps: log.records.values.filter { $0.lastStudied != nil }.count,
                            knownSteps: log.known.count)
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
