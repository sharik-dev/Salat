import Foundation

// MARK: - Flashcards

/// One card of the deck. The front is the meaning alone: printing the Arabic
/// or the phonetic there would hand over the very thing the card asks you to
/// recall. The back is the check — Arabic, and the reading where one exists.
public struct Flashcard: Identifiable, Hashable, Sendable {
    public let id: String
    public let stepID: String
    /// The Arabic of the line — always on the back.
    public let arabic: String
    /// The reading as the drill reads it; nil when it *is* the Arabic (the
    /// Arabic language), where printing it twice would say nothing.
    public let reading: String?
    /// The meaning — the front of the card.
    public let meaning: String

    public init(id: String, stepID: String, arabic: String,
                reading: String?, meaning: String) {
        self.id = id
        self.stepID = stepID
        self.arabic = arabic
        self.reading = reading
        self.meaning = meaning
    }
}

public enum Flashcards {

    /// How many cards a deck deals at most. A deck is one sitting; the lines
    /// left out come up under another seed.
    public static let deckSize = 12

    /// The deck: one card per line of the spoken steps already read, shuffled
    /// by the seed and capped. Nothing is invented — every card is a line of
    /// `steps.<language>.json`, and only the steps in `pool` are dealt, for
    /// the same reason the drill only asks about them.
    public static func deck(steps: [PrayerStep],
                            pool: Set<String>,
                            seed: UInt64) -> [Flashcard] {
        var rng = SeededRandom(seed: seed ^ 0xF1A5_CA2D)
        let cards = steps
            .filter { pool.contains($0.id) && $0.spoken }
            .flatMap { step -> [Flashcard] in
                let arabics = step.arabicLines
                let readings = step.readingLines
                let meanings = step.translationLines
                guard meanings.count == arabics.count else { return [] }
                let phonetic = readings != arabics && readings.count == arabics.count
                return arabics.indices.compactMap { i in
                    let arabic = arabics[i].trimmingCharacters(in: .whitespaces)
                    let meaning = meanings[i].trimmingCharacters(in: .whitespaces)
                    guard !arabic.isEmpty, meaning.count > 3 else { return nil }
                    return Flashcard(id: "flash.\(step.id).\(i)", stepID: step.id,
                                     arabic: arabic,
                                     reading: phonetic ? readings[i] : nil,
                                     meaning: meaning)
                }
            }
        return Array(cards.shuffled(using: &rng).prefix(deckSize))
    }
}

// MARK: - Fading recitation

/// The classic memorisation ladder: the same text, shown with fewer and fewer
/// words, until reciting it leans on nothing. The plan is pure arithmetic so
/// the same step always fades the same way — a word, once hidden, must stay
/// hidden on the next level, or the ladder would feel like a slot machine.
public enum Fade {

    /// How many rungs the ladder has. Level 0 shows everything, the last
    /// level shows nothing.
    public static let levels = 4

    /// Which words of a line are hidden at a level. Deterministic per step
    /// and line — no seed argument: the ladder is a property of the text,
    /// not of the sitting — and monotonic: `hidden(level: n)` is always a
    /// subset of `hidden(level: n + 1)`.
    public static func hiddenWords(stepID: String, lineIndex: Int,
                                   wordCount: Int, level: Int) -> Set<Int> {
        guard wordCount > 0, level > 0 else { return [] }
        guard level < levels - 1 else { return Set(0..<wordCount) }

        // Rounded up: on a two-word line the first rung already hides one
        // word, otherwise short formulas would not fade until the very end.
        let count = (wordCount * level + (levels - 2)) / (levels - 1)
        var rng = SeededRandom(seed: seed(stepID) ^ UInt64(lineIndex))
        let order = Array(0..<wordCount).shuffled(using: &rng)
        return Set(order.prefix(count))
    }

    /// A stable seed for a step id. `String.hashValue` is randomised per
    /// launch and would deal a different ladder every time.
    static func seed(_ id: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
