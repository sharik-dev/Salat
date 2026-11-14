import SwiftUI

/// The *Learn* tab: a banner, the one step to open now, and the fourteen steps
/// as a single list.
///
/// It used to open on a title, a sentence, a bar, two counters and a button
/// before the first step showed. All of that now fits the banner (title + a
/// pill that *is* the progress button), and the page starts on what to do.
struct LearnView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StudyReminders.self) private var reminders
    @Environment(\.loc) private var loc
    @State private var selected: PrayerStep?
    @State private var showsAnalytics = false

    /// The head of `StudyPlanner.queue` — the same step the reminder names, so
    /// the notification and this card can never disagree.
    private var upNext: (step: PrayerStep, reason: StudyPlanner.Reason)? {
        guard let due = settings.dueQueue().first, let step = settings.step(due.stepID) else { return nil }
        return (step, due.reason)
    }

    var body: some View {
        VStack(spacing: 0) {
            Banner(title: loc.t("learn.title"),
                   subtitle: loc.t("learn.progress", settings.learned.count, settings.steps.count),
                   subtitleAction: { showsAnalytics = true },
                   subtitleID: "learn.analytics") {
                LofiIcon(.mosque, size: 104, interval: 4)
            }
            .accessibilityIdentifier("learn.header")

            ScrollView {
                VStack(spacing: 14) {
                    ProgressBar(value: Double(settings.learned.count),
                                secondary: Double(settings.learned.count + settings.learningNow.count),
                                total: Double(max(settings.steps.count, 1)))
                        .frame(height: 14)
                        .padding(.horizontal, 4)

                    if let upNext { nextCard(upNext.step, reason: upNext.reason) }

                    SectionLabel(loc.t("drill.filter.all"))
                        .padding(.top, 6)

                    VStack(spacing: 0) {
                        ForEach(settings.steps) { step in
                            Button {
                                Haptic.tap.play()
                                selected = step
                            } label: {
                                StepRow(step: step, status: settings.status(of: step))
                            }
                            .buttonStyle(RowPressStyle())
                            .accessibilityIdentifier("learn.step.\(step.id)")

                            if step.id != settings.steps.last?.id {
                                RowDivider().padding(.leading, 82)
                            }
                        }
                    }
                    .card(padding: 0)

                    // Under the steps, never above them: the page opens on
                    // what to learn, the offer waits at the end of the list.
                    PremiumShortcut(place: "learn.premium")
                        .padding(.top, 6)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            if let id = LaunchOptions.openStep {
                selected = settings.steps.first { $0.id == id }
            }
            if LaunchOptions.opensAnalytics { showsAnalytics = true }
            openReminderStep()
        }
        .onChange(of: reminders.pendingStepID) { _, _ in openReminderStep() }
        .sheet(item: $selected, onDismiss: { Nudges.shared.pause(.stepClosed) }) { step in
            StepDetailView(step: step)
                .localized(settings.localizer)
                .environment(settings)
        }
        .sheet(isPresented: $showsAnalytics) {
            AnalyticsView { step in
                // Closing first and opening on the next runloop: two sheets
                // asked for in the same frame leave iOS showing neither.
                showsAnalytics = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { selected = step }
            }
            .localized(settings.localizer)
            .environment(settings)
        }
    }

    /// Consumed once: leaving the id in place would reopen the sheet every
    /// time this view comes back.
    private func openReminderStep() {
        guard let id = reminders.pendingStepID else { return }
        selected = settings.steps.first { $0.id == id }
        reminders.pendingStepID = nil
    }

    // MARK: The step to open now

    /// One card, one button. Whatever the reader's state — first launch, three
    /// steps started, everything acquired — there is exactly one obvious thing
    /// to press, and it is green.
    private func nextCard(_ step: PrayerStep, reason: StudyPlanner.Reason) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                PositionMedallion(step: step, size: 84)

                VStack(alignment: .leading, spacing: 6) {
                    Text(loc.t(reasonKey(reason)))
                        .font(Theme.rounded(11.5, .black))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(reason == .learning ? Theme.goldDeep : Theme.primaryDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(reason == .learning ? Theme.goldSoft : Theme.primarySoft))

                    Text(step.name)
                        .font(Theme.title(21))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Button {
                selected = step
            } label: {
                Text(loc.t("common.continue"))
            }
            .buttonStyle(.cta(.primary, height: 54))
            .accessibilityIdentifier("learn.continue")
        }
        .card()
    }

    private func reasonKey(_ reason: StudyPlanner.Reason) -> String {
        switch reason {
        case .learning: return "analytics.reason.learning"
        case .new:      return "analytics.reason.new"
        case .review:   return "analytics.reason.review"
        }
    }
}

// MARK: - Row

/// A row of the list: the posture, the step's name, the first words. The step
/// number rides on the medallion instead of taking a line of its own.
private struct StepRow: View {
    let step: PrayerStep
    let status: StepStatus
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(spacing: 14) {
            PositionMedallion(step: step, size: 54)
                .overlay(alignment: .bottomTrailing) {
                    Text(String(step.order))
                        .font(Theme.rounded(11, .black).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Circle().fill(Theme.primary))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 4, y: 4)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(step.name)
                    .font(Theme.rounded(16.5, .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)

                Text(step.spoken ? step.phoneticLines[0] : loc.t("detail.silent"))
                    .font(Theme.rounded(13, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Acquired is a badge, in progress is a sprout — two objects that
            // differ in shape, not only in colour, so the list still reads at a
            // glance and for someone who cannot tell green from gold.
            switch status {
            case .known:
                LofiIcon(.check, size: 34, animated: false)
            case .learning:
                LofiIcon(.sprout, size: 34, animated: false)
            case .untouched:
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.border)
                    .frame(width: 34)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A row inside a card answers a touch by tinting, not by sinking: the card is
/// the object, the row is only a place on it.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.primarySoft.opacity(0.7) : .clear)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Progress bar

/// One bar, two readings: the pale stretch is the ground already walked on
/// (steps being learned), the solid green is what is actually held. Two separate
/// bars would say the same thing twice and imply two separate races.
struct ProgressBar: View {
    let value: Double
    /// Acquired *plus* in progress. Defaults to `value` for the callers that
    /// only track one number.
    var secondary: Double?
    let total: Double
    var tint: Color = Theme.primary
    var track: Color = Theme.sand

    init(value: Double, secondary: Double? = nil, total: Double,
         tint: Color = Theme.primary, track: Color = Theme.sand) {
        self.value = value
        self.secondary = secondary
        self.total = total
        self.tint = tint
        self.track = track
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                if let secondary, secondary > value {
                    Capsule()
                        .fill(Theme.goldSoft)
                        .overlay(Capsule().strokeBorder(Theme.edge(for: Theme.goldSoft), lineWidth: 1.5))
                        .frame(width: width(secondary, in: geo))
                }
                Capsule()
                    .fill(tint)
                    // A lighter band along the top: the bar reads as a filled
                    // tube rather than as a coloured rectangle.
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.28))
                            .frame(height: geo.size.height * 0.28)
                            .padding(.horizontal, geo.size.height * 0.3)
                            .padding(.top, geo.size.height * 0.18)
                    }
                    .frame(width: width(value, in: geo))
                    .animation(Theme.spring, value: value)
            }
        }
    }

    private func width(_ amount: Double, in geo: GeometryProxy) -> CGFloat {
        max(geo.size.width * min(max(amount / total, 0), 1),
            amount > 0 ? geo.size.height : 0)
    }
}
