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

    public init(date: Date, step: PrayerStep, position: Int, total: Int, localizer: Localizer) {
        self.date = date
        self.step = step
        self.position = position
        self.total = total
        self.localizer = localizer
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

    // MARK: Small — the pronunciation, and just enough to place it

    private var small: some View {
        VStack(spacing: 5) {
            header(medallion: 30, title: 11)
            pronunciation(size: 14, floor: 0.45)
            counter
        }
    }

    // MARK: Medium — the pronunciation in full, the illustration as a marker

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(medallion: 34, title: 13)
            pronunciation(size: 16, floor: 0.45)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                counter
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Large — the same, with the Arabic underneath it

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(medallion: 40, title: 15)

            pronunciation(size: 19, floor: 0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if entry.step.spoken {
                Divider().background(isFullColor ? Theme.border : Color.white.opacity(0.3))

                Text(entry.step.arabic)
                    .font(Theme.arabic(15))
                    .foregroundStyle(inkSoft)
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .minimumScaleFactor(0.5)
            }

            HStack {
                counter
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Pieces

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

    /// The reason the widget exists: the words to say, spelled the way the
    /// reader reads. Shown **whole** — every line of the block, never a first
    /// line and an ellipsis — and allowed to shrink a long way rather than be
    /// cut, because half a formula teaches nothing. A step that says nothing
    /// aloud (the niyyah) falls back to what it does instead.
    private func pronunciation(size: CGFloat, floor: CGFloat) -> some View {
        Text(entry.step.spoken ? entry.step.phonetic : entry.step.postureText)
            .font(entry.step.spoken ? Theme.body(size).italic() : Theme.body(size * 0.85))
            .foregroundStyle(entry.step.spoken ? ink : inkSoft)
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(floor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Lock screen

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.step.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(entry.step.spoken ? entry.step.phoneticLines[0] : entry.step.translationLines[0])
                .font(.system(size: 12))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

