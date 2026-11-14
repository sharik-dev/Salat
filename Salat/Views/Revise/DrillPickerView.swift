import SwiftUI

/// The landing page of *Exercises*: a gallery, not a corridor. The dealt
/// round used to be the only door; now it is the first card of many, and the
/// reader picks the exercise — and optionally the step — instead of taking
/// what the deal imposes.
///
/// The step filter narrows what is asked, never what distracts: wrong answers
/// keep coming from the whole prayer, or the filtered run would be answered
/// by elimination.
struct DrillPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    /// nil is "all steps" — the default, and the only state the old screen had.
    @State private var subject: String?

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    private var pool: Set<String> { settings.learned.union(settings.learningNow) }
    private var poolSteps: [PrayerStep] {
        settings.steps.filter { pool.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if poolSteps.count < 2 {
                    emptyState
                } else {
                    Text(loc.t("drill.picker.subtitle"))
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    stepFilter
                    mixedCard

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DrillFocus.gallery, id: \.self) { focus in
                            focusCard(focus)
                        }
                    }
                }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .animation(Theme.spring, value: subject)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(loc.t("revise.tool.drill.title"))
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
    }

    // MARK: The step filter

    /// One row of chips, "all" first. A picker wheel would hide the choices;
    /// fourteen names in a sheet would bury a two-tap gesture. The chips show
    /// only the steps that have been read — the same pool the drill draws on.
    private var stepFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(loc.t("drill.filter.all"), selected: subject == nil) {
                    subject = nil
                }
                .accessibilityIdentifier("drill.filter.all")
                ForEach(poolSteps) { step in
                    chip(step.name, selected: subject == step.id) {
                        subject = subject == step.id ? nil : step.id
                    }
                    .accessibilityIdentifier("drill.filter.\(step.id)")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ label: String, selected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.rounded(13.5, .black))
                .foregroundStyle(selected ? .white : Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
        }
        .chunky(selected ? Theme.primary : Theme.surface, radius: 16, depth: 4,
                haptic: .select)
    }

    // MARK: The cards

    /// The dealt mix keeps the top spot and the full width: it is still the
    /// best default, it just stopped being the only option.
    private var mixedCard: some View {
        NavigationLink(value: ReviseRoute.drillRun(DrillRun(focus: .mixed,
                                                            subject: subject))) {
            HStack(spacing: 14) {
                LofiIcon(.quiz, size: 62, interval: 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.t("drill.picker.mixed.title"))
                        .font(Theme.title(19))
                        .foregroundStyle(Theme.ink)
                    Text(loc.t("drill.picker.mixed.body"))
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.cardPadding)
            .contentShape(Rectangle())
        }
        .chunky(Theme.surface, radius: Theme.Radius.card, depth: 5)
        .accessibilityIdentifier("drill.picker.mixed")
    }

    @ViewBuilder
    private func focusCard(_ focus: DrillFocus) -> some View {
        let run = DrillRun(focus: focus, subject: subject)
        let count = Drill.available(run, steps: settings.steps, pool: pool)

        NavigationLink(value: ReviseRoute.drillRun(run)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    plate(icon(focus))
                    Spacer(minLength: 0)
                    // How many exercises the door opens on — a fact, not a score.
                    Text("\(count)")
                        .font(Theme.rounded(14, .black).monospacedDigit())
                        .foregroundStyle(Theme.primaryDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.primarySoft))
                }
                Text(loc.t(focus.titleKey))
                    .font(Theme.title(16))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(14)
            .contentShape(Rectangle())
        }
        .chunky(Theme.surface, radius: 22, depth: 5)
        // Greyed, not hidden: a card that vanishes with the filter looks like
        // a bug; a card that stays pale says "not for this step".
        .disabled(count == 0)
        .opacity(count == 0 ? 0.4 : 1)
        .accessibilityIdentifier("drill.picker.\(identifier(focus))")
    }

    private func plate(_ systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.primarySoft)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Theme.primaryDeep)
            )
            .frame(width: 44, height: 44)
    }

    private func icon(_ focus: DrillFocus) -> String {
        switch focus {
        case .mixed:            return "square.grid.2x2.fill"
        case .kind(.nextStep):  return "arrow.right.circle.fill"
        case .kind(.posture):   return "figure.stand"
        case .kind(.nextLine):  return "text.line.first.and.arrowtriangle.forward"
        case .kind(.blank):     return "character.cursor.ibeam"
        case .kind(.meaning):   return "text.book.closed.fill"
        case .pairs:            return "arrow.triangle.swap"
        case .order:            return "shuffle"
        }
    }

    private func identifier(_ focus: DrillFocus) -> String {
        switch focus {
        case .mixed:           return "mixed"
        case .kind(let kind):  return kind.rawValue
        case .pairs:           return "pairs"
        case .order:           return "order"
        }
    }

    private var emptyState: some View {
        Text(loc.t("drill.empty"))
            .font(Theme.body(15))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityIdentifier("drill.picker.empty")
    }
}
