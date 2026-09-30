import SwiftUI

/// What the reader has actually done, and what to go back to.
///
/// The list in *Learn* answers "where am I in the prayer"; this page answers
/// "where am I in the work" — which days were spent on it, which steps were
/// claimed and when, and which one has been left alone the longest. The last
/// section is the same queue the daily reminder reads, on purpose: the
/// notification and the screen must never name two different steps.
struct AnalyticsView: View {
    /// Handed a step when a row is tapped, so the caller can open its page.
    let onOpen: (PrayerStep) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @Environment(\.dismiss) private var dismiss

    /// Thirteen weeks: a season of reading, and the widest grid that still fits
    /// a portrait screen without shrinking a day to a crumb.
    private static let calendarWeeks = 13

    private var calendar: Calendar { .current }
    private var now: Date { Date() }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            StarLattice().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    title
                    tiles
                    calendarCard
                    dueCard
                    acquiredCard
                    journalCard
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
            }
            .chunky(Theme.sand, radius: 12, depth: 3)
            .padding(16)
        }
    }

    // MARK: Title

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc.t("analytics.title"))
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(loc.t("analytics.subtitle"))
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.trailing, 44) // clear the close button
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The four numbers

    private var tiles: some View {
        HStack(spacing: 10) {
            tile(String(settings.learned.count), loc.t("analytics.stat.known"), Theme.green)
            tile(String(settings.learningNow.count), loc.t("analytics.stat.learning"), Theme.gold)
            tile(String(settings.log.studyDays(calendar: calendar).count),
                 loc.t("analytics.stat.days"), Theme.ink)
            tile(String(settings.log.streak(now: now, calendar: calendar)),
                 loc.t("analytics.stat.streak"), Theme.ink)
        }
    }

    private func tile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.pixel(20))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.label(9))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .plate(Theme.surface, radius: Theme.Radius.chip)
    }

    // MARK: The days

    private var calendarCard: some View {
        let days = settings.log.studyDays(calendar: calendar)
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(loc.t("analytics.calendar.title"), icon: "calendar")

            // Columns are weeks, rows are weekdays — a season fits in one glance
            // and the gaps are the point: a week left blank is visible as a
            // column of empty squares, not as a missing number.
            HStack(spacing: 4) {
                ForEach(weekStarts, id: \.self) { weekStart in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { offset in
                            let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                            square(day: day, studied: days.contains(calendar.startOfDay(for: day)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(loc.t("analytics.calendar.hint"))
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func square(day: Date, studied: Bool) -> some View {
        let future = calendar.startOfDay(for: day) > calendar.startOfDay(for: now)
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(studied ? Theme.gold : Theme.sand.opacity(future ? 0.35 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(studied ? 0.55 : 0.12), lineWidth: 1)
            )
            .aspectRatio(1, contentMode: .fit)
    }

    /// The Mondays (or whatever the locale's first weekday is) of the last
    /// thirteen weeks, oldest first.
    private var weekStarts: [Date] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let backToStart = (weekday - calendar.firstWeekday + 7) % 7
        guard let thisWeek = calendar.date(byAdding: .day, value: -backToStart, to: today)
        else { return [] }
        return (0..<Self.calendarWeeks).reversed().compactMap {
            calendar.date(byAdding: .day, value: -7 * $0, to: thisWeek)
        }
    }

    // MARK: What to go back to

    private var dueCard: some View {
        let due = Array(settings.dueQueue(now: now).prefix(4))
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(loc.t("analytics.due.title"), icon: "arrow.uturn.backward")

            if due.isEmpty {
                Text(loc.t("analytics.due.empty"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(loc.t("analytics.due.hint"))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(due) { item in
                    if let step = settings.step(item.stepID) {
                        Button { onOpen(step) } label: {
                            HStack(spacing: 10) {
                                PositionMedallion(step: step, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.name)
                                        .font(Theme.title(15))
                                        .foregroundStyle(Theme.ink)
                                        .multilineTextAlignment(.leading)
                                    Text(reasonLine(item))
                                        .font(Theme.label(10))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                        }
                        .chunky(Theme.sand.opacity(0.7), radius: Theme.Radius.chip,
                                depth: 2, haptic: .tap, sparks: false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// Why this step is at the top, and how long it has been waiting. The two
    /// together are the whole argument for opening it.
    private func reasonLine(_ item: StudyPlanner.Due) -> String {
        let reason: String
        switch item.reason {
        case .learning: reason = loc.t("analytics.reason.learning")
        case .new:      reason = loc.t("analytics.reason.new")
        case .review:   reason = loc.t("analytics.reason.review")
        }
        // A step never opened has nothing to say about how long ago that was:
        // "never opened · never opened" is what saying it twice looks like.
        guard let last = item.lastStudied else { return reason }
        return "\(reason) · \(elapsed(last))"
    }

    private func elapsed(_ date: Date) -> String {
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return loc.t("analytics.ago.today")
        case 1:    return loc.t("analytics.ago.yesterday")
        default:   return loc.t("analytics.ago.days", days)
        }
    }

    // MARK: What is held

    private var acquiredCard: some View {
        let acquired = settings.steps
            .filter { settings.status(of: $0) == .known }
            .sorted { lhs, rhs in
                let a = settings.log.record(for: lhs.id).knownSince ?? .distantPast
                let b = settings.log.record(for: rhs.id).knownSince ?? .distantPast
                return a == b ? lhs.order < rhs.order : a > b
            }

        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(loc.t("analytics.learned.title"), icon: "checkmark.seal")

            if acquired.isEmpty {
                Text(loc.t("analytics.learned.empty"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(acquired) { step in
                    HStack(spacing: 8) {
                        StepBadge(order: step.order, size: 10)
                        Text(step.name)
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        // A step ticked in the two-state version has no date to
                        // show: it was never recorded, and inventing one would
                        // put a lie in the only history the reader has.
                        Text(settings.log.record(for: step.id).knownSince.map(dayLabel)
                             ?? loc.t("analytics.date.unknown"))
                            .font(Theme.label(10))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: The journal

    private var journalCard: some View {
        let recent = settings.log.events.suffix(24).reversed()
        let grouped = Dictionary(grouping: recent) { calendar.startOfDay(for: $0.date) }

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle(loc.t("analytics.timeline.title"), icon: "clock.arrow.circlepath")

            if recent.isEmpty {
                Text(loc.t("analytics.timeline.empty"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(dayLabel(day).uppercased())
                            .font(Theme.label(9))
                            .foregroundStyle(Theme.gold)
                            .tracking(0.8)

                        ForEach(grouped[day] ?? []) { event in
                            HStack(spacing: 7) {
                                Image(systemName: icon(event.kind))
                                    .font(.system(size: 10))
                                    .foregroundStyle(colour(event.kind))
                                    .frame(width: 14)
                                Text(line(event))
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func line(_ event: StudyEvent) -> String {
        let name = settings.step(event.stepID)?.name ?? event.stepID
        switch event.kind {
        case .opened:   return loc.t("analytics.event.opened", name)
        case .learning: return loc.t("analytics.event.learning", name)
        case .known:    return loc.t("analytics.event.known", name)
        }
    }

    private func icon(_ kind: StudyEvent.Kind) -> String {
        switch kind {
        case .opened:   return "eye"
        case .learning: return "book.fill"
        case .known:    return "checkmark.seal.fill"
        }
    }

    private func colour(_ kind: StudyEvent.Kind) -> Color {
        switch kind {
        case .opened:   return Theme.inkSoft
        case .learning: return Theme.gold
        case .known:    return Theme.green
        }
    }

    // MARK: Bits

    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text.uppercased()).font(Theme.label(9)).tracking(0.8)
        }
        .foregroundStyle(Theme.gold)
    }

    /// Dates are written in the app's language, not the phone's: someone reading
    /// the prayer in French on a Turkish phone chose French.
    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = loc.locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }
}
