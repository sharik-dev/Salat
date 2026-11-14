import SwiftUI

/// First-launch welcome, modelled on SelfTransfer's: three pitch pages — each
/// one a big animated scene that loops like a video, then a title and a single
/// sentence — followed by two questions, one per screen.
///
/// The old onboarding was six pages of text under a still picture. Nobody reads
/// a paragraph before having seen the app; what the three scenes do instead is
/// *show* the three things the app does: you read a line three ways, you go
/// through the prayer step by step, and the widget keeps teaching it from the
/// home screen without the app being opened. That last page is the widget's
/// on purpose (Sharik, 14/11/2026): learning passively is what sets the app
/// apart, and it used to be half a sentence at the end of a list.
struct OnboardingView: View {
    @Environment(OnboardingManager.self) private var onboarding
    @State private var asking = LaunchOptions.welcomeQuestion != nil
    /// True once back from the questions: the pitch reopens on its last page.
    @State private var cameBack = false

    var body: some View {
        ZStack {
            if asking {
                WelcomeQuestionsView(back: {
                    cameBack = true
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) { asking = false }
                }, done: finish)
                .transition(.push(from: .trailing))
            } else {
                WelcomePitchView(startAtEnd: cameBack, next: {
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) { asking = true }
                }, skip: finish)
                .transition(.push(from: .leading))
            }
        }
        .background(Theme.surface.ignoresSafeArea())
    }

    /// Finishing must always get you into the app — by the last button, by
    /// *Skip*, or by *Not now*.
    private func finish() { onboarding.markSeen() }
}

// MARK: - Pitch

enum WelcomePage: Int, CaseIterable, Identifiable {
    case words, steps, widget
    var id: Int { rawValue }

    var titleKey: String { "welcome.\(rawValue + 1).title" }
    var bodyKey: String { "welcome.\(rawValue + 1).body" }
}

/// The pitch pages: a tall green sky that carries the animated scene; under it
/// a centred title and sentence, the dots, the button.
struct WelcomePitchView: View {
    var startAtEnd: Bool
    var next: () -> Void
    var skip: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @State private var index = 0
    @State private var forward = true
    @State private var showLanguages = false
    private let pages = WelcomePage.allCases
    private var page: WelcomePage { pages[index] }
    private var isLast: Bool { index == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                WelcomeMotion(page: page)
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
                    if !isLast { skipCapsule.transition(.opacity) }
                }
                .padding(.horizontal, 20)
            }

            // Every caption laid out, hidden, so the height does not change
            // from one page to the next (the scene above must not jump).
            ZStack {
                ForEach(pages) { WelcomeCaption(page: $0).hidden() }
                WelcomeCaption(page: page)
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
                if advance, isLast { next() } else { move(advance ? 1 : -1) }
            }
        )
        .onAppear {
            if startAtEnd { index = pages.count - 1 }
            if let page = LaunchOptions.welcomePage, pages.indices.contains(page) { index = page }
        }
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

/// The text of a page: a title and a sentence, nothing else.
private struct WelcomeCaption: View {
    let page: WelcomePage
    @Environment(\.loc) private var loc

    var body: some View {
        VStack(spacing: 8) {
            Text(loc.t(page.titleKey))
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)
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

    var body: some View {
        MotionCanvas {
            switch page {
            case .words: MotionLoop(durations: WordsMotion.durations) { WordsMotion(beat: $0) }
            case .steps: MotionLoop(durations: StepsMotion.durations) { StepsMotion(beat: $0) }
            case .widget: MotionLoop(durations: WidgetMotion.durations) { WidgetMotion(beat: $0) }
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

// MARK: Page 2 — step by step

/// The prayer as a short list that fills in: each beat, one more posture is
/// acquired, the badge pops and the bar moves.
private struct StepsMotion: View {
    let beat: Int
    @Environment(AppSettings.self) private var settings

    /// 0 nothing yet · 1–4 one more step acquired · 5 held, with the trophy.
    static let durations: [Double] = [0.9, 0.85, 0.85, 0.85, 0.85, 2.2]

    private static let ids = ["takbir", "ruku", "sujud", "tashahhud"]
    private var steps: [PrayerStep] { Self.ids.compactMap { settings.step($0) } }

    var body: some View {
        WelcomeCard(padding: 14) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ProgressBar(value: Double(min(beat, 4)), total: 4)
                        .frame(height: 14)
                    Text(verbatim: "\(min(beat, 4))/4")
                        .font(Theme.rounded(15, .black).monospacedDigit())
                        .foregroundStyle(Theme.primaryDeep)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    row(step, done: beat > i, active: beat == i)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            LofiIcon(.trophy, size: 86, interval: 1.2)
                .scaleEffect(beat >= 5 ? 1 : 0.1)
                .opacity(beat >= 5 ? 1 : 0)
                .rotationEffect(.degrees(beat >= 5 ? 8 : -30))
                .offset(x: 18, y: -70)
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ step: PrayerStep, done: Bool, active: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return HStack(spacing: 12) {
            PositionMedallion(step: step, size: 58)
                .saturation(done || active ? 1 : 0.2)
                .opacity(done || active ? 1 : 0.6)
            Text(step.name)
                .font(Theme.rounded(16, .black))
                .foregroundStyle(done || active ? Theme.ink : Theme.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 4)
            ZStack {
                LofiIcon(.check, size: 38, interval: 1.6, animated: done)
                    .scaleEffect(done ? 1 : 0.1)
                    .opacity(done ? 1 : 0)
                LofiIcon(.sprout, size: 38, interval: 1.2)
                    .scaleEffect(active ? 1 : 0.1)
                    .opacity(active ? 1 : 0)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(height: 70)
        .background(done ? Theme.primarySoft : .white, in: shape)
        .overlay(shape.strokeBorder(done ? Theme.primary : (active ? Theme.gold : Theme.border), lineWidth: 2.5))
        .scaleEffect(active ? 1.03 : 1)
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

// MARK: - Questions

/// The second half of the welcome: two questions, one per screen, in the same
/// frame as the rest of the app (banner, bar, one button at the bottom).
struct WelcomeQuestionsView: View {
    var back: () -> Void
    var done: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(StudyReminders.self) private var reminders
    @Environment(\.loc) private var loc
    @State private var index = min(max(LaunchOptions.welcomeQuestion ?? 0, 0), 1)
    @State private var forward = true
    /// True while one question slides to the next: a second tap (a double tap
    /// on *Continue*) does not count.
    @State private var moving = false
    @State private var showLanguages = false
    private let count = 2
    private var isLast: Bool { index == count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            Banner(title: loc.t("welcome.setup"),
                   subtitle: "\(index + 1) / \(count)", subtitleAction: nil, subtitleID: nil,
                   back: goBack) {
                LofiIcon(index == 0 ? .globe : .bell, size: 96, interval: 3)
                    .id(index)
                    .transition(.scale.combined(with: .opacity))
            }

            ProgressBar(value: Double(index + 1), total: Double(count))
                .frame(height: 14)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if index == 0 { languageQuestion } else { reminderQuestion }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                if isLast {
                    Button {
                        // Second tap of a double tap on "Continue": no system alert.
                        guard !moving else { return }
                        Task { await turnRemindersOn() }
                    } label: {
                        Text(loc.t("welcome.reminder.on"))
                    }
                    .buttonStyle(.cta(.primary, height: 60))
                    .accessibilityIdentifier("onboarding.reminders")

                    Button { if !moving { done() } } label: {
                        Text(loc.t("welcome.later"))
                    }
                    .buttonStyle(.cta(.secondary, height: 52, haptic: .tap))
                    .accessibilityIdentifier("onboarding.later")
                } else {
                    Button { move(1) } label: {
                        Text(loc.t("common.continue"))
                    }
                    .buttonStyle(.cta(.primary, height: 60))
                    .accessibilityIdentifier("onboarding.primary")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(isPresented: $showLanguages) {
            LanguagePickerView()
                .localized(settings.localizer)
                .environment(settings)
        }
    }

    // MARK: The two questions

    @ViewBuilder
    private var languageQuestion: some View {
        title(loc.t("onboarding.language.title"))

        Button { showLanguages = true } label: {
            HStack(spacing: 14) {
                LanguageCode(language: settings.resolvedLanguage)
                    .environment(\.layoutDirection, .leftToRight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.resolvedLanguage.nativeName)
                        .font(Theme.rounded(21, .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if settings.languagePreference == .system {
                        Text(loc.t("settings.language.system"))
                            .font(Theme.rounded(13, .heavy))
                            .foregroundStyle(Theme.goldDeep)
                    }
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .chunky(Theme.surface, radius: 22, depth: 5, haptic: .select)
        .accessibilityIdentifier("onboarding.language.open")
    }

    @ViewBuilder
    private var reminderQuestion: some View {
        @Bindable var settings = settings

        title(loc.t("welcome.reminder.title"))

        Text(loc.t("welcome.reminder.body"))
            .font(Theme.rounded(16, .semibold))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

        // What the reminder will actually say: a real one, about a real step.
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
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Theme.title(26))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
    }

    // MARK: Moves

    /// The permission is asked here, on the button that says so — never at
    /// launch. A refusal simply leaves the reminder off; either way the
    /// welcome is over.
    private func turnRemindersOn() async {
        moving = true
        let granted = await reminders.requestAuthorization()
        settings.remindersOn = granted
        await reminders.sync(with: settings)
        done()
    }

    private func goBack() { index == 0 ? back() : move(-1) }

    private func move(_ delta: Int) {
        guard !moving, (0..<count).contains(index + delta) else { return }
        moving = true
        forward = delta > 0
        DispatchQueue.main.async {
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) { index += delta }
        }
        // The length of the transition (0.4 s) plus a small margin.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { moving = false }
    }
}
