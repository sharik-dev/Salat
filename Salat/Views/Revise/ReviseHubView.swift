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
            VStack(spacing: 0) {
                Banner(title: loc.t("tab.memorize"),
                       subtitle: nil, subtitleAction: nil, subtitleID: nil, back: nil) {
                    LofiIcon(.bulb, size: 100, interval: 4)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        startCard

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(ReviseTool.allCases.filter { $0 != .widget }) { tool in
                                NavigationLink(value: ReviseRoute.tool(tool)) {
                                    ToolTile(tool: tool)
                                }
                                .chunky(Theme.surface, radius: 26, depth: 5)
                                .accessibilityIdentifier("revise.tool.\(tool.rawValue)")
                            }
                        }
                        .padding(.top, 4)

                        NavigationLink(value: ReviseRoute.tool(.widget)) {
                            ToolRow(tool: .widget)
                        }
                        .chunky(Theme.surface, radius: 26, depth: 5)
                        .accessibilityIdentifier("revise.tool.widget")

                        strengthSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReviseRoute.self) { route in
                Group {
                switch route {
                case .tool(.drill):
                    DrillPickerView()
                case .drillRun(let run):
                    DrillSessionView(run: run)
                case .tool(.flash):
                    FlashcardsView()
                case .tool(.fade):
                    FadeGalleryView()
                case .tool(.vocal):
                    VocalGalleryView()
                case .tool(.widget):
                    WidgetToolView()
                case .step(let id):
                    if let step = settings.steps.first(where: { $0.id == id }) {
                        VocalStepView(step: step)
                    }
                case .fadeStep(let id):
                    if let step = settings.steps.first(where: { $0.id == id }) {
                        FadeStepView(step: step)
                    }
                }
                }
                .onAppear {
                    if case .tool(let tool) = route {
                        Telemetry.shared.track("tool_open", props: ["tool": tool.rawValue])
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
                // `-openTool fade -openStep <id>` lands on the fading ladder;
                // a bare `-openStep` keeps its old meaning, the vocal page.
                path = LaunchOptions.openTool == ReviseTool.fade.rawValue
                    ? [.tool(.fade), .fadeStep(step.id)]
                    : [.tool(.vocal), .step(step.id)]
            } else if let raw = LaunchOptions.openTool, let tool = ReviseTool(rawValue: raw) {
                // `-openTool drill` still lands in a dealt round — every
                // script and UI test expects a question on screen — with the
                // picker beneath; `-drillPicker 1` stops on the gallery.
                if tool == .drill, !LaunchOptions.opensDrillPicker {
                    path = [.tool(.drill), .drillRun(DrillRun())]
                } else {
                    path = [.tool(tool)]
                }
            }
        }
        .onChange(of: path) { _, new in
            // Coming back from a round: the tally moved while we were away.
            if new.isEmpty { scores = DrillLog.scores }
        }
    }

    /// One tap to a round, from the top of the tab. This is the door you use
    /// every day, and burying it under a list would make a daily gesture cost
    /// two taps for no reason.
    @ViewBuilder
    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                LofiIcon(.quiz, size: 76, interval: 5, animated: pool.count >= 2)

                if pool.count >= 2 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(pool.count))
                            .font(Theme.rounded(34, .black).monospacedDigit())
                            .foregroundStyle(Theme.primary)
                        // The count is the badge; the sentence never repeats it,
                        // so no language has to bend a plural around a number.
                        Text(loc.t("memorize.ready"))
                            .font(Theme.rounded(14, .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(loc.t("drill.empty"))
                        .font(Theme.rounded(14.5, .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if pool.count >= 2 {
                Button {
                    // Straight into the dealt mix — the daily gesture stays
                    // one tap — with the picker beneath it on the way back.
                    path = [.tool(.drill), .drillRun(DrillRun())]
                } label: {
                    Text(loc.t("memorize.start"))
                }
                .buttonStyle(.cta(.primary))
                .accessibilityIdentifier("memorize.start")
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
            SectionLabel(loc.t("memorize.strength.title"))
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(seen) { step in
                    HStack(spacing: 12) {
                        Text(step.name)
                            .font(Theme.rounded(15.5, .heavy))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        PipRow(filled: scores[step.id]?.pips ?? 0)
                    }
                    .padding(.horizontal, Theme.cardPadding)
                    .padding(.vertical, 13)
                    if step.id != seen.last?.id { RowDivider().padding(.leading, Theme.cardPadding) }
                }
            }
            .card(padding: 0)
            .accessibilityIdentifier("memorize.strength")
        }
    }
}

// MARK: - Pips

/// Five dots, green once earned. The same ladder wherever recall is drawn.
struct PipRow: View {
    let filled: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < filled ? Theme.primary : Theme.sand)
                    .frame(width: 11, height: 11)
            }
        }
    }
}

// MARK: - Tools

enum ReviseTool: String, CaseIterable, Identifiable, Hashable {
    /// Eight questions built from the steps already read.
    case drill
    /// See the meaning, say the line, flip the card to check — recall where
    /// the drill is recognition.
    case flash
    /// The same text with fewer and fewer words, until it carries itself.
    case fade
    /// Listen to a reciter, record yourself, put the two side by side.
    case vocal
    /// The home screen widget: what it does, and what it shows — the tool that
    /// keeps the memorising going between two sessions.
    case widget

    var id: String { rawValue }

    var titleKey: String { "revise.tool.\(rawValue).title" }
    var bodyKey: String { "revise.tool.\(rawValue).body" }

    var icon: Icon3D {
        switch self {
        case .drill: return .quiz
        case .flash: return .cards
        case .fade:  return .eraser
        case .vocal: return .mic
        case .widget: return .phone
        }
    }
}

/// Routing is a value, so a deep link is just an array.
enum ReviseRoute: Hashable {
    case tool(ReviseTool)
    case step(String)
    /// The fading ladder for one step — a different page than the vocal one.
    case fadeStep(String)
    /// One chosen run of exercises, below the picker gallery.
    case drillRun(DrillRun)
}

/// A tool as a tile: its object, its name. The sentence that used to sit
/// under each title is gone — the object says what the tool is, and the tool's
/// own page says the rest.
private struct ToolTile: View {
    let tool: ReviseTool
    @Environment(\.loc) private var loc

    var body: some View {
        VStack(spacing: 8) {
            LofiIcon(tool.icon, size: 78, interval: 6)
            Text(loc.t(tool.titleKey))
                .font(Theme.rounded(16, .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .top)
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

/// The same tool laid flat, for the one that closes the list.
private struct ToolRow: View {
    let tool: ReviseTool
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(spacing: 14) {
            LofiIcon(tool.icon, size: 58, interval: 6)
            Text(loc.t(tool.titleKey))
                .font(Theme.rounded(16, .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Toolbar

extension View {
    /// The pushed screens of *Memorise* keep the banner's green under the nav
    /// bar, with a white title and back arrow. Left to itself the bar is system
    /// white, which reads as another app's screen sliding in.
    func paperToolbar() -> some View {
        self.toolbarBackground(Theme.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .background(Theme.paper.ignoresSafeArea())
    }
}
