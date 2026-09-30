import WidgetKit
import SwiftUI

/// The widget's presentation lives in the kit, not in the extension: the app
/// renders the very same views in a debug screen, so what gets reviewed is
/// literally what iOS will draw.

// MARK: - Entry

public struct CarouselEntry: TimelineEntry {
    public let date: Date
    public let step: PrayerStep
    public let position: Int
    public let total: Int
    public let localizer: Localizer
    /// Which text leads the card — the reader's pick, made in the widget tool.
    public let focus: WidgetFocus

    public init(date: Date, step: PrayerStep, position: Int, total: Int,
                localizer: Localizer, focus: WidgetFocus = .phonetic) {
        self.date = date
        self.step = step
        self.position = position
        self.total = total
        self.localizer = localizer
        self.focus = focus
    }
}

public struct CarouselWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    public let entry: CarouselEntry

    /// WidgetKit supplies the family through the environment, and that
    /// environment value is read-only — so the debug preview inside the app
    /// passes the family in directly instead.
    private let forcedFamily: WidgetFamily?
    private let forcedMode: WidgetRenderingMode?

    public init(entry: CarouselEntry,
                family: WidgetFamily? = nil,
                mode: WidgetRenderingMode? = nil) {
        self.entry = entry
        self.forcedFamily = family
        self.forcedMode = mode
    }

    private var family: WidgetFamily { forcedFamily ?? environmentFamily }
    private var mode: WidgetRenderingMode { forcedMode ?? renderingMode }

    // MARK: Palette
    //
    // A tinted home screen (and the lock screen) do not show what the widget
    // painted: iOS keeps only its luminance and re-tints it. The cream card
    // then disappears and the brown ink with it — the widget reads as an empty
    // plate. In those modes everything is redrawn light on nothing.

    private var isFullColor: Bool { mode == .fullColor }
    private var ink: Color      { isFullColor ? Theme.ink : .white }
    private var inkSoft: Color  { isFullColor ? Theme.inkSoft : .white.opacity(0.7) }
    private var accent: Color   { isFullColor ? Theme.gold : .white.opacity(0.85) }

    public var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                // The lock screen has no page to set anything down on.
                accessory
            case .systemSmall:  plated(small, radius: 20)
            case .systemLarge:  plated(large, radius: 22)
            default:            plated(medium, radius: 22)
            }
        }
        .localized(entry.localizer)
        .containerBackground(for: .widget) {
            if isFullColor {
                ZStack {
                    Theme.paper
                    StarLattice(spacing: 46, opacity: 0.09)
                }
            } else {
                // Painting the cream here would be re-read as luminance and
                // washed over the content; the system's own plate is what a
                // tinted home screen expects to see.
                Color.clear
            }
        }
    }

    /// The app never lays text straight onto the page: it sets it on a plate —
    /// cream face, thick ink outline, a solid face extruded underneath. The
    /// widget is the corner of the app that shows on the home screen, so it
    /// gets the same object. A tinted home screen keeps only luminance, and an
    /// ink outline there would come back as a grey box, so that rendering does
    /// without the plate rather than draw a broken one.
    private func plated<V: View>(_ content: V, radius: CGFloat) -> some View {
        Group {
            if isFullColor {
                content
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .plate(Theme.surface, radius: radius)
                    .padding(.horizontal, 7)
                    .padding(.top, 7)
                    .padding(.bottom, 3)
            } else {
                content
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: The three canvases — same layout, more room

    private var small: some View {
        layout(medallion: 30, title: 11, size: 14, floor: 0.45, arabic: 12, spacing: 5)
    }

    private var medium: some View {
        layout(medallion: 34, title: 13, size: 16, floor: 0.45, arabic: 14, spacing: 6)
    }

    private var large: some View {
        layout(medallion: 40, title: 15, size: 19, floor: 0.5, arabic: 17, spacing: 8)
    }

    // MARK: Pieces

    /// One layout for all three sizes, because they say the same thing at
    /// different volumes. What changes is how much fits, and that is not decided
    /// here: `ViewThatFits` tries the fullest version first — the lead text plus
    /// both companions — and falls back a rung at a time until one fits the
    /// canvas it was given. A short formula on a large widget therefore gets the
    /// whole card; the Fatiha on a small one keeps the lead text alone.
    ///
    /// *Which* text leads is `entry.focus` — the reader's pick, not the
    /// layout's. The lead is what never gets dropped; the other two are the
    /// rungs of the ladder.
    private func layout(medallion: CGFloat, title: CGFloat, size: CGFloat,
                        floor: CGFloat, arabic: CGFloat, spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            header(medallion: medallion, title: title)

            ViewThatFits(in: .vertical) {
                block(size: size, floor: floor, arabic: arabic,
                      companions: companionOrder, spacing: spacing)
                block(size: size, floor: floor, arabic: arabic,
                      companions: [preferredCompanion], spacing: spacing)
                block(size: size, floor: floor, arabic: arabic,
                      companions: [], spacing: spacing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack {
                counter
                Spacer(minLength: 0)
            }
        }
    }

    /// The two texts that are not the lead, in the order they stack under it.
    private var companionOrder: [WidgetFocus] {
        switch entry.focus {
        case .phonetic:    return [.arabic, .translation]
        case .arabic:      return [.phonetic, .translation]
        case .translation: return [.arabic, .phonetic]
        }
    }

    /// The companion that survives when only one fits: the meaning under the
    /// pronunciation, the pronunciation under the script, the script under the
    /// meaning — always the closest help for what is being read.
    private var preferredCompanion: WidgetFocus {
        switch entry.focus {
        case .phonetic:    return .translation
        case .arabic:      return .phonetic
        case .translation: return .arabic
        }
    }

    private func block(size: CGFloat, floor: CGFloat, arabic: CGFloat,
                       companions: [WidgetFocus], spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing * 0.7) {
            lead(size: size, floor: floor)

            ForEach(companions, id: \.rawValue) { kind in
                companion(kind, size: size, arabic: arabic)
            }
        }
    }

    @ViewBuilder
    private func companion(_ kind: WidgetFocus, size: CGFloat, arabic: CGFloat) -> some View {
        if entry.step.spoken, !text(for: kind).isEmpty {
            switch kind {
            case .arabic:
                Text(entry.step.arabic)
                    .font(Theme.arabic(arabic))
                    .foregroundStyle(inkSoft)
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            case .phonetic, .translation:
                Text(text(for: kind))
                    .font(kind == .phonetic ? Theme.body(size * 0.72).italic()
                                            : Theme.body(size * 0.72))
                    .foregroundStyle(inkSoft)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func text(for kind: WidgetFocus) -> String {
        switch kind {
        case .phonetic:    return entry.step.phonetic
        case .arabic:      return entry.step.arabic
        case .translation: return entry.step.translation
        }
    }

    /// The illustration is a **marker**, not the subject: it says which posture
    /// this is at a glance and then gets out of the way. What is being learnt is
    /// the pronunciation, so the picture shrank to make room for it.
    private func header(medallion: CGFloat, title: CGFloat) -> some View {
        HStack(spacing: 7) {
            PositionMedallion(step: entry.step, size: medallion, monochrome: !isFullColor)
            Text(entry.step.name)
                .font(Theme.title(title))
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    /// The reason the widget exists: the text being learnt, in the reader's
    /// chosen form. Shown **whole** — every line of the block, never a first
    /// line and an ellipsis — and allowed to shrink a long way rather than be
    /// cut, because half a formula teaches nothing. A step that says nothing
    /// aloud (the niyyah) falls back to what it does instead, and a lead whose
    /// text is empty (phonetic in the Arabic locale) falls back to the Arabic.
    @ViewBuilder
    private func lead(size: CGFloat, floor: CGFloat) -> some View {
        if !entry.step.spoken {
            Text(entry.step.postureText)
                .font(Theme.body(size * 0.85))
                .foregroundStyle(inkSoft)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(floor)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            let kind = text(for: entry.focus).isEmpty ? WidgetFocus.arabic : entry.focus
            switch kind {
            case .arabic:
                Text(entry.step.arabic)
                    .font(Theme.arabic(size * 1.1))
                    .foregroundStyle(ink)
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(floor)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            case .phonetic:
                Text(entry.step.phonetic)
                    .font(Theme.body(size).italic())
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(floor)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            case .translation:
                Text(entry.step.translation)
                    .font(Theme.body(size))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(floor)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: Lock screen

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.step.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(accessoryLine)
                .font(.system(size: 12))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The lock screen has room for one line; it is the lead text's first line,
    /// same pick as the widget's card.
    private var accessoryLine: String {
        guard entry.step.spoken else { return entry.step.translationLines[0] }
        switch entry.focus {
        case .phonetic:
            let line = entry.step.phoneticLines[0]
            return line.isEmpty ? entry.step.arabicLines[0] : line
        case .arabic:      return entry.step.arabicLines[0]
        case .translation: return entry.step.translationLines[0]
        }
    }

    /// The same sand chip that numbers a step in the list — the widget counts
    /// with the app's furniture, not with a loose line of text.
    private var counter: some View {
        Text("\(entry.position) / \(entry.total)")
            .font(Theme.pixel(10))
            .foregroundStyle(accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isFullColor ? Theme.sand : Color.white.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isFullColor ? Theme.gold.opacity(0.45)
                                                      : Color.white.opacity(0.35),
                                          lineWidth: 1)
                    )
            )
    }
}

