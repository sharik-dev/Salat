import SwiftUI

struct LearnView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StudyReminders.self) private var reminders
    @Environment(\.loc) private var loc
    @State private var selected: PrayerStep?
    @State private var showsAnalytics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ForEach(settings.steps) { step in
                    Button {
                        selected = step
                    } label: {
                        StepRow(step: step, status: settings.status(of: step))
                    }
                    .buttonStyle(.plain)
                }
                Color.clear.frame(height: 92) // clear the floating bar
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .task {
            if let id = LaunchOptions.openStep {
                selected = settings.steps.first { $0.id == id }
            }
            if LaunchOptions.opensAnalytics { showsAnalytics = true }
            openReminderStep()
        }
        .onChange(of: reminders.pendingStepID) { _, _ in openReminderStep() }
        .sheet(item: $selected) { step in
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc.t("learn.title"))
                .font(Theme.title(30))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(loc.t("learn.subtitle", settings.steps.count))
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)

            ProgressBar(value: Double(settings.learned.count),
                        secondary: Double(settings.learned.count + settings.learningNow.count),
                        total: Double(max(settings.steps.count, 1)))
                .frame(height: 10)
                .padding(.top, 4)

            HStack(spacing: 10) {
                Text(loc.t("learn.progress", settings.learned.count, settings.steps.count))
                if !settings.learningNow.isEmpty {
                    Text(loc.t("learn.progress.learning", settings.learningNow.count))
                        .foregroundStyle(Theme.gold)
                }
            }
            .font(Theme.label(11))
            .foregroundStyle(Theme.inkSoft)

            // The analytics page hangs off the header rather than the tab bar:
            // it is a second look at *this* list, not a fourth place to be.
            Button {
                showsAnalytics = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text(loc.t("analytics.open"))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .font(Theme.label(12))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .chunky(Theme.sand, radius: Theme.Radius.chip, haptic: .tap, sparks: false)
            .padding(.top, 6)
            .accessibilityIdentifier("learn.analytics")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
        .accessibilityIdentifier("learn.header")
    }
}

// MARK: - Row

private struct StepRow: View {
    let step: PrayerStep
    let status: StepStatus
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(spacing: 14) {
            PositionMedallion(step: step, size: 62)

            VStack(alignment: .leading, spacing: 4) {
                StepBadge(order: step.order)

                Text(step.name)
                    .font(Theme.title(17))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)

                Text(step.spoken ? step.phoneticLines[0] : loc.t("detail.silent"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Acquired is a seal, in progress is an open book — two marks that
            // differ in shape, not only in colour, so the list still reads at a
            // glance and for someone who cannot tell green from gold.
            switch status {
            case .known:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.green)
                    .font(.system(size: 18))
            case .learning:
                Image(systemName: "book.fill")
                    .foregroundStyle(Theme.gold)
                    .font(.system(size: 15))
            case .untouched:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Progress bar

/// One bar, two readings: the pale stretch is the ground already walked on
/// (steps being learned), the solid gold is what is actually held. Two separate
/// bars would say the same thing twice and imply two separate races.
struct ProgressBar: View {
    let value: Double
    /// Acquired *plus* in progress. Defaults to `value` for the callers that
    /// only track one number.
    var secondary: Double?
    let total: Double

    init(value: Double, secondary: Double? = nil, total: Double) {
        self.value = value
        self.secondary = secondary
        self.total = total
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.sand)
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                if let secondary, secondary > value {
                    Capsule()
                        .fill(Theme.goldSoft)
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                        .frame(width: width(secondary, in: geo))
                }
                Capsule()
                    .fill(Theme.gold)
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                    .frame(width: width(value, in: geo))
            }
        }
    }

    private func width(_ amount: Double, in geo: GeometryProxy) -> CGFloat {
        max(geo.size.width * min(max(amount / total, 0), 1),
            amount > 0 ? geo.size.height : 0)
    }
}
