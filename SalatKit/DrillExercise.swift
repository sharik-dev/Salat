import Foundation

// MARK: - Matching pairs

/// The tap-the-pairs board: four lines of one step on one side, their four
/// translations on the other, both columns shuffled. Cut from a single step
/// rather than across the prayer so that matching still exercises *that*
/// formula — and so the answer can be filed against one step's memory card.
public struct PairsExercise: Identifiable, Hashable, Sendable {
    public struct Pair: Hashable, Sendable {
        /// The line as the drill reads it — phonetic, or Arabic in Arabic.
        public let reading: String
        public let meaning: String

        public init(reading: String, meaning: String) {
            self.reading = reading
            self.meaning = meaning
        }
    }

    public let id: String
    public let stepID: String
    /// The truth: `pairs[i].reading` matches `pairs[i].meaning`.
    public let pairs: [Pair]
    /// Column orders, drawn at build time so the board is part of the seed —
    /// a session that shuffled in the view could never be replayed.
    public let readingOrder: [Int]
    public let meaningOrder: [Int]

    public init(id: String, stepID: String, pairs: [Pair],
                readingOrder: [Int], meaningOrder: [Int]) {
        self.id = id
        self.stepID = stepID
        self.pairs = pairs
        self.readingOrder = readingOrder
        self.meaningOrder = meaningOrder
    }
}

// MARK: - Word order

/// Rebuild one line from its own words, shuffled — the word-bank exercise.
/// Nothing is invented here either: the bank is the line itself, cut on spaces.
public struct OrderExercise: Identifiable, Hashable, Sendable {
    public let id: String
    public let stepID: String
    /// The Arabic of the line, shown only where the answer is a phonetic. In
    /// Arabic the reading *is* the Arabic, and printing it above the bank
    /// would hand over the answer in full — so there it stays nil.
    public let arabic: String?
    public let meaning: String
    /// The words in prayer order.
    public let answer: [String]
    /// The same words, shuffled — never dealt in the right order.
    public let bank: [String]

    public init(id: String, stepID: String, arabic: String?,
                meaning: String, answer: [String], bank: [String]) {
        self.id = id
        self.stepID = stepID
        self.arabic = arabic
        self.meaning = meaning
        self.answer = answer
        self.bank = bank
    }
}

// MARK: - One exercise

/// What a round is actually made of. The multiple-choice question keeps its
/// type untouched; the two board exercises ride alongside it.
public enum DrillExercise: Identifiable, Hashable, Sendable {
    case choice(DrillQuestion)
    case pairs(PairsExercise)
    case order(OrderExercise)

    public var id: String {
        switch self {
        case .choice(let q): return q.id
        case .pairs(let p):  return p.id
        case .order(let o):  return o.id
        }
    }

    public var stepID: String {
        switch self {
        case .choice(let q): return q.stepID
        case .pairs(let p):  return p.stepID
        case .order(let o):  return o.stepID
        }
    }

    public var promptKey: String {
        switch self {
        case .choice(let q): return q.promptKey
        case .pairs:         return "drill.q.pairs"
        case .order:         return "drill.q.order"
        }
    }
}

// MARK: - Choosing your exercise

/// One face of the picker gallery: an exercise the reader chooses to work,
/// rather than the mix the round deals. `mixed` stays the daily default; the
/// others each run a single kind, which is the whole point of choosing.
public enum DrillFocus: Hashable, Sendable {
    case mixed
    case kind(DrillQuestion.Kind)
    case pairs
    case order

    /// The cards of the gallery, in the order the kinds teach: prayer
    /// structure first, then the texts, then the boards.
    public static var gallery: [DrillFocus] {
        DrillQuestion.Kind.allCases.map(DrillFocus.kind) + [.pairs, .order]
    }

    /// The card and the run title reuse the prompt strings — the question an
    /// exercise asks is the best possible name for it, and it is already
    /// translated fourteen times.
    public var titleKey: String {
        switch self {
        case .mixed:       return "drill.picker.mixed.title"
        case .kind(let k): return "drill.q.\(k.rawValue)"
        case .pairs:       return "drill.q.pairs"
        case .order:       return "drill.q.order"
        }
    }
}

/// A run as the reader ordered it: which exercise, and optionally which step.
/// `subject` narrows the questions, never the distractors — a wrong answer
/// drawn from elsewhere in the prayer is still a wrong answer.
public struct DrillRun: Hashable, Sendable {
    public let focus: DrillFocus
    public let subject: String?

    public init(focus: DrillFocus = .mixed, subject: String? = nil) {
        self.focus = focus
        self.subject = subject
    }
}

public extension Drill {

    /// The chosen run. Candidates are always built over the whole pool and
    /// narrowed afterwards: the builders' own guards (a next step that has
    /// been read, an illustration that belongs to one step alone) need the
    /// full picture to judge, and a subject filter applied before them would
    /// change which questions are legal.
    static func run(_ run: DrillRun,
                    steps: [PrayerStep],
                    pool: Set<String>,
                    priority: [String] = [],
                    count: Int = sessionLength,
                    seed: UInt64) -> [DrillExercise] {
        let asked = steps.filter { pool.contains($0.id) }
        guard asked.count >= 2 else { return [] }

        func narrowed<T>(_ items: [T], step: (T) -> String) -> [T] {
            guard let subject = run.subject else { return items }
            return items.filter { step($0) == subject }
        }

        switch run.focus {
        case .mixed where run.subject == nil:
            return round(steps: steps, pool: pool, priority: priority,
                         count: count, seed: seed)

        case .mixed:
            // One step, every kind: the choice heaps flattened, plus that
            // step's boards woven in at even intervals like the dealt round.
            var rng = SeededRandom(seed: seed)
            var out: [DrillExercise] = narrowed(
                DrillQuestion.Kind.allCases.flatMap {
                    candidates($0, steps: steps, asked: asked, rng: &rng)
                }, step: \.stepID)
                .shuffled(using: &rng)
                .prefix(count)
                .map(DrillExercise.choice)
            var boardRng = SeededRandom(seed: seed ^ 0x51AC_ED17)
            let extras: [DrillExercise] =
                narrowed(pairsCandidates(asked: asked, rng: &boardRng),
                         step: \.stepID).map(DrillExercise.pairs)
                + narrowed(orderCandidates(asked: asked, rng: &boardRng),
                           step: \.stepID).shuffled(using: &boardRng)
                    .prefix(2).map(DrillExercise.order)
            let total = out.count + extras.count
            for (i, extra) in extras.enumerated() {
                let slot = ((i + 1) * total) / (extras.count + 1)
                out.insert(extra, at: min(max(slot, min(1, out.count)), out.count))
            }
            return Array(out.prefix(count))

        case .kind(let kind):
            var rng = SeededRandom(seed: seed)
            return narrowed(candidates(kind, steps: steps, asked: asked, rng: &rng),
                            step: \.stepID)
                .shuffled(using: &rng)
                .prefix(count)
                .map(DrillExercise.choice)

        case .pairs:
            var rng = SeededRandom(seed: seed ^ 0x51AC_ED17)
            return narrowed(pairsCandidates(asked: asked, rng: &rng), step: \.stepID)
                .shuffled(using: &rng)
                .prefix(count)
                .map(DrillExercise.pairs)

        case .order:
            var rng = SeededRandom(seed: seed ^ 0x51AC_ED17)
            return narrowed(orderCandidates(asked: asked, rng: &rng), step: \.stepID)
                .shuffled(using: &rng)
                .prefix(count)
                .map(DrillExercise.order)
        }
    }

    /// How many exercises a card would open on. The gallery greys a card out
    /// rather than opening an empty run — a door onto nothing teaches that
    /// doors lie. Fixed seed: availability is a fact about the content, not
    /// about a sitting.
    static func available(_ run: DrillRun,
                          steps: [PrayerStep],
                          pool: Set<String>) -> Int {
        self.run(run, steps: steps, pool: pool, count: Int.max, seed: 0xA11).count
    }
}

// MARK: - The mixed round

public extension Drill {

    /// How many pairs a matching board holds.
    static let pairCount = 4

    /// A round that mixes the multiple-choice questions with one matching
    /// board and up to two word-order lines, woven in at even intervals — the
    /// first exercise is always a familiar tap-a-card question, never a board.
    /// Same seed, same round, exactly like `session`.
    static func round(steps: [PrayerStep],
                      pool: Set<String>,
                      priority: [String] = [],
                      count: Int = sessionLength,
                      seed: UInt64) -> [DrillExercise] {
        let asked = steps.filter { pool.contains($0.id) }
        guard asked.count >= 2 else { return [] }

        // A separate stream from `session`'s: the boards must not shift which
        // multiple-choice questions come out of the same seed.
        var rng = SeededRandom(seed: seed ^ 0x51AC_ED17)
        let urgency = Dictionary(uniqueKeysWithValues: priority.enumerated().map { ($1, $0) })

        // Shuffled first, urgency as the sort key, shuffled position as the
        // tiebreak — the same ranking `session` applies to its heaps.
        func rank<T>(_ items: [T], step: (T) -> String) -> [T] {
            items.shuffled(using: &rng).enumerated()
                .sorted { a, b in
                    let ua = urgency[step(a.element)] ?? Int.max
                    let ub = urgency[step(b.element)] ?? Int.max
                    return ua == ub ? a.offset < b.offset : ua < ub
                }
                .map(\.element)
        }

        var extras: [DrillExercise] = []
        if let board = rank(pairsCandidates(asked: asked, rng: &rng), step: \.stepID).first {
            extras.append(.pairs(board))
        }
        var orderSteps = Set<String>()
        let orders = rank(orderCandidates(asked: asked, rng: &rng), step: \.stepID)
            .filter { orderSteps.insert($0.stepID).inserted }
            .prefix(2)
        extras.append(contentsOf: orders.map(DrillExercise.order))

        let choices = session(steps: steps, pool: pool, priority: priority,
                              count: max(count - extras.count, 1), seed: seed)
            .map(DrillExercise.choice)
        guard !choices.isEmpty else { return extras.isEmpty ? [] : Array(extras.prefix(count)) }

        var out = choices
        let total = out.count + extras.count
        for (i, extra) in extras.enumerated() {
            let slot = ((i + 1) * total) / (extras.count + 1)
            out.insert(extra, at: min(max(slot, 1), out.count))
        }
        return out
    }

    // MARK: Candidates

    /// One matching board per step that can afford it: four lines with four
    /// distinct readings and four distinct translations. Internal, not
    /// private, so the tests can sweep every candidate rather than the one a
    /// seed happens to deal.
    static func pairsCandidates(asked: [PrayerStep],
                                rng: inout SeededRandom) -> [PairsExercise] {
        asked.filter(\.spoken).compactMap { step in
            let lines = step.readingLines
            let meanings = step.translationLines
            guard meanings.count == lines.count else { return nil }

            var pairs: [PairsExercise.Pair] = []
            var readings = Set<String>(), told = Set<String>()
            for i in lines.indices.shuffled(using: &rng) {
                let reading = lines[i].trimmingCharacters(in: .whitespaces)
                let meaning = meanings[i].trimmingCharacters(in: .whitespaces)
                // Two identical texts on one side would be two right answers.
                guard !reading.isEmpty, meaning.count > 3,
                      readings.insert(reading).inserted,
                      told.insert(meaning).inserted else { continue }
                pairs.append(.init(reading: reading, meaning: meaning))
                if pairs.count == pairCount { break }
            }
            guard pairs.count == pairCount else { return nil }

            let readingOrder = Array(pairs.indices).shuffled(using: &rng)
            var meaningOrder = Array(pairs.indices).shuffled(using: &rng)
            if meaningOrder == readingOrder {
                // Fully level columns solve every row by its neighbour.
                meaningOrder = [meaningOrder.removeLast()] + meaningOrder
            }
            return PairsExercise(id: "pairs.\(step.id)", stepID: step.id, pairs: pairs,
                                 readingOrder: readingOrder, meaningOrder: meaningOrder)
        }
    }

    /// One word-order exercise per line that can afford it: four to ten words,
    /// at least three distinct, and a translation to stand as the prompt.
    static func orderCandidates(asked: [PrayerStep],
                                rng: inout SeededRandom) -> [OrderExercise] {
        asked.filter(\.spoken).flatMap { step -> [OrderExercise] in
            let lines = step.readingLines
            let meanings = step.translationLines
            // When the reading fell back to the Arabic (the Arabic language),
            // the Arabic line must not be printed as a prompt — it is the answer.
            let phonetic = lines != step.arabicLines
            return lines.indices.compactMap { i in
                let words = lines[i].split(separator: " ").map(String.init)
                guard (4...10).contains(words.count), Set(words).count >= 3,
                      let meaning = meanings[at: i]?.trimmingCharacters(in: .whitespaces),
                      meaning.count > 3 else { return nil }
                var bank = words.shuffled(using: &rng)
                if bank == words,
                   let j = bank.indices.dropFirst().first(where: { bank[$0] != bank[0] }) {
                    bank.swapAt(0, j)
                }
                return OrderExercise(id: "order.\(step.id).\(i)", stepID: step.id,
                                     arabic: phonetic ? step.arabicLines[at: i] : nil,
                                     meaning: meaning, answer: words, bank: bank)
            }
        }
    }
}

private extension Array {
    subscript(at index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
