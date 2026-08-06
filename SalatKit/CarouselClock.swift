import Foundation

/// Which step the passive carousel shows at a given moment.
///
/// The rotation is derived from the wall clock rather than from a counter, so
/// two widgets placed on different screens — and the app's own Practice tab —
/// land on the same step instead of drifting apart. It also means a widget
/// that iOS refreshed late resumes where it should be, not where it left off.
public enum CarouselClock {
    /// One step per minute: the fastest cadence WidgetKit actually honours.
    public static let interval: TimeInterval = 60

    /// How many entries a timeline carries before iOS asks for a new one.
    public static let horizon = 60

    public static func tick(at date: Date, interval: TimeInterval = interval) -> Int {
        Int(date.timeIntervalSince1970 / interval)
    }

    /// Index into `count` steps, wrapping — never negative, never out of range.
    public static func index(tick: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((tick % count) + count) % count
    }

    public static func index(at date: Date, count: Int) -> Int {
        index(tick: tick(at: date), count: count)
    }
}
