import Foundation

// MARK: - Determinism

/// Same steps, same seed, same questions.
///
/// A drill built on `Int.random` cannot be tested: a run that produced a
/// question with two right answers, or with the answer among the distractors,
/// could never be replayed. Every draw here goes through this generator, and
/// the seed is the session's identity.
public struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - A question

/// One multiple-choice question. Four options, one right, and the step it came
/// from — that last field is the whole point: the answer feeds back into the
/// step's memory card, so a session teaches the app what to ask next time.
public struct DrillQuestion: Identifiable, Hashable, Sendable {

    public enum Kind: String, CaseIterable, Sendable {
        /// Which step follows this one. The only question about the prayer as
        /// a whole rather than about a text.
        case nextStep = "next_step"
        /// The posture is shown, the words are asked.
        case posture
        /// The next line of a multi-line formula — the classic hifz drill.
        case nextLine = "next_line"
        /// One word hidden inside a line.
        case blank
        /// A meaning is given, the line that carries it is asked.
        case meaning
    }

    public let id: String
    public let kind: Kind
    public let stepID: String
    /// The Arabic of the line being asked about, when showing it helps rather
    /// than gives the answer away. Nil for `blank`, where it *is* the answer.
    public let arabic: String?
    /// The text the question is about. Empty for `posture`, which shows the
    /// illustration instead.
    public let subject: String
    public let options: [String]
    public let answer: Int

    public var promptKey: String { "drill.q.\(kind.rawValue)" }
    public var correctOption: String { options[answer] }

    public init(id: String, kind: Kind, stepID: String, arabic: String?,
                subject: String, options: [String], answer: Int) {
        self.id = id
        self.kind = kind
        self.stepID = stepID
        self.arabic = arabic
        self.subject = subject
        self.options = options
        self.answer = answer
    }
}

// MARK: - The generator

public enum Drill {

    /// Eight questions: long enough to touch several steps, short enough to be
    /// done standing up. A round that outlasts the attention it needs is a
    /// round nobody finishes.
    public static let sessionLength = 8

    /// How many options every question carries.
    public static let optionCount = 4

    /// A round drawn from `pool` — the steps the user has actually read.
    ///
    /// Asking about a step nobody has opened is not an exercise, it is a
    /// guess: the drill only ever revisits, which is exactly what *Learn* does
    /// not do. `steps` stays the full list because the wrong answers are drawn
    /// from all of it — a distractor nobody has read is still a wrong answer.
    /// - Parameter priority: step ids, most urgent first — what `DrillLog`
    ///   makes of past rounds. A step you keep missing comes back before one you
    ///   answer every time; steps left out of the list simply carry no urgency.
    public static func session(steps: [PrayerStep],
                               pool: Set<String>,
                               priority: [String] = [],
                               count: Int = sessionLength,
                               seed: UInt64) -> [DrillQuestion] {
        var rng = SeededRandom(seed: seed)
        let asked = steps.filter { pool.contains($0.id) }
        guard asked.count >= 2 else { return [] }

        let urgency = Dictionary(uniqueKeysWithValues: priority.enumerated().map { ($1, $0) })

        // Built kind by kind, then dealt round-robin: taking the first eight of
        // one shuffled heap gives sessions that are all "next line", and the
        // variety is what keeps a round from feeling like a form to fill in.
        var heaps: [[DrillQuestion]] = DrillQuestion.Kind.allCases.map { kind in
            candidates(kind, steps: steps, asked: asked, rng: &rng)
                .shuffled(using: &rng)
                // Shuffled first, then ordered by urgency with the shuffled
                // position as tiebreak: the weak steps rise to the top without
                // the round becoming the same eight questions every time.
                .enumerated()
                .sorted { a, b in
                    let ua = urgency[a.element.stepID] ?? Int.max
                    let ub = urgency[b.element.stepID] ?? Int.max
                    return ua == ub ? a.offset < b.offset : ua < ub
                }
                .map(\.element)
        }
        heaps.shuffle(using: &rng)

        var out: [DrillQuestion] = []
        while out.count < count, heaps.contains(where: { !$0.isEmpty }) {
            for i in heaps.indices where out.count < count {
                if !heaps[i].isEmpty { out.append(heaps[i].removeFirst()) }
            }
        }
        return out
    }

    // MARK: Per-kind candidates

    /// Internal, not private: the chosen-exercise run (`Drill.run`) draws one
    /// kind's heap on its own instead of dealing round-robin.
    static func candidates(_ kind: DrillQuestion.Kind,
                           steps: [PrayerStep],
                           asked: [PrayerStep],
                           rng: inout SeededRandom) -> [DrillQuestion] {
        switch kind {
        case .nextStep: return nextStepQuestions(steps: steps, asked: asked, rng: &rng)
        case .posture:  return postureQuestions(steps: steps, asked: asked, rng: &rng)
        case .nextLine: return lineQuestions(steps: steps, asked: asked, rng: &rng)
        case .blank:    return blankQuestions(steps: steps, asked: asked, rng: &rng)
        case .meaning:  return meaningQuestions(steps: steps, asked: asked, rng: &rng)
        }
    }

    private static func nextStepQuestions(steps: [PrayerStep], asked: [PrayerStep],
                                          rng: inout SeededRandom) -> [DrillQuestion] {
        let names = steps.map(\.name)
        return asked.compactMap { step in
            // The step after it has to be one they have read too, otherwise the
            // right answer is a name they have never seen.
            guard let next = steps.first(where: { $0.order == step.order + 1 }),
                  asked.contains(where: { $0.id == next.id }) else { return nil }
            return build(id: "next_step.\(step.id)", kind: .nextStep, stepID: step.id,
                         arabic: nil, subject: step.name,
                         answer: next.name, from: names, rng: &rng)
        }
    }

    private static func postureQuestions(steps: [PrayerStep], asked: [PrayerStep],
                                         rng: inout SeededRandom) -> [DrillQuestion] {
        let names = steps.map(\.name)
        // Four steps share the standing illustration and two share the
        // prostration one: asking "which words go here" over an image that fits
        // several steps has more than one right answer. Only the steps whose
        // picture belongs to them alone can be asked this way.
        let unique = Dictionary(grouping: steps, by: \.image)
            .filter { $0.value.count == 1 }
            .map(\.key)
        return asked.filter { unique.contains($0.image) }.compactMap { step in
            build(id: "posture.\(step.id)", kind: .posture, stepID: step.id,
                  arabic: nil, subject: "", answer: step.name, from: names, rng: &rng)
        }
    }

    private static func lineQuestions(steps: [PrayerStep], asked: [PrayerStep],
                                      rng: inout SeededRandom) -> [DrillQuestion] {
        let pool = allLines(steps)
        return asked.filter(\.spoken).flatMap { step -> [DrillQuestion] in
            let lines = step.readingLines
            guard lines.count >= 2 else { return [] }
            return (0..<(lines.count - 1)).compactMap { i in
                build(id: "next_line.\(step.id).\(i)", kind: .nextLine, stepID: step.id,
                      arabic: step.arabicLines[safe: i], subject: lines[i],
                      answer: lines[i + 1], from: pool, rng: &rng)
            }
        }
    }

    private static func blankQuestions(steps: [PrayerStep], asked: [PrayerStep],
                                       rng: inout SeededRandom) -> [DrillQuestion] {
        let vocabulary = allLines(steps).flatMap { $0.split(separator: " ").map(String.init) }
            .filter { $0.count >= 4 }
        return asked.filter(\.spoken).flatMap { step -> [DrillQuestion] in
            step.readingLines.enumerated().compactMap { i, line in
                let words = line.split(separator: " ").map(String.init)
                // Under four words there is nothing to hide: blanking one out
                // of three leaves a question anyone answers by elimination.
                guard words.count >= 4,
                      let hidden = words.dropFirst().first(where: { $0.count >= 4 }),
                      let at = words.firstIndex(of: hidden) else { return nil }
                var masked = words
                masked[at] = String(repeating: "•", count: max(3, min(hidden.count, 8)))
                // No Arabic here, unlike the other kinds: the line printed in
                // Arabic next to its own gap is the answer, in full.
                return build(id: "blank.\(step.id).\(i)", kind: .blank, stepID: step.id,
                             arabic: nil, subject: masked.joined(separator: " "),
                             answer: hidden,
                             from: vocabulary.filter { !words.contains($0) },
                             rng: &rng)
            }
        }
    }

    private static func meaningQuestions(steps: [PrayerStep], asked: [PrayerStep],
                                         rng: inout SeededRandom) -> [DrillQuestion] {
        let pool = allLines(steps)
        return asked.filter(\.spoken).flatMap { step -> [DrillQuestion] in
            let lines = step.readingLines
            let meanings = step.translationLines
            guard meanings.count == lines.count else { return [] }
            return lines.indices.compactMap { i in
                guard meanings[i].count > 12 else { return nil }
                return build(id: "meaning.\(step.id).\(i)", kind: .meaning, stepID: step.id,
                             arabic: nil, subject: meanings[i],
                             answer: lines[i], from: pool, rng: &rng)
            }
        }
    }

    // MARK: Plumbing

    /// Every line of every spoken step, deduplicated: the shared pool the wrong
    /// answers are drawn from. A distractor taken from the prayer itself is
    /// plausible; a made-up one is not, and would be answered by style alone.
    private static func allLines(_ steps: [PrayerStep]) -> [String] {
        var seen = Set<String>()
        return steps.filter(\.spoken).flatMap(\.readingLines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return false }
            seen.insert(trimmed)
            return true
        }
    }

    /// Assembles a question, or gives up when three distinct wrong answers
    /// cannot be found — a question with a duplicated option has two right
    /// answers, and there is no honest way to mark it.
    private static func build(id: String, kind: DrillQuestion.Kind, stepID: String,
                              arabic: String?, subject: String, answer: String,
                              from pool: [String], rng: inout SeededRandom) -> DrillQuestion? {
        let wrong = pool
            .filter { $0 != answer && $0 != subject }
            .shuffled(using: &rng)
            .reduce(into: [String]()) { acc, candidate in
                if acc.count < optionCount - 1, !acc.contains(candidate) { acc.append(candidate) }
            }
        guard wrong.count == optionCount - 1 else { return nil }

        var options = wrong + [answer]
        options.shuffle(using: &rng)
        guard let at = options.firstIndex(of: answer) else { return nil }
        return DrillQuestion(id: id, kind: kind, stepID: stepID, arabic: arabic,
                             subject: subject, options: options, answer: at)
    }
}

// MARK: - Small helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public extension PrayerStep {
    /// The lines the drill reads from: the phonetic in every language that
    /// writes one, the Arabic itself in Arabic — where the phonetic field is
    /// empty by design, since the reader is already reading the text.
    var readingLines: [String] {
        let phonetic = phoneticLines
        let written = phonetic.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return written && phonetic.count == arabicLines.count ? phonetic : arabicLines
    }
}
