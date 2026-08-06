import SwiftUI

/// A round of eight questions.
///
/// This is what the tab is for: *Learn* shows you the prayer, the drill asks
/// you about it. Nothing here is new content — every question is built from the
/// steps already read, and every answer files itself into that step's memory
/// card, which is what decides when it comes back.
struct DrillSessionView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    @State private var questions: [DrillQuestion] = []
    @State private var index = 0
    /// Which option the finger landed on. Nil while the question is open: it is
    /// also the flag that locks the row once an answer is given.
    @State private var picked: Int?
    @State private var right = 0
    @State private var seed = UInt64(Date().timeIntervalSince1970)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if questions.isEmpty {
                    emptyState
                } else if index >= questions.count {
                    summary
                } else {
                    progress
                    QuestionCard(question: questions[index], picked: picked)
                    options(for: questions[index])
                    if picked != nil { verdict(for: questions[index]) }
                }
                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .animation(Theme.spring, value: index)
            .animation(Theme.spring, value: picked)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(loc.t("revise.tool.drill.title"))
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
        .task { deal() }
    }

    // MARK: Pieces

    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressBar(value: Double(index), total: Double(questions.count))
                .frame(height: 8)
            Text("\(index + 1) / \(questions.count)")
                .font(Theme.pixel(11))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    private func options(for question: DrillQuestion) -> some View {
        VStack(spacing: 8) {
            ForEach(question.options.indices, id: \.self) { i in
                Button { answer(i, of: question) } label: {
                    HStack(spacing: 10) {
                        Text(question.options[i])
                            .font(Theme.body(16))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        mark(for: i, of: question)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .chunky(face(for: i, of: question), radius: 16,
                        haptic: picked == nil ? .select : nil, sparks: false)
                .disabled(picked != nil)
                .accessibilityIdentifier("drill.option.\(i)")
            }
        }
    }

    /// Once answered, the right option lights up whatever was picked: a round
    /// that only says "no" teaches nothing, and the answer is the lesson.
    private func face(for i: Int, of question: DrillQuestion) -> Color {
        guard let picked else { return Theme.surface }
        if i == question.answer { return Theme.greenSoft }
        return i == picked ? Theme.sand : Theme.surface
    }

    @ViewBuilder
    private func mark(for i: Int, of question: DrillQuestion) -> some View {
        if let picked {
            if i == question.answer {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.green)
            } else if i == picked {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func verdict(for question: DrillQuestion) -> some View {
        HStack(spacing: 12) {
            Text(loc.t(picked == question.answer ? "drill.right" : "drill.wrong"))
                .font(Theme.title(17))
                .foregroundStyle(picked == question.answer ? Theme.green : Theme.inkSoft)
            Spacer(minLength: 0)
            Button(loc.t("drill.next")) { advance() }
                .font(Theme.label(13))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .chunky(Theme.goldSoft, radius: 14, haptic: .press)
                .accessibilityIdentifier("drill.next")
        }
    }

    private var summary: some View {
        VStack(spacing: 14) {
            Text(loc.t("drill.done.title"))
                .font(Theme.title(24))
                .foregroundStyle(Theme.ink)
            Text("\(right) / \(questions.count)")
                .font(Theme.pixel(32))
                .foregroundStyle(Theme.gold)
            Text(loc.t("drill.done.score", right, questions.count))
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button(loc.t("drill.done.again")) {
                seed &+= 0x9E37
                deal()
            }
            .font(Theme.label(13))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .chunky(Theme.goldSoft, radius: 14, haptic: .press)
            .accessibilityIdentifier("drill.again")
        }
        .frame(maxWidth: .infinity)
        .card()
        .accessibilityIdentifier("drill.summary")
    }

    /// Nothing has been read yet, so there is nothing to ask. Saying so beats
    /// inventing a quiz over steps the user has never opened.
    private var emptyState: some View {
        Text(loc.t("drill.empty"))
            .font(Theme.body(15))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityIdentifier("drill.empty")
    }

    // MARK: Flow

    /// The round is drawn from the steps that have been opened and declared —
    /// `learning` and `known`. A step nobody has read yet has nothing to be
    /// asked about, and *Learn* is where it starts.
    private var pool: Set<String> { settings.learned.union(settings.learningNow) }

    private func deal() {
        let ids = Array(pool)
        questions = Drill.session(steps: settings.steps, pool: pool,
                                  priority: DrillLog.priority(ids, scores: DrillLog.scores),
                                  seed: seed)
        index = 0
        picked = nil
        right = 0
    }

    private func answer(_ i: Int, of question: DrillQuestion) {
        guard picked == nil else { return }
        picked = i
        let correct = i == question.answer
        if correct { right += 1 }
        // Filed one question at a time, not at the end: a round left halfway
        // still said something about those steps, and dropping it would punish
        // stopping.
        DrillLog.record(step: question.stepID, correct: correct)
        // Being asked about a step is studying it: the round feeds the same
        // journal a reading does, so a day spent only drilling still counts.
        if let step = settings.step(question.stepID) { settings.noteStudied(step) }
    }

    private func advance() {
        picked = nil
        index += 1
        if index >= questions.count, right == questions.count { Haptic.win.play() }
    }
}

// MARK: - The question itself

private struct QuestionCard: View {
    let question: DrillQuestion
    let picked: Int?

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    private var step: PrayerStep? { settings.steps.first { $0.id == question.stepID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc.t(question.promptKey))
                .font(Theme.label(11))
                .foregroundStyle(Theme.gold)
                .textCase(.uppercase)

            // The posture question shows the drawing and nothing else: naming
            // the step would be handing over the answer.
            if question.kind == .posture, let step {
                PositionMedallion(step: step, size: 132)
                    .frame(maxWidth: .infinity)
            }

            if let arabic = question.arabic, !arabic.isEmpty {
                Text(arabic)
                    .font(Theme.arabic(26))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }

            if !question.subject.isEmpty {
                Text(question.subject)
                    .font(Theme.title(19))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityIdentifier("drill.question")
    }
}
