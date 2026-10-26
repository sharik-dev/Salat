import SwiftUI

/// A round of exercises, run like a lesson: one exercise fills the screen, the
/// bar on top shows where the round stands, and the only way forward is the
/// wide button pinned at the bottom — check first, then continue. The floating
/// tab bar steps aside for the duration (`TabBarHiddenKey`): mid-round there
/// is nowhere else to go, and the action bar needs the bottom of the screen.
///
/// Nothing here is new content — every exercise is built from the steps
/// already read, and every answer files itself into that step's memory card,
/// which is what decides when it comes back.
struct DrillSessionView: View {
    /// What the reader ordered on the picker: the dealt mix by default, one
    /// exercise kind and/or one step when chosen. The session itself does not
    /// care — it plays whatever list `Drill.run` hands it.
    var run = DrillRun()

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    @State private var exercises: [DrillExercise] = []
    @State private var index = 0
    @State private var right = 0
    @State private var seed = UInt64(Date().timeIntervalSince1970)

    /// Where the current exercise stands. `.checked` locks it: an answer that
    /// could still be changed after the verdict would make the verdict a hint.
    private enum Phase: Equatable { case working, checked(Bool) }
    @State private var phase: Phase = .working

    /// Which option the finger chose, before checking (multiple choice).
    @State private var selection: Int?
    /// The word-bank picks, in tap order (word order).
    @State private var placed: [Int] = []

    var body: some View {
        content
            // A chosen run is titled by the question it asks; the mix keeps
            // the tool's name.
            .navigationTitle(loc.t(run.focus == .mixed ? "revise.tool.drill.title"
                                                       : run.focus.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .paperToolbar()
            .preference(key: TabBarHiddenKey.self, value: !exercises.isEmpty)
            .task { deal() }
    }

    @ViewBuilder
    private var content: some View {
        if exercises.isEmpty {
            ScrollView { emptyState.padding(18) }
                .scrollIndicators(.hidden)
        } else if index >= exercises.count {
            summary
        } else {
            lesson(exercises[index])
        }
    }

    // MARK: The lesson frame

    private func lesson(_ exercise: DrillExercise) -> some View {
        VStack(spacing: 0) {
            progressHeader
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc.t(exercise.promptKey))
                        .font(Theme.title(21))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    board(exercise)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .animation(Theme.spring, value: phase)
            }
            .scrollIndicators(.hidden)

            actionBar(exercise)
        }
        .animation(Theme.spring, value: index)
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            // The bar fills as soon as the answer is checked, not on continue:
            // the fill is the reward, and it should land with the verdict.
            ProgressBar(value: Double(index) + (phase == .working ? 0 : 1),
                        total: Double(exercises.count))
                .frame(height: 14)
                .animation(Theme.spring, value: phase)
                .animation(Theme.spring, value: index)
            Text("\(min(index + 1, exercises.count))/\(exercises.count)")
                .font(Theme.pixel(11))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    private func board(_ exercise: DrillExercise) -> some View {
        switch exercise {
        case .choice(let question):
            QuestionCard(question: question, fill: blankFill(question))
            options(for: question)
        case .pairs(let pairs):
            PairsBoard(exercise: pairs, locked: phase != .working) { perfect in
                grade(perfect, step: pairs.stepID)
            }
            .id(pairs.id)
        case .order(let order):
            OrderBoard(exercise: order, locked: phase != .working, placed: $placed)
                .id(order.id)
        }
    }

    // MARK: Multiple choice

    @ViewBuilder
    private func options(for question: DrillQuestion) -> some View {
        VStack(spacing: 8) {
            ForEach(question.options.indices, id: \.self) { i in
                Button {
                    guard phase == .working else { return }
                    selection = selection == i ? nil : i
                } label: {
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
                        haptic: phase == .working ? .select : nil, sparks: false)
                .disabled(phase != .working)
                .accessibilityIdentifier("drill.option.\(i)")
            }
        }
        .animation(Theme.spring, value: selection)
    }

    /// Once checked, the right option lights up whatever was picked: a round
    /// that only says "no" teaches nothing, and the answer is the lesson.
    private func face(for i: Int, of question: DrillQuestion) -> Color {
        switch phase {
        case .working:
            return selection == i ? Theme.goldSoft : Theme.surface
        case .checked:
            if i == question.answer { return Theme.greenSoft }
            return i == selection ? Theme.sand : Theme.surface
        }
    }

    @ViewBuilder
    private func mark(for i: Int, of question: DrillQuestion) -> some View {
        if case .checked = phase {
            if i == question.answer {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.green)
            } else if i == selection {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// What stands in the gap of a fill-in question right now: the picked
    /// option while it is open, the right word once checked, nil for the
    /// empty slot.
    private func blankFill(_ question: DrillQuestion) -> String? {
        guard question.kind == .blank else { return nil }
        if case .checked = phase { return question.correctOption }
        if let selection { return question.options[selection] }
        return nil
    }

    // MARK: The action bar

    /// The bottom of the screen belongs to one wide button — check, then
    /// continue — with the verdict above it once the answer is in. This is
    /// the fixed ground of the lesson; everything above it scrolls.
    private func actionBar(_ exercise: DrillExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch phase {
            case .working:
                wideButton(loc.t("drill.check"), enabled: canCheck(exercise)) {
                    check(exercise)
                }
                .accessibilityIdentifier("drill.check")
            case .checked(let won):
                verdict(exercise, won: won)
                wideButton(loc.t("drill.next"), enabled: true) { advance() }
                    .accessibilityIdentifier("drill.next")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.bar,
                                   topTrailingRadius: Theme.Radius.bar,
                                   style: .continuous)
                .fill(barColor)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.bar,
                                           topTrailingRadius: Theme.Radius.bar,
                                           style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: Theme.stroke)
                )
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(Theme.spring, value: phase)
    }

    private var barColor: Color {
        switch phase {
        case .working:            return Theme.surface
        case .checked(true):      return Theme.greenSoft
        case .checked(false):     return Theme.sand
        }
    }

    private func wideButton(_ title: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.label(16))
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .chunky(enabled ? Theme.goldSoft : Theme.sand, radius: 16,
                haptic: .press, sparks: false)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }

    private func verdict(_ exercise: DrillExercise, won: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(won ? Theme.green : Theme.inkSoft)
            VStack(alignment: .leading, spacing: 3) {
                Text(loc.t(won ? "drill.right" : "drill.wrong"))
                    .font(Theme.title(18))
                    .foregroundStyle(won ? Theme.green : Theme.ink)
                if !won, let answer = correction(exercise) {
                    Text("\(loc.t("drill.answer")) : \(answer)")
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("drill.verdict")
    }

    /// What should have been answered, spelled out under a miss. The pairs
    /// board has no single answer to print — its board already shows every
    /// match settled in green.
    private func correction(_ exercise: DrillExercise) -> String? {
        switch exercise {
        case .choice(let question): return question.correctOption
        case .order(let order):     return order.answer.joined(separator: " ")
        case .pairs:                return nil
        }
    }

    // MARK: Flow

    /// The round is drawn from the steps that have been opened and declared —
    /// `learning` and `known`. A step nobody has read yet has nothing to be
    /// asked about, and *Learn* is where it starts.
    private var pool: Set<String> { settings.learned.union(settings.learningNow) }

    private func deal() {
        let ids = Array(pool)
        exercises = Drill.run(run, steps: settings.steps, pool: pool,
                              priority: DrillLog.priority(ids, scores: DrillLog.scores),
                              seed: seed)
        index = 0
        right = 0
        resetExercise()
        #if DEBUG
        // `-drillBoard pairs|order` — land on the board under review; the
        // boards live mid-round and nobody is here to answer their way there.
        switch LaunchOptions.drillBoard {
        case "pairs": index = exercises.firstIndex { if case .pairs = $0 { true } else { false } } ?? 0
        case "order": index = exercises.firstIndex { if case .order = $0 { true } else { false } } ?? 0
        default: break
        }
        // `-drillVerdict right|wrong` — the bar between check and continue.
        if let verdict = LaunchOptions.drillVerdict,
           case .choice(let q) = exercises[index] {
            selection = verdict == "right" ? q.answer : (q.answer + 1) % q.options.count
            grade(selection == q.answer, step: q.stepID)
        }
        #endif
    }

    private func resetExercise() {
        phase = .working
        selection = nil
        placed = []
    }

    private func canCheck(_ exercise: DrillExercise) -> Bool {
        switch exercise {
        case .choice:           return selection != nil
        case .order(let order): return placed.count == order.bank.count
        case .pairs:            return false // the board checks itself, match by match
        }
    }

    private func check(_ exercise: DrillExercise) {
        switch exercise {
        case .choice(let question):
            guard let selection else { return }
            grade(selection == question.answer, step: question.stepID)
        case .order(let order):
            grade(placed.map { order.bank[$0] } == order.answer, step: order.stepID)
        case .pairs:
            break
        }
    }

    private func grade(_ won: Bool, step: String) {
        guard phase == .working else { return }
        phase = .checked(won)
        if won { right += 1 }
        (won ? Haptic.select : Haptic.tap).play()
        // Filed one exercise at a time, not at the end: a round left halfway
        // still said something about those steps, and dropping it would punish
        // stopping.
        DrillLog.record(step: step, correct: won)
        // Being asked about a step is studying it: the round feeds the same
        // journal a reading does, so a day spent only drilling still counts.
        if let step = settings.step(step) { settings.noteStudied(step) }
    }

    private func advance() {
        index += 1
        resetExercise()
        if index >= exercises.count, right == exercises.count { Haptic.win.play() }
        // The round is over: a pause, and the only one in a drill.
        if index >= exercises.count { Ads.shared.breakPoint() }
    }

    // MARK: Ends of the road

    private var summary: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                Text(loc.t("drill.done.title"))
                    .font(Theme.title(24))
                    .foregroundStyle(Theme.ink)
                Text("\(right) / \(exercises.count)")
                    .font(Theme.pixel(32))
                    .foregroundStyle(Theme.gold)
                Text(loc.t("drill.done.score", right, exercises.count))
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .card()
            .accessibilityIdentifier("drill.summary")
            Spacer()
            wideButton(loc.t("drill.done.again"), enabled: true) {
                seed &+= 0x9E37
                deal()
            }
            .accessibilityIdentifier("drill.again")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
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
}

// MARK: - The question itself

private struct QuestionCard: View {
    let question: DrillQuestion
    /// What stands in the blank of a fill-in question, if anything.
    var fill: String?

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    private var step: PrayerStep? { settings.steps.first { $0.id == question.stepID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                subject
                    .font(Theme.title(19))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityIdentifier("drill.question")
    }

    /// The fill-in question draws its gap as a gold underlined slot — a run
    /// of bullets reads as censorship, not as "your word goes here" — and the
    /// picked option drops into it, so the sentence can be read back whole
    /// before checking.
    private var subject: Text {
        guard question.kind == .blank,
              let gap = question.subject.range(of: "•+", options: .regularExpression)
        else { return Text(question.subject) }

        let slot: Text = if let fill, !fill.isEmpty {
            Text(fill).fontWeight(.semibold).foregroundStyle(Theme.gold)
        } else {
            Text(String(repeating: "\u{00A0}", count: 10))
        }
        return Text(question.subject[..<gap.lowerBound])
            + slot.underline(true, color: Theme.gold)
            + Text(question.subject[gap.upperBound...])
    }
}
