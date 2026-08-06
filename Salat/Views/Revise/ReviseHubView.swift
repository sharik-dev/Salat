import SwiftUI

/// The *Memorise* tab is a landing page, not a screen: memorising means several
/// different tools, and each one deserves its own room.
///
/// What it is **not** any more is a second reading screen. The carousel that
/// used to live here showed the same fourteen steps *Learn* already shows, only
/// slower — the home screen widget does that job, and doing it twice added
/// nothing to this tab. What earns a tab is being asked: the drill starts from
/// the steps already read and puts them back as questions.
///
/// Adding a tool is adding a case to `ReviseTool` — the hub, the icons and the
/// routing follow from it.
struct ReviseHubView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    /// Set at launch by `-startTab practice -openStep <id>`, which lands
    /// straight on that step's vocal page.
    @State private var path: [ReviseRoute] = []
    /// Read once per appearance rather than on every redraw: these live in the
    /// shared defaults, not in `@Observable` state, so nothing would tell the
    /// view to look again.
    @State private var scores: [String: DrillScore] = [:]

    private var pool: [PrayerStep] {
        let ids = settings.learned.union(settings.learningNow)
        return settings.steps.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    startCard
                    ForEach(ReviseTool.allCases) { tool in
                        NavigationLink(value: ReviseRoute.tool(tool)) {
                            ToolCard(tool: tool)
                        }
                        .buttonStyle(.plain)
                    }
                    strengthSection
                    Color.clear.frame(height: 92) // clear the floating bar
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationDestination(for: ReviseRoute.self) { route in
                switch route {
                case .tool(.drill):
                    DrillSessionView()
                case .tool(.vocal):
                    VocalGalleryView()
                case .step(let id):
                    if let step = settings.steps.first(where: { $0.id == id }) {
                        VocalStepView(step: step)
                    }
                }
            }
        }
        .task {
            scores = DrillLog.scores
            // Deep link into the stack: Sharik drives from his phone and cannot
            // tap through two levels in the simulator.
            if let id = LaunchOptions.openStep,
               let step = settings.steps.first(where: { $0.id == id }), step.spoken {
                path = [.tool(.vocal), .step(step.id)]
            } else if let raw = LaunchOptions.openTool, let tool = ReviseTool(rawValue: raw) {
                path = [.tool(tool)]
            }
        }
        .onChange(of: path) { _, new in
            // Coming back from a round: the tally moved while we were away.
            if new.isEmpty { scores = DrillLog.scores }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc.t("tab.memorize"))
                .font(Theme.title(30))
                .foregroundStyle(Theme.ink)
            Text(loc.t("revise.subtitle"))
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    /// One tap to a round, from the top of the tab. The tool card below leads to
    /// the same place; this is the door you use every day, and burying it under
    /// a list would make a daily gesture cost two taps for no reason.
    @ViewBuilder
    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if pool.count >= 2 {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", pool.count))
                        .font(Theme.pixel(24))
                        .foregroundStyle(Theme.gold)
                    // The count is the badge; the sentence never repeats it, so
                    // no language has to bend a plural around a number.
                    Text(loc.t("memorize.ready"))
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    path = [.tool(.drill)]
                } label: {
                    Text(loc.t("memorize.start"))
                        .font(Theme.label(14))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .chunky(Theme.goldSoft, radius: 16, haptic: .press)
                .accessibilityIdentifier("memorize.start")
            } else {
                Text(loc.t("drill.empty"))
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// What the rounds have shown so far. Pips, never a percentage: this counts
    /// answers to the app's own questions, and a figure printed next to the name
    /// of a prayer step would read as a mark on the step itself.
    @ViewBuilder
    private var strengthSection: some View {
        let seen = pool.filter { (scores[$0.id]?.asked ?? 0) > 0 }
        if !seen.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.t("memorize.strength.title"))
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.gold)
                    .textCase(.uppercase)

                ForEach(seen) { step in
                    HStack(spacing: 12) {
                        Text(step.name)
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        PipRow(filled: scores[step.id]?.pips ?? 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityIdentifier("memorize.strength")
        }
    }
}

// MARK: - Pips

/// Five dots, gold once earned. The same ladder wherever recall is drawn.
struct PipRow: View {
    let filled: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < filled ? Theme.gold : Theme.sand)
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(0.55), lineWidth: 1))
                    .frame(width: 9, height: 9)
            }
        }
    }
}

// MARK: - Tools

enum ReviseTool: String, CaseIterable, Identifiable, Hashable {
    /// Eight questions built from the steps already read.
    case drill
    /// Listen to a reciter, record yourself, put the two side by side.
    case vocal

    var id: String { rawValue }

    var titleKey: String { "revise.tool.\(rawValue).title" }
    var bodyKey: String { "revise.tool.\(rawValue).body" }

    var icon: String {
        switch self {
        case .drill: return "questionmark.circle.fill"
        case .vocal: return "waveform"
        }
    }
}

/// Routing is a value, so a deep link is just an array.
enum ReviseRoute: Hashable {
    case tool(ReviseTool)
    case step(String)
}

private struct ToolCard: View {
    let tool: ReviseTool
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(spacing: 14) {
            // The gold plate carries the icon: on cream, a bare glyph next to a
            // serif title reads as a bullet point rather than as a door.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.goldSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: Theme.stroke)
                )
                .overlay(
                    Image(systemName: tool.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                )
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(loc.t(tool.titleKey))
                    .font(Theme.title(19))
                    .foregroundStyle(Theme.ink)
                Text(loc.t(tool.bodyKey))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Toolbar

extension View {
    /// The pushed screens of *Memorise* keep the app's paper under the nav bar.
    /// Left to itself the bar is system white, which on cream reads as another
    /// app's screen sliding in.
    func paperToolbar() -> some View {
        self.toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
