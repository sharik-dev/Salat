import Foundation

/// What the widget shows, and when.
///
/// The carousel used to walk the fourteen steps in order. That spends most of
/// the day on what the reader already knows — a widget is a *reminder*, and
/// reminding someone of what they hold is wasted screen. The cycle is therefore
/// the steps that are **not known yet**, in order.
///
/// The one exception is the step just read. Coming out of the app, the widget
/// should still be showing what was being worked on rather than jumping
/// somewhere else: for a few minutes the last opened step is pinned, then the
/// cycle resumes where the clock says it should be.
///
/// This is a pure value, deliberately: the widget extension has no way to be
/// stepped through, so what decides *which step* has to be testable from the
/// app's own test target.
public enum CarouselPlan {

    /// How long the step just read stays on the widget before the cycle takes
    /// over. Long enough to still be there when the phone is put down, short
    /// enough that the widget does not freeze on one step for the evening.
    public static let pinWindow: TimeInterval = 5 * 60

    public struct Slot: Equatable, Sendable {
        public let step: PrayerStep
        /// Rank inside the cycle, 1-based, and how many steps the cycle holds.
        public let position: Int
        public let total: Int
        /// True when this is the step just read rather than the cycle's turn.
        public let pinned: Bool
    }

    /// The steps the carousel rotates through: everything not marked known.
    /// A reader who knows all fourteen gets the whole prayer back rather than
    /// an empty widget — at that point it is a rehearsal, not a lesson.
    public static func cycle(_ steps: [PrayerStep], known: Set<String>) -> [PrayerStep] {
        let remaining = steps.filter { !known.contains($0.id) }
        return remaining.isEmpty ? steps : remaining
    }

    /// The step to draw at `date`.
    public static func slot(at date: Date,
                            steps: [PrayerStep],
                            log: StudyLogState) -> Slot? {
        let cycle = cycle(steps, known: log.known)
        guard !cycle.isEmpty else { return nil }

        if let pinned = pinned(at: date, cycle: cycle, log: log) {
            return pinned
        }

        let index = CarouselClock.index(at: date, count: cycle.count)
        return Slot(step: cycle[index], position: index + 1, total: cycle.count, pinned: false)
    }

    /// The last step opened, if it was opened recently **and** still belongs to
    /// the cycle. A step read and then ticked as known is not pinned: the whole
    /// point of the cycle is to leave what is held behind.
    private static func pinned(at date: Date,
                               cycle: [PrayerStep],
                               log: StudyLogState) -> Slot? {
        var best: (step: PrayerStep, index: Int, date: Date)?
        for (index, step) in cycle.enumerated() {
            guard let studied = log.record(for: step.id).lastStudied else { continue }
            if best == nil || studied > best!.date {
                best = (step, index, studied)
            }
        }
        guard let best,
              date >= best.date,
              date.timeIntervalSince(best.date) < pinWindow
        else { return nil }

        return Slot(step: best.step, position: best.index + 1, total: cycle.count, pinned: true)
    }
}
