import SwiftUI

struct LearnView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @State private var selected: PrayerStep?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ForEach(settings.steps) { step in
                    Button {
                        selected = step
                    } label: {
                        StepRow(step: step, isLearned: settings.isLearned(step))
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
        }
        .sheet(item: $selected) { step in
            StepDetailView(step: step)
                .localized(settings.localizer)
                .environment(settings)
        }
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
                        total: Double(max(settings.steps.count, 1)))
                .frame(height: 10)
                .padding(.top, 4)

            Text(loc.t("learn.progress", settings.learned.count, settings.steps.count))
                .font(Theme.label(11))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
        .accessibilityIdentifier("learn.header")
    }
}

// MARK: - Row

private struct StepRow: View {
    let step: PrayerStep
    let isLearned: Bool
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

            if isLearned {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.green)
                    .font(.system(size: 18))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    let value: Double
    let total: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.sand)
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                Capsule()
                    .fill(Theme.gold)
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                    .frame(width: max(geo.size.width * min(max(value / total, 0), 1),
                                      value > 0 ? geo.size.height : 0))
            }
        }
    }
}
