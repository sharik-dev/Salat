import SwiftUI

// MARK: - Matching pairs

/// Two shuffled columns, tap one on each side. A right match settles into
/// green and locks; a wrong one flashes sand and counts against the round.
/// The board owns its transient state and resets with `.id(exercise.id)` —
/// only the outcome leaves through `onComplete`.
struct PairsBoard: View {
    let exercise: PairsExercise
    let locked: Bool
    /// Called once, when the last pair falls: `true` if no match ever missed.
    let onComplete: (Bool) -> Void

    @State private var matched: Set<Int> = []
    @State private var mistakes = 0
    @State private var pickedReading: Int?
    @State private var pickedMeaning: Int?
    /// The rows of a failed match, kept lit long enough to be seen.
    @State private var misfire: (reading: Int, meaning: Int)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                ForEach(exercise.readingOrder.indices, id: \.self) { row in
                    chip(exercise.pairs[exercise.readingOrder[row]].reading,
                         face: readingFace(row), lit: pickedReading == row,
                         done: matched.contains(exercise.readingOrder[row])) {
                        tapReading(row)
                    }
                    .accessibilityIdentifier("drill.pairs.reading.\(row)")
                }
            }
            VStack(spacing: 10) {
                ForEach(exercise.meaningOrder.indices, id: \.self) { row in
                    chip(exercise.pairs[exercise.meaningOrder[row]].meaning,
                         face: meaningFace(row), lit: pickedMeaning == row,
                         done: matched.contains(exercise.meaningOrder[row])) {
                        tapMeaning(row)
                    }
                    .accessibilityIdentifier("drill.pairs.meaning.\(row)")
                }
            }
        }
        .animation(Theme.spring, value: matched)
        .animation(Theme.spring, value: pickedReading)
        .animation(Theme.spring, value: pickedMeaning)
    }

    private func chip(_ text: String, face: Color, lit: Bool, done: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Theme.body(14))
                .foregroundStyle(done ? Theme.inkSoft : Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
        }
        .chunky(face, radius: 14, haptic: lit ? nil : .select, sparks: false)
        .disabled(locked || done)
        .opacity(done ? 0.55 : 1)
    }

    private func readingFace(_ row: Int) -> Color {
        face(pair: exercise.readingOrder[row],
             lit: pickedReading == row, missed: misfire?.reading == row)
    }

    private func meaningFace(_ row: Int) -> Color {
        face(pair: exercise.meaningOrder[row],
             lit: pickedMeaning == row, missed: misfire?.meaning == row)
    }

    private func face(pair: Int, lit: Bool, missed: Bool) -> Color {
        if matched.contains(pair) { return Theme.greenSoft }
        if missed { return Theme.sand }
        return lit ? Theme.goldSoft : Theme.surface
    }

    private func tapReading(_ row: Int) {
        guard !locked, !matched.contains(exercise.readingOrder[row]) else { return }
        pickedReading = pickedReading == row ? nil : row
        resolve()
    }

    private func tapMeaning(_ row: Int) {
        guard !locked, !matched.contains(exercise.meaningOrder[row]) else { return }
        pickedMeaning = pickedMeaning == row ? nil : row
        resolve()
    }

    private func resolve() {
        guard let r = pickedReading, let m = pickedMeaning else { return }
        let reading = exercise.readingOrder[r]
        let meaning = exercise.meaningOrder[m]
        pickedReading = nil
        pickedMeaning = nil
        if reading == meaning {
            matched.insert(reading)
            Haptic.select.play()
            if matched.count == exercise.pairs.count {
                onComplete(mistakes == 0)
            }
        } else {
            mistakes += 1
            misfire = (r, m)
            Haptic.tap.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                misfire = nil
            }
        }
    }
}

// MARK: - Word order

/// The word bank: the line's own words, shuffled, picked back into order. The
/// chosen sequence lives in the parent — it is the answer the check reads.
struct OrderBoard: View {
    let exercise: OrderExercise
    let locked: Bool
    /// Indices into `exercise.bank`, in the order they were tapped.
    @Binding var placed: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let arabic = exercise.arabic, !arabic.isEmpty {
                Text(arabic)
                    .font(Theme.arabic(24))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            Text(exercise.meaning)
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            answerStrip
            bank
        }
        .animation(Theme.spring, value: placed)
    }

    /// Where the sentence takes shape. A sand well rather than ruled lines:
    /// the plate language has no pencil rules, and an empty well already
    /// reads as "put something here".
    private var answerStrip: some View {
        FlowLayout(spacing: 8) {
            ForEach(placed, id: \.self) { i in
                Button { unplace(i) } label: { chipLabel(exercise.bank[i]) }
                    .chunky(Theme.goldSoft, radius: 10, haptic: .select, sparks: false)
                    .disabled(locked)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.sand)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.45), lineWidth: 1.5)
                )
        )
        .accessibilityIdentifier("drill.order.answer")
    }

    private var bank: some View {
        FlowLayout(spacing: 8) {
            ForEach(exercise.bank.indices, id: \.self) { i in
                let used = placed.contains(i)
                Button { place(i) } label: {
                    // The hole stays: a bank that reflows under the thumb
                    // makes the next word land somewhere else.
                    chipLabel(exercise.bank[i]).opacity(used ? 0 : 1)
                }
                .chunky(used ? Theme.sand : Theme.surface, radius: 10,
                        haptic: .select, sparks: false)
                .disabled(locked || used)
                .accessibilityIdentifier("drill.order.word.\(i)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func chipLabel(_ word: String) -> some View {
        Text(word)
            .font(Theme.body(15))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
    }

    private func place(_ i: Int) {
        guard !locked, !placed.contains(i) else { return }
        placed.append(i)
    }

    private func unplace(_ i: Int) {
        guard !locked else { return }
        placed.removeAll { $0 == i }
    }
}

// MARK: - Flow layout

/// Chips laid left to right, wrapping like text. The one custom `Layout` in
/// the app — both boards need it, nothing else does.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let positions = arrange(proposal: proposal, subviews: subviews).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                          proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize,
                         subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: maxWidth.isFinite ? maxWidth : widest, height: y + rowHeight),
                positions)
    }
}
