import Foundation

// MARK: - Status

/// Where a step stands for this reader.
///
/// Two states were not enough. "I know it" is an answer, and an answer is rare:
/// most of the fourteen steps spend weeks in the middle — read a few times, half
/// held, and quietly lost again unless something points back at them. `learning`
/// is that middle, and it is what the reminders and the analytics page aim at.
/// Without it the app could only say "not done", which is the same thing it said
/// the day it was installed.
public enum StepStatus: String, Codable, Sendable, CaseIterable {
    case untouched
    case learning
    case known
}

// MARK: - One step's history

public struct StepRecord: Codable, Sendable, Equatable {
    public var status: StepStatus
    /// The last time the step was opened. This — not the status — is what
    /// "you haven't come back to it in a while" is measured against.
    public var lastStudied: Date?
    public var learningSince: Date?
    public var knownSince: Date?
    public var visits: Int

    public init(status: StepStatus = .untouched,
                lastStudied: Date? = nil,
                learningSince: Date? = nil,
                knownSince: Date? = nil,
                visits: Int = 0) {
        self.status = status
        self.lastStudied = lastStudied
        self.learningSince = learningSince
        self.knownSince = knownSince
        self.visits = visits
    }
}

// MARK: - One line of the journal

/// What the analytics page reads back: what happened, to which step, and when.
public struct StudyEvent: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case opened
        case learning
        case known
    }

    public let date: Date
    public let stepID: String
    public let kind: Kind

    /// Stable enough to key a `ForEach`: two events on the same step, the same
    /// kind and the same instant would be the same event.
    public var id: String { "\(stepID).\(kind.rawValue).\(date.timeIntervalSinceReferenceDate)" }

    public init(date: Date, stepID: String, kind: Kind) {
        self.date = date
        self.stepID = stepID
        self.kind = kind
    }
}

// MARK: - The whole log

/// Records *and* journal in one value, so the whole thing is written in one go
/// and can never be half-saved: a status change that landed without its event
/// would be a hole in the history the analytics page draws.
public struct StudyLogState: Codable, Sendable, Equatable {

    /// How many journal lines are kept. Enough for a year of daily reading,
    /// bounded so a shared `UserDefaults` never grows without end.
    public static let eventLimit = 500

    public var records: [String: StepRecord]
    /// Oldest first.
    public var events: [StudyEvent]

    public init(records: [String: StepRecord] = [:], events: [StudyEvent] = []) {
        self.records = records
        self.events = events
    }

    // MARK: Reading

    public func status(of id: String) -> StepStatus { records[id]?.status ?? .untouched }
    public func record(for id: String) -> StepRecord { records[id] ?? StepRecord() }

    public var known: Set<String> {
        Set(records.filter { $0.value.status == .known }.keys)
    }

    public var learning: Set<String> {
        Set(records.filter { $0.value.status == .learning }.keys)
    }

    /// The days the reader actually opened something, normalised to midnight —
    /// the grid on the analytics page and the streak both count these.
    public func studyDays(calendar: Calendar = .current) -> Set<Date> {
        Set(events.map { calendar.startOfDay(for: $0.date) })
    }

    /// Consecutive days up to today. Yesterday still counts as alive: a streak
    /// that dies at midnight punishes someone who reads at 23:50 one day and
    /// 00:10 the next.
    public func streak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = studyDays(calendar: calendar)
        guard !days.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        var cursor = days.contains(today) ? today : yesterday
        guard days.contains(cursor) else { return 0 }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    // MARK: Writing

    /// Opening a step. The visit is always counted, but only the *first* one of
    /// the day writes a journal line: someone flicking back and forth between
    /// two steps would otherwise fill the history with noise and push the real
    /// milestones out of the window.
    public mutating func study(_ id: String, at date: Date = Date(), calendar: Calendar = .current) {
        var record = records[id] ?? StepRecord()
        let alreadyToday = record.lastStudied.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        record.lastStudied = date
        record.visits += 1
        records[id] = record
        if !alreadyToday { append(StudyEvent(date: date, stepID: id, kind: .opened)) }
    }

    /// Declaring where a step stands. Going back down (known → learning, or
    /// either → untouched) is a correction and is recorded just the same: the
    /// history is what happened, not a highlight reel.
    public mutating func set(_ status: StepStatus, for id: String, at date: Date = Date()) {
        var record = records[id] ?? StepRecord()
        guard record.status != status else { return }
        record.status = status
        switch status {
        case .learning:
            record.learningSince = date
            record.knownSince = nil
        case .known:
            record.knownSince = date
            // Marked known straight away: the step still started somewhere.
            if record.learningSince == nil { record.learningSince = date }
        case .untouched:
            record.learningSince = nil
            record.knownSince = nil
        }
        if record.lastStudied == nil { record.lastStudied = date }
        records[id] = record

        if let kind = StudyEvent.Kind(status) {
            append(StudyEvent(date: date, stepID: id, kind: kind))
        }
    }

    private mutating func append(_ event: StudyEvent) {
        events.append(event)
        if events.count > Self.eventLimit {
            events.removeFirst(events.count - Self.eventLimit)
        }
    }
}

private extension StudyEvent.Kind {
    /// `untouched` has no line of its own — undoing a status is visible as the
    /// absence of the milestone, and a journal entry saying "nothing" reads as
    /// a bug.
    init?(_ status: StepStatus) {
        switch status {
        case .learning: self = .learning
        case .known:    self = .known
        case .untouched: return nil
        }
    }
}

// MARK: - Storage

/// The log lives in the shared suite next to the settings, as one JSON blob.
public enum StudyLog {

    public static func load() -> StudyLogState {
        guard let data = SharedStore.defaults.data(forKey: SharedStore.Key.studyLog),
              let state = try? JSONDecoder().decode(StudyLogState.self, from: data)
        else { return migratedFromLegacy() }
        return state
    }

    public static func save(_ state: StudyLogState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        SharedStore.defaults.set(data, forKey: SharedStore.Key.studyLog)
        // The old flat list is still written, and only written: it is what the
        // previous version of the app reads, and a reader who downgrades or
        // restores a backup should not find their fourteen ticks gone.
        SharedStore.defaults.set(Array(state.known), forKey: SharedStore.Key.learned)
    }

    /// Someone who already ticked steps in the two-state version keeps them, as
    /// `known`. The dates they were acquired on are lost — they were never
    /// recorded — so the journal starts empty rather than inventing a history.
    private static func migratedFromLegacy() -> StudyLogState {
        let legacy = SharedStore.defaults.stringArray(forKey: SharedStore.Key.learned) ?? []
        guard !legacy.isEmpty else { return StudyLogState() }
        var state = StudyLogState()
        for id in legacy {
            state.records[id] = StepRecord(status: .known)
        }
        return state
    }

    public static func clear() {
        SharedStore.defaults.removeObject(forKey: SharedStore.Key.studyLog)
        SharedStore.defaults.removeObject(forKey: SharedStore.Key.learned)
    }
}

// MARK: - What to work on next

/// The one ordering the app has: it drives the reminders *and* the "what to go
/// back to" list on the analytics page. Two orderings would mean the notification
/// naming one step and the screen naming another.
public enum StudyPlanner {

    public enum Reason: String, Sendable {
        /// Started, not finished, and untouched for the longest.
        case learning
        /// Never opened.
        case new
        /// Known, but not seen in a while — memory is the point of the app.
        case review
    }

    public struct Due: Sendable, Equatable, Identifiable {
        public let stepID: String
        public let reason: Reason
        public let lastStudied: Date?
        public var id: String { stepID }

        public init(stepID: String, reason: Reason, lastStudied: Date?) {
            self.stepID = stepID
            self.reason = reason
            self.lastStudied = lastStudied
        }
    }

    /// A step marked known goes back in the queue after this long. Ten days is
    /// short enough that a whole prayer never drifts out of reach, long enough
    /// that finishing a step is still worth something.
    public static let reviewAfterDays = 10

    public static func queue(steps: [PrayerStep],
                             log: StudyLogState,
                             now: Date = Date(),
                             reviewAfterDays: Int = reviewAfterDays,
                             calendar: Calendar = .current) -> [Due] {

        /// Never opened sorts before everything: no date is older than any date.
        func staler(_ a: PrayerStep, _ b: PrayerStep) -> Bool {
            switch (log.record(for: a.id).lastStudied, log.record(for: b.id).lastStudied) {
            case (nil, nil):              return a.order < b.order
            case (nil, _):                return true
            case (_, nil):                return false
            case let (x?, y?):            return x == y ? a.order < b.order : x < y
            }
        }

        let learning = steps
            .filter { log.status(of: $0.id) == .learning }
            .sorted(by: staler)
            .map { Due(stepID: $0.id, reason: .learning, lastStudied: log.record(for: $0.id).lastStudied) }

        // In prayer order, not by staleness: a step never opened has no history
        // to be stale against, and reading the prayer in order is how it is
        // learned.
        let new = steps
            .filter { log.status(of: $0.id) == .untouched }
            .map { Due(stepID: $0.id, reason: .new, lastStudied: nil) }

        let cutoff = calendar.date(byAdding: .day, value: -reviewAfterDays, to: now) ?? now
        let review = steps
            .filter { step in
                guard log.status(of: step.id) == .known else { return false }
                guard let seen = log.record(for: step.id).lastStudied else { return true }
                return seen <= cutoff
            }
            .sorted(by: staler)
            .map { Due(stepID: $0.id, reason: .review, lastStudied: log.record(for: $0.id).lastStudied) }

        return learning + new + review
    }
}
