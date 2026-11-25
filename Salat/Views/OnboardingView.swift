import SwiftUI

/// First-launch welcome (rewritten 22/11/2026, sharpened for conversion on
/// 25/11/2026 — Sharik: « parle du gain : plus de scroll, mais scroll le
/// Coran »). Big animated scenes that loop like a video on a green sky, a
/// title and one sentence under them, telling one story, in order:
///
/// 1. **The hook.** A feed scrolls by and, with the same swipe, becomes the
///    Qur'an feed: the habit is not fought, it is redirected.
/// 2. **Two questions** (what do you want most? how many hours a day on your
///    phone?) and what the second adds up to over a year. The number is the
///    reader's own answer multiplied out, never a statistic: the app invents
///    nothing (5.6), and both answers stay on the phone.
/// 3. **The proof.** The reader swipes a few real verses themselves (the
///    Qur'an tab in small), then the prayer line read three ways, then the
///    widget where the scroll used to start.
/// 4. **The plan.** It assembles under the reader's eyes, then sums up their
///    own answers: the goal, ten minutes a day.
/// 5. **The commitment.** One daily moment, with a reminder.
///
/// Then the welcome ends and, without Premium, the paywall takes the screen
/// (`ContentView`): it is the last page of the story, not a surprise.
///
/// No promise beyond what the app does: no reward, no health claim, nothing
/// that takes sides between schools.
struct OnboardingView: View {
    @Environment(OnboardingManager.self) private var onboarding
    @State private var committing = LaunchOptions.welcomeQuestion != nil
    /// True once back from the last screen: the pitch reopens on its last page.
    @State private var cameBack = false
    @State private var hours: Int? = OnboardingManager.phoneHours
    @State private var goal: WelcomeGoal? = OnboardingManager.goal

    var body: some View {
        ZStack {
            if committing {
                WelcomeCommitView(back: {
                    cameBack = true
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) { committing = false }
                }, done: finish)
                .transition(.push(from: .trailing))
            } else {
                WelcomePitchView(startAtEnd: cameBack, hours: $hours, goal: $goal, next: {
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) { committing = true }
                }, skip: finish)
                .transition(.push(from: .leading))
            }
        }
        .background(Theme.surface.ignoresSafeArea())
        .onChange(of: hours) { _, value in OnboardingManager.phoneHours = value }
        .onChange(of: goal) { _, value in
            OnboardingManager.goal = value
            if let value { Telemetry.shared.track("onboarding_goal", props: ["goal": value.rawValue]) }
        }
    }

    /// Finishing must always get you out of the welcome — by the last button,
    /// by *Skip*, or by *Not now*.
    private func finish() { onboarding.markSeen() }
}

// MARK: - Pitch

enum WelcomePage: Int, CaseIterable, Identifiable {
    case scroll, goal, hours, reckoning, feed, words, widget, plan
    var id: Int { rawValue }

    var name: String {
        switch self {
        case .scroll:    return "scroll"
        case .goal:      return "goal"
        case .hours:     return "hours"
        case .reckoning: return "reckoning"
        case .feed:      return "feed"
        case .words:     return "words"
        case .widget:    return "widget"
        case .plan:      return "plan"
        }
    }

    var titleKey: String { "welcome.\(name).title" }
    var bodyKey: String { "welcome.\(name).body" }
}

/// The pitch pages: a tall green sky that carries the animated scene; under it
/// a centred title and sentence, the dots, the button.
struct WelcomePitchView: View {
    var startAtEnd: Bool
    @Binding var hours: Int?
    @Binding var goal: WelcomeGoal?
    var next: () -> Void
    var skip: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @State private var index = 0
    @State private var forward = true
    @State private var showLanguages = false
    /// The plan page holds its button until the plan has finished building.
    @State private var planReady = false
    private let pages = WelcomePage.allCases
    private var page: WelcomePage { pages[index] }
    private var isLast: Bool { index == pages.count - 1 }
    /// The questions want an answer before going on: the pages after them are
    /// built on it. The plan waits for its own build.
    private var canAdvance: Bool {
        switch page {
        case .goal:  return goal != nil
        case .hours: return hours != nil
        case .plan:  return planReady
        default:     return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Group {
                    switch page {
                    case .hours: HoursPicker(hours: $hours)
                    case .goal:  GoalPicker(goal: $goal)
                    case .feed:  FeedDemo()
                    case .plan:  PlanBuild(goal: goal, ready: $planReady)
                    default:     WelcomeMotion(page: page, hours: hours)
                    }
                }
                .id(index)
                .transition(slide)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 52)
            .padding(.bottom, 20)
            .background {
                WelcomeSky()
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36,
                                                      style: .continuous))
                    .ignoresSafeArea(edges: .top)
            }
            .overlay(alignment: .top) {
                HStack {
                    languageCapsule
                    Spacer()
                    skipCapsule
                }
                .padding(.horizontal, 20)
            }

            // Every caption laid out, hidden, so the height does not change
            // from one page to the next (the scene above must not jump).
            ZStack {
                ForEach(pages) { WelcomeCaption(page: $0, hours: hours, goal: goal).hidden() }
                WelcomeCaption(page: page, hours: hours, goal: goal)
                    .id(index)
                    .transition(slide)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 18)

            HStack(spacing: 7) {
                ForEach(pages) { p in
                    Capsule()
                        .fill(p.rawValue == index ? Theme.primary : Theme.sand)
                        .frame(width: p.rawValue == index ? 26 : 10, height: 10)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.35), value: index)
            .padding(.bottom, 16)
            .accessibilityHidden(true)

            Button { isLast ? next() : move(1) } label: {
                Text(loc.t(isLast ? "onboarding.start" : "common.continue"))
            }
            .buttonStyle(.cta(.primary, height: 60))
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.5)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityIdentifier("onboarding.primary")
        }
        .background(Theme.surface.ignoresSafeArea())
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                let t = value.translation
                guard abs(t.width) > 60, abs(t.width) > abs(t.height) * 1.4 else { return }
                // A swipe follows the reading direction: in Arabic, "next" is
                // a swipe to the right.
                let advance = (t.width < 0) != (loc.layoutDirection == .rightToLeft)
                if advance, !canAdvance { return }
                if advance, isLast { next() } else { move(advance ? 1 : -1) }
            }
        )
        .onAppear {
            if startAtEnd { index = pages.count - 1 }
            if let page = LaunchOptions.welcomePage, pages.indices.contains(page) {
                index = page
                // A page photographed past a question needs its answer.
                if page > WelcomePage.goal.rawValue, goal == nil { goal = .quran }
                if page > WelcomePage.hours.rawValue, hours == nil { hours = 4 }
            }
            trackPage()
        }
        .onChange(of: index) { trackPage() }
        .sheet(isPresented: $showLanguages) {
            LanguagePickerView()
                .localized(settings.localizer)
                .environment(settings)
        }
    }

    /// The pitch is written in the phone's language. When that guess is wrong,
    /// this is the way out — on the very first screen, not three pages later.
    private var languageCapsule: some View {
        Button { showLanguages = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe").font(.system(size: 13, weight: .black))
                Text(settings.resolvedLanguage.flagless)
                    .font(Theme.rounded(14, .black))
            }
            .capsuleFace()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.language")
    }

    private var skipCapsule: some View {
        Button(action: skip) {
            Text(loc.t("onboarding.skip"))
                .font(Theme.rounded(14, .black))
                .capsuleFace()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.skip")
    }

    private var slide: AnyTransition {
        .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    /// The funnel: which page each install reached. A page id, nothing else.
    private func trackPage() {
        Telemetry.shared.track("onboarding_step", value: Double(index), props: ["page": page.name])
    }

    private func move(_ delta: Int) {
        let target = index + delta
        guard pages.indices.contains(target) else { return }
        // The direction first, without animation, so the leaving page takes the
        // right exit.
        forward = delta > 0
        DispatchQueue.main.async {
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) { index = target }
        }
    }
}

private extension View {
    /// White capsule on a green edge; the touch target reaches down to 44 pt.
    func capsuleFace() -> some View {
        self.foregroundStyle(Theme.primaryDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white, in: Capsule())
            .background(Capsule().fill(Theme.primaryDeep).offset(y: 3))
            .frame(minWidth: 44, minHeight: 44, alignment: .top)
            .contentShape(Rectangle())
    }
}

/// The text of a page: a title and a sentence, nothing else. The reckoning
/// page's title carries the reader's own number.
private struct WelcomeCaption: View {
    let page: WelcomePage
    let hours: Int?
    let goal: WelcomeGoal?
    @Environment(\.loc) private var loc

    private var title: String {
        if page == .reckoning {
            guard let hours, hours > 0 else { return loc.t("welcome.reckoning.none.title") }
            return loc.t(page.titleKey, OnboardingManager.daysPerYear(hours: hours))
        }
        return loc.t(page.titleKey)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.8)
            Text(loc.t(page.bodyKey))
                .font(Theme.rounded(16, .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The question

/// "How many hours a day on your phone?" — eight answers, one tap. Not drawn
/// in the scaled scene canvas: these are real buttons, for VoiceOver and the
/// UI tests alike.
private struct HoursPicker: View {
    @Binding var hours: Int?
    @Environment(\.loc) private var loc

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 18) {
            LofiIcon(.phone, size: 110, interval: 1.4)
                .frame(maxHeight: .infinity)

            WelcomeCard(padding: 14) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1...8, id: \.self) { value in
                        chip(value)
                    }
                }
            }
            .frame(maxWidth: 380)
        }
    }

    private func chip(_ value: Int) -> some View {
        let selected = hours == value
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) { hours = value }
            Haptic.select.play()
        } label: {
            Text(loc.t(value == 8 ? "welcome.hours.max" : "welcome.hours.option", value))
                .font(Theme.rounded(18, .black).monospacedDigit())
                .foregroundStyle(selected ? .white : Theme.primaryDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(selected ? Theme.primary : Theme.primarySoft, in: shape)
                .overlay(shape.strokeBorder(selected ? Theme.primaryDeep : Theme.primaryBorder, lineWidth: 2.5))
                .scaleEffect(selected ? 1.06 : 1)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.hours.\(value)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - The goal

/// "What do you want most?": four answers, one tap. The answer comes back on
/// the plan and the paywall, so the reader hears their own words again.
private struct GoalPicker: View {
    @Binding var goal: WelcomeGoal?
    @Environment(\.loc) private var loc

    var body: some View {
        VStack(spacing: 10) {
            ForEach(WelcomeGoal.allCases) { option in row(option) }
        }
        .frame(maxWidth: 400)
        .frame(maxHeight: .infinity)
    }

    private func row(_ option: WelcomeGoal) -> some View {
        let selected = goal == option
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) { goal = option }
            Haptic.select.play()
        } label: {
            HStack(spacing: 12) {
                LofiIcon(option.icon, size: 52, interval: 1.4, animated: selected)
                Text(loc.t(option.key))
                    .font(Theme.rounded(18, .black))
                    .foregroundStyle(selected ? .white : Theme.ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(selected ? .white : Theme.border)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(selected ? Theme.primary : .white, in: shape)
            .background(shape.fill(Theme.primaryDeep).offset(y: 5))
            .scaleEffect(selected ? 1.03 : 1)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.goal.\(option.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - The proof: the reader swipes it

/// The Qur'an tab in small, and the reader's own thumb on it: a phone frame
/// with a real paged feed of al-Fatiha, swipe up for the next verse, double
/// tap for a heart. Trying the gesture is worth more than any sentence about
/// it, and it is the very gesture the welcome promised to redirect.
private struct FeedDemo: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @State private var position: Int? = 0
    @State private var liked: Set<Int> = []
    @State private var hintUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lines: [(String, String)] { Array(settings.feedSampleLines.prefix(5)) }
    private var swiped: Bool { (position ?? 0) > 0 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        GeometryReader { geo in
            let height = min(geo.size.height, geo.size.width * 1.55)
            let width = height / 1.55
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                        QuranFeedCard(arabic: line.0, translation: line.1, picture: i * 3 + 1,
                                      liked: liked.contains(i), scale: width / 330)
                            .frame(width: width, height: height)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(duration: 0.3, bounce: 0.5)) { _ = liked.insert(i) }
                                Haptic.select.play()
                            }
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .frame(width: width, height: height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 7))
            .background(shape.fill(Theme.primaryDeep).offset(y: 8))
            .overlay(alignment: .bottom) {
                if !swiped {
                    Label(loc.t("welcome.feed.hint"), systemImage: "chevron.up")
                        .font(Theme.rounded(15, .black))
                        .foregroundStyle(Theme.primaryDeep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white, in: Capsule())
                        .offset(y: hintUp ? -26 : -14)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeInOut(duration: 0.25), value: swiped)
        .onChange(of: position) { _, value in
            if let value, value > 0 { Haptic.select.play() }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { hintUp = true }
        }
        .accessibilityIdentifier("onboarding.feed")
    }
}

// MARK: - The plan

/// The plan builds itself under the reader's eyes: four lines tick one after
/// the other, then the summary of their own answers. Nothing here is
/// computed for show: each line is a thing the app has just set up (the
/// language, the feed, the prayer, the widget), and the summary only repeats
/// the reader's goal. The button waits for the last tick.
private struct PlanBuild: View {
    let goal: WelcomeGoal?
    @Binding var ready: Bool
    @Environment(\.loc) private var loc
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var done = 0

    private let items: [(Icon3D, String)] = [
        (.globe, "welcome.plan.item.language"),
        (.quran, "welcome.plan.item.feed"),
        (.mat, "welcome.plan.item.prayer"),
        (.phone, "welcome.plan.item.widget"),
    ]

    var body: some View {
        VStack(spacing: 14) {
            WelcomeCard(padding: 14) {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        ProgressBar(value: Double(done), total: Double(items.count))
                            .frame(height: 14)
                        Text(verbatim: "\(done * 100 / items.count) %")
                            .font(Theme.rounded(15, .black).monospacedDigit())
                            .foregroundStyle(Theme.primaryDeep)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        HStack(spacing: 12) {
                            LofiIcon(item.0, size: 40, interval: 1.6, animated: done == i)
                                .saturation(done > i ? 1 : 0.3)
                            Text(loc.t(item.1))
                                .font(Theme.rounded(15.5, .heavy))
                                .foregroundStyle(done > i ? Theme.ink : Theme.inkSoft)
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 0)
                            ZStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.primary)
                                    .scaleEffect(done > i ? 1 : 0.1)
                                    .opacity(done > i ? 1 : 0)
                                if done == i { ProgressView().tint(Theme.gold) }
                            }
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 28)
                        }
                        .frame(minHeight: 46)
                    }
                }
            }

            if ready {
                WelcomeCard(padding: 14) {
                    HStack(spacing: 12) {
                        LofiIcon((goal ?? .quran).icon, size: 56, interval: 1.4)
                        VStack(alignment: .leading, spacing: 3) {
                            if let goal {
                                Text(loc.t("welcome.plan.goal", loc.t(goal.key)))
                                    .font(Theme.rounded(16, .black))
                                    .foregroundStyle(Theme.ink)
                            }
                            Text(loc.t("welcome.plan.daily"))
                                .font(Theme.rounded(15, .heavy))
                                .foregroundStyle(Theme.primaryDeep)
                        }
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .accessibilityIdentifier("onboarding.plan.ready")
            }
        }
        .frame(maxWidth: 420)
        .frame(maxHeight: .infinity)
        .task { await build() }
    }

    private func build() async {
        if ready || reduceMotion || LaunchOptions.welcomeBeat != nil {
            done = items.count
            ready = true
            return
        }
        try? await Task.sleep(for: .seconds(0.5))
        for i in 1...items.count {
            try? await Task.sleep(for: .seconds(0.65))
            if Task.isCancelled { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { done = i }
            Haptic.select.play()
        }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { ready = true }
        Haptic.press.play()
    }
}

// MARK: - Sky

/// The banner's green, tall: the house lattice, a crescent, gold sparks.
private struct WelcomeSky: View {
    var body: some View {
        ZStack {
            Theme.primary
            StarLattice(spacing: 66, opacity: 0.14, color: .white)
            GeometryReader { geo in
                Circle().fill(.white.opacity(0.07))
                    .frame(width: 320, height: 320)
                    .position(x: geo.size.width * 0.05, y: geo.size.height * 0.95)
                Circle().fill(.white.opacity(0.06))
                    .frame(width: 240, height: 240)
                    .position(x: geo.size.width * 0.98, y: geo.size.height * 0.2)
            }
            Twinkles(spots: [(0.14, 0.2, 18, 1.7, 0.0), (0.9, 0.36, 14, 2.3, 1.4), (0.08, 0.62, 12, 1.9, 2.6),
                             (0.93, 0.86, 16, 2.6, 3.9), (0.5, 0.12, 10, 2.1, 5.0)])
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Animated scenes

/// Working size of every scene: they are drawn at this size, then scaled to the
/// room available (small iPhone and Pro Max alike).
private let motionCanvas = CGSize(width: 340, height: 430)

/// The scene of a page, looping like a video.
private struct WelcomeMotion: View {
    let page: WelcomePage
    let hours: Int?

    var body: some View {
        MotionCanvas {
            switch page {
            case .scroll:    MotionLoop(durations: ScrollMotion.durations) { ScrollMotion(beat: $0) }
            case .goal, .hours, .feed, .plan: EmptyView()
            case .reckoning: MotionLoop(durations: ReckoningMotion.durations) { ReckoningMotion(beat: $0, hours: hours) }
            case .words:     MotionLoop(durations: WordsMotion.durations) { WordsMotion(beat: $0) }
            case .widget:    MotionLoop(durations: WidgetMotion.durations) { WidgetMotion(beat: $0) }
            }
        }
        // The scenes show the app's own left-to-right mock-ups; mirroring them
        // in Arabic would flip the finger away from what it taps.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

/// Sets the scene (340 × 430) in the middle of its room, grown up to 125 %.
private struct MotionCanvas<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / motionCanvas.width, geo.size.height / motionCanvas.height, 1.25)
            content()
                .frame(width: motionCanvas.width, height: motionCanvas.height)
                .scaleEffect(scale)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// A scene's metronome: steps from one beat to the next (`durations[i]` seconds
/// each), fades out, snaps back to beat 0 without animation and starts again.
/// Reduce Motion: the scene rests on its last beat.
/// Debug: `-welcomeBeat N` freezes the scene on beat N (99 = the last).
private struct MotionLoop<Content: View>: View {
    let durations: [Double]
    @ViewBuilder var content: (Int) -> Content

    @State private var beat = 0
    @State private var visible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content(beat)
            .opacity(visible ? 1 : 0)
            .task { await run() }
    }

    private func run() async {
        let last = durations.count - 1
        if let frozen = LaunchOptions.welcomeBeat {
            beat = min(max(frozen, 0), last)
            return
        }
        if reduceMotion { beat = last; return }
        while !Task.isCancelled {
            for i in 0...last {
                if i > 0 { withAnimation(.spring(duration: 0.55, bounce: 0.3)) { beat = i } }
                try? await Task.sleep(for: .seconds(durations[i]))
                if Task.isCancelled { return }
            }
            withAnimation(.easeInOut(duration: 0.3)) { visible = false }
            try? await Task.sleep(for: .seconds(0.35))
            if Task.isCancelled { return }
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { beat = 0 }
            withAnimation(.easeInOut(duration: 0.35)) { visible = true }
        }
    }
}

/// The white card the scenes are built on: a slab on a deep-green edge.
private struct WelcomeCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        content()
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(shape.fill(.white))
            .background(shape.fill(Theme.primaryDeep).offset(y: 6))
    }
}

private extension PrayerStep {
    /// What the reader actually reads: the phonetic, or the Arabic itself in
    /// the one language whose phonetic field is empty by construction.
    var welcomeLines: [String] {
        let lines = phoneticLines.filter { !$0.isEmpty }
        return lines.isEmpty ? arabicLines : lines
    }
}

// MARK: Hook — the feed that becomes a verse

/// A phone, and in it a feed of grey posts sliding up, one swipe after the
/// other, while a thumb keeps flicking. Then, with the same swipe, the feed
/// becomes the Qur'an feed: a photograph, a verse, its meaning, a heart. The
/// habit is not taken away, it is pointed somewhere else. No logo, no real
/// app: the grey feed is drawn as blank shapes on purpose.
private struct ScrollMotion: View {
    let beat: Int
    @Environment(AppSettings.self) private var settings

    /// 0–3 the feed scrolls · 4 it fades, the verse arrives · 5 held.
    static let durations: [Double] = [0.75, 0.75, 0.75, 0.9, 1.0, 2.4]

    private var swapped: Bool { beat >= 4 }

    /// The second line of al-Fatiha as the app itself spells it (the first,
    /// the Basmala, is too familiar to surprise anyone).
    private var verse: (String, String) {
        let lines = settings.feedSampleLines
        return lines.count > 1 ? lines[1] : lines[0]
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 42, style: .continuous)
        ZStack(alignment: .top) {
            Theme.paper
            feed
                .offset(y: -CGFloat(min(beat, 3)) * 118)
                .opacity(swapped ? 0 : 1)
                .blur(radius: swapped ? 6 : 0)
            if swapped {
                QuranFeedCard(arabic: verse.0, translation: verse.1, picture: 3,
                              liked: beat >= 5, scale: 0.82)
                    // Its own size, pinned to the top: the feed under it is
                    // taller than the phone, and the card would centre on it.
                    .frame(width: 260, height: 380)
                    .transition(.move(edge: .bottom))
            }
        }
        .frame(width: 260, height: 380, alignment: .top)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 7))
        .background(shape.fill(Theme.primaryDeep).offset(y: 8))
        .overlay(alignment: .bottomTrailing) {
            // The thumb: flicks while the feed runs, a quiet book once it stops.
            ZStack {
                LofiIcon(.phone, size: 74, interval: 0.5)
                    .opacity(swapped ? 0 : 1)
                    .offset(y: swapped ? 0 : (beat.isMultiple(of: 2) ? 0 : -16))
                LofiIcon(.quran, size: 86, interval: 1.6)
                    .scaleEffect(swapped ? 1 : 0.1)
                    .opacity(swapped ? 1 : 0)
            }
            .offset(x: 30, y: 24)
        }
        .frame(maxHeight: .infinity)
    }

    /// Eight blank posts: an avatar, two lines, a picture.
    private var feed: some View {
        VStack(spacing: 14) {
            ForEach(0..<8, id: \.self) { i in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.border).frame(width: 26, height: 26)
                        Capsule().fill(Theme.border).frame(width: 90, height: 9)
                    }
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(i.isMultiple(of: 2) ? Theme.sand : Theme.line)
                        .frame(height: 64)
                }
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 26)
    }

}

// MARK: The reckoning — the reader's own number

/// The answer to the question, multiplied out: hours a day become days a year,
/// counted up on a calendar. Then, under it, what ten minutes of that would be.
/// Both numbers are plain arithmetic on the reader's answer.
private struct ReckoningMotion: View {
    let beat: Int
    let hours: Int?
    @Environment(\.loc) private var loc

    /// 0 the calendar · 1–3 the count climbs · 4 the swap · 5 held.
    static let durations: [Double] = [0.7, 0.55, 0.55, 0.8, 1.0, 2.6]

    private var days: Int { OnboardingManager.daysPerYear(hours: hours ?? 0) }
    /// A third, two thirds, then all of it: the number climbs.
    private var shown: Int {
        switch beat {
        case 0: return 0
        case 1: return days / 3
        case 2: return days * 2 / 3
        default: return days
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            WelcomeCard(padding: 18) {
                VStack(spacing: 6) {
                    LofiIcon(.calendar, size: 84, interval: 1.4)
                    if hours != nil {
                        Text(verbatim: "\(shown)")
                            .font(Theme.title(64).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text(loc.t("welcome.reckoning.unit"))
                            .font(Theme.rounded(17, .heavy))
                            .foregroundStyle(Theme.inkSoft)
                    } else {
                        LofiIcon(.phone, size: 84, interval: 1.0)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            WelcomeCard(padding: 14) {
                HStack(spacing: 12) {
                    LofiIcon(.quran, size: 58, interval: 1.6)
                    Text(loc.t("welcome.reckoning.swap"))
                        .font(Theme.rounded(17, .black))
                        .foregroundStyle(Theme.primaryDeep)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            .scaleEffect(beat >= 4 ? 1 : 0.8)
            .opacity(beat >= 4 ? 1 : 0)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: Page 1 — one line, three ways

/// A real line of the prayer builds up in front of you: the Arabic, then how to
/// say it, then what it means — and then a voice goes through it word by word.
private struct WordsMotion: View {
    let beat: Int
    @Environment(AppSettings.self) private var settings

    /// 0 arabic · 1 + how to say it · 2 + meaning · 3–5 the voice, word by word · 6 held.
    static let durations: [Double] = [0.9, 0.9, 1.0, 0.55, 0.55, 0.7, 2.2]

    private var step: PrayerStep? { settings.step("ruku") ?? settings.steps.first(where: \.spoken) }
    private var listening: Bool { beat >= 3 }
    private var cursor: Int? { (3...5).contains(beat) ? beat - 3 : nil }

    var body: some View {
        if let step {
            let arabic = step.arabicLines[0]
            let words = arabic.split(separator: " ").count
            VStack(spacing: 18) {
                PositionMedallion(step: step, size: 150)
                    .background(Circle().fill(.white).padding(-7))
                    .overlay(alignment: .bottomTrailing) {
                        LofiIcon(.headphones, size: 64, interval: 1.2)
                            .scaleEffect(listening ? 1 : 0.2)
                            .opacity(listening ? 1 : 0)
                            .offset(x: 22, y: 14)
                    }

                WelcomeCard(padding: 18) {
                    VStack(spacing: 10) {
                        Karaoke.line(arabic, active: cursor.map { min($0, words - 1) },
                                     base: Theme.ink, tint: Theme.gold)
                            .font(Theme.arabic(30))
                            .multilineTextAlignment(.center)
                            .environment(\.layoutDirection, .rightToLeft)
                            .frame(maxWidth: .infinity)

                        if beat >= 1, !step.phoneticLines[0].isEmpty {
                            let phonetic = step.phoneticLines[0]
                            let count = phonetic.split(separator: " ").count
                            Karaoke.line(phonetic,
                                         active: cursor.map { Karaoke.projected(min($0, words - 1), from: words, onto: count) },
                                         base: Theme.ink, tint: Theme.gold)
                                .font(Theme.rounded(19, .black))
                                .multilineTextAlignment(.center)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if beat >= 2 {
                            Text(step.translationLines[0])
                                .font(Theme.rounded(15, .semibold))
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.center)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                }
                .overlay(alignment: .topTrailing) {
                    LofiIcon(.check, size: 58, interval: 1.4)
                        .scaleEffect(beat >= 6 ? 1 : 0.1)
                        .opacity(beat >= 6 ? 1 : 0)
                        .offset(x: 14, y: -24)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: Page 3 — it comes to you

/// A home screen, and on it the widget turning from one step to the next while
/// the clock moves on: the prayer learnt without opening anything.
///
/// The widget shown is the real one (`HomeScreenMock`), and a minute per step
/// is its real pace: the scene promises nothing the home screen will not do.
private struct WidgetMotion: View {
    let beat: Int
    @Environment(AppSettings.self) private var settings

    static let durations: [Double] = [1.7, 1.7, 1.7, 2.3]
    /// Four short steps whose postures differ at a glance: the eye should see
    /// the figure change even before it reads a word.
    private static let stepIDs = ["takbir", "ruku", "sujud", "tashahhud"]

    private var shown: Int { min(beat, Self.stepIDs.count - 1) }

    private var entry: CarouselEntry? {
        guard let step = settings.step(Self.stepIDs[shown]) else { return nil }
        return CarouselEntry(date: .now, step: step,
                             position: step.order, total: settings.steps.count,
                             localizer: settings.localizer, focus: .phonetic)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 42, style: .continuous)
        Group {
            if let entry {
                HomeScreenMock(entry: entry, rows: 2, clock: "9:4\(1 + shown)")
            } else {
                HomeWallpaper()
            }
        }
        .frame(width: 318, height: 376)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 7))
        .background(shape.fill(Theme.primaryDeep).offset(y: 8))
        .frame(maxHeight: .infinity)
    }
}

// MARK: - The commitment

/// The last screen of the welcome: one daily moment, given to the Qur'an
/// instead of the feed, and the reminder that holds it. In the same frame as
/// the rest of the app (banner, one button at the bottom).
struct WelcomeCommitView: View {
    var back: () -> Void
    var done: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(StudyReminders.self) private var reminders
    @Environment(\.loc) private var loc
    /// True once a button was pressed: a second tap (a double tap) does not
    /// count, and no second system alert comes up.
    @State private var leaving = false

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            Banner(title: loc.t("welcome.setup"), subtitle: nil, subtitleAction: nil, subtitleID: nil,
                   back: back) {
                LofiIcon(.bell, size: 96, interval: 3)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(loc.t("welcome.commit.title"))
                        .font(Theme.title(26))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)

                    Text(loc.t("welcome.commit.body"))
                        .font(Theme.rounded(16, .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(loc.t("settings.reminders.time"))
                            .font(Theme.rounded(16.5, .heavy))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        DatePicker("", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .card(padding: 14)

                    // What the reminder will actually say: a real one, about a
                    // real step.
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(icon: .bell, size: 46, animated: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.t("notif.title"))
                                .font(Theme.rounded(14, .black))
                                .foregroundStyle(Theme.ink)
                            Text(loc.t("notif.body.2", settings.steps.first?.name ?? ""))
                                .font(Theme.rounded(14.5, .semibold))
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .card(padding: 14)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                Button {
                    guard !leaving else { return }
                    Task { await turnRemindersOn() }
                } label: {
                    Text(loc.t("welcome.reminder.on"))
                }
                .buttonStyle(.cta(.primary, height: 60))
                .accessibilityIdentifier("onboarding.reminders")

                Button {
                    guard !leaving else { return }
                    leaving = true
                    done()
                } label: {
                    Text(loc.t("welcome.later"))
                }
                .buttonStyle(.cta(.secondary, height: 52, haptic: .tap))
                .accessibilityIdentifier("onboarding.later")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    /// The permission is asked here, on the button that says so — never at
    /// launch. A refusal simply leaves the reminder off; either way the
    /// welcome is over.
    private func turnRemindersOn() async {
        leaving = true
        let granted = await reminders.requestAuthorization()
        settings.remindersOn = granted
        await reminders.sync(with: settings)
        done()
    }
}
