import Foundation

/// What the drill remembers about a step: how often it was asked, how often it
/// came back right, and when it was last missed.
///
/// Deliberately *not* a second scheduler. `StudyPlanner` already decides what to
/// come back to, and two orderings would have the reminder naming one step while
/// the app pointed at another. This is a tally, and it does one thing: put the
/// steps you keep missing at the front of the next round.
public struct DrillScore: Codable, Hashable, Sendable {
    public var asked: Int
    public var right: Int
    public var lastMissed: Date?

    public init(asked: Int = 0, right: Int = 0, lastMissed: Date? = nil) {
        self.asked = asked
        self.right = right
        self.lastMissed = lastMissed
    }

    /// How much of it comes back, 0 to 1.
    ///
    /// This measures answers to questions the app itself wrote — not how the
    /// step is recited. The app scores nothing about a recitation and says so;
    /// counting whether you picked the right line out of four is a different
    /// thing, and it is the only way the drill can know what to ask again.
    public var recall: Double { asked == 0 ? 0 : Double(right) / Double(asked) }

    /// Five pips, the same ladder everywhere it is drawn. A step asked twice
    /// cannot fill the row: two right answers are not mastery, and a full row
    /// after one lucky guess would be a lie told in pictures.
    public var pips: Int {
        guard asked >= 2 else { return 0 }
        let earned = Int((recall * 5).rounded(.down))
        return max(0, min(earned, min(asked, 5)))
    }
}

public enum DrillLog {

    private static let key = "drill.scores"

    // MARK: The pure part

    /// The order the next round should ask in: missed first, then never asked,
    /// then the rest by how well they come back. Ties keep the order they came
    /// in, so a caller that shuffled first still gets a shuffled result inside
    /// each band.
    public static func priority(_ ids: [String], scores: [String: DrillScore]) -> [String] {
        ids.enumerated()
            .sorted { a, b in
                let ra = rank(scores[a.element]), rb = rank(scores[b.element])
                return ra == rb ? a.offset < b.offset : ra < rb
            }
            .map(\.element)
    }

    /// Lower is asked sooner.
    public static func rank(_ score: DrillScore?) -> Int {
        guard let score, score.asked > 0 else { return 1 }   // never asked
        if score.lastMissed != nil, score.recall < 0.75 { return 0 }
        return 2 + Int(score.recall * 4)
    }

    public static func updated(_ score: DrillScore, correct: Bool, at date: Date) -> DrillScore {
        var next = score
        next.asked += 1
        if correct { next.right += 1 } else { next.lastMissed = date }
        return next
    }

    // MARK: Storage

    public static var scores: [String: DrillScore] {
        get {
            guard let data = SharedStore.defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: DrillScore].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            SharedStore.defaults.set(data, forKey: key)
        }
    }

    public static func score(_ id: String) -> DrillScore { scores[id] ?? DrillScore() }

    /// Filed one question at a time, not once per round: a session abandoned
    /// halfway still said something about those steps.
    public static func record(step id: String, correct: Bool, at date: Date = Date()) {
        var all = scores
        all[id] = updated(all[id] ?? DrillScore(), correct: correct, at: date)
        scores = all
    }

    public static func reset() { SharedStore.defaults.removeObject(forKey: key) }
}
