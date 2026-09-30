import SwiftUI

/// The word being sung, lit inside its line — the karaoke cursor.
///
/// Two honesty rules, because this app teaches a sacred text:
///
/// - The **arabic** cursor is exact: it comes from quran-align's word-level
///   timestamps, measured on these very recordings.
/// - The **phonetic** cursor is a projection. No language splits its
///   transliteration into the same word count as the arabic (`Bismillaahi`
///   *is* بِسْمِ + اللَّهِ fused), so the arabic index is mapped onto the
///   phonetic words proportionally, anchored at both ends. That is a guide
///   for the eye, not a measurement — which is exactly what a follow-along
///   cursor is for.
enum Karaoke {

    /// Which word of `spans` sounds at `time`. Between two words (a breath,
    /// a lengthened vowel) the cursor holds on the word just said instead of
    /// going dark and flickering back.
    static func wordIndex(at time: Double, in spans: [ClosedRange<Double>]) -> Int? {
        if let exact = spans.firstIndex(where: { $0.contains(time) }) { return exact }
        guard let first = spans.first, time >= first.lowerBound else { return nil }
        return spans.lastIndex { $0.upperBound <= time }
    }

    /// Projects an arabic word index onto a differently-split word list.
    static func projected(_ index: Int, from sourceCount: Int, onto targetCount: Int) -> Int {
        guard sourceCount > 1, targetCount > 0 else { return 0 }
        let fraction = Double(index) / Double(sourceCount - 1)
        return min(targetCount - 1, Int((fraction * Double(targetCount - 1)).rounded()))
    }

    /// The line as one `Text`, with word `active` in `tint` and, when
    /// `saidTint` is given, every word before it tinted too — the "already
    /// sung" trail of a karaoke line.
    static func line(_ string: String, active: Int?, base: Color, tint: Color,
                     saidTint: Color? = nil) -> Text {
        let words = string.split(separator: " ", omittingEmptySubsequences: true)
        var result = Text(verbatim: "")
        for (index, word) in words.enumerated() {
            if index > 0 { result = result + Text(verbatim: " ") }
            let color: Color = switch (active, saidTint) {
            case let (.some(a), _) where index == a: tint
            case let (.some(a), .some(said)) where index < a: said
            default: base
            }
            result = result + Text(verbatim: String(word)).foregroundColor(color)
        }
        return result
    }
}
