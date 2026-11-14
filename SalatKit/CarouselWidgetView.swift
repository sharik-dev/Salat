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
    /// True when Salat Premium is not active: the widget then draws an
    /// invitation to open the app instead of its content. Only the extension
    /// ever sets it, the previews inside the app always show the real card,
    /// since showing it is how the widget is sold.
    public let locked: Bool

    public init(date: Date, step: PrayerStep, position: Int, total: Int,
                localizer: Localizer, focus: WidgetFocus = .phonetic,
                locked: Bool = false) {
        self.date = date
        self.step = step
        self.position = position
        self.total = total
        self.localizer = localizer
        self.focus = focus
        self.locked = locked
    }

    /// A verse of the Qur'an on the card. It has no phonetic, so a reader who
    /// asked for the pronunciation first gets the Arabic first: that is the
    /// text the pronunciation would have been of.
    public init(date: Date, verse: WidgetVerse, position: Int, total: Int,
                localizer: Localizer, focus: WidgetFocus = .arabic) {
        self.init(date: date, step: PrayerStep(verse: verse),
                  position: position, total: total, localizer: localizer,
                  focus: focus == .phonetic ? .arabic : focus)
    }

    /// What the extension draws without a subscription.
    public static func locked(date: Date, localizer: Localizer) -> CarouselEntry {
        let none = PrayerStep(id: "", order: 0, image: "", posture: .standing,
                              repetitions: 1, spoken: false, arabic: "",
                              name: "", postureText: "", phonetic: "",
                              translation: "", note: "")
        return CarouselEntry(date: date, step: none, position: 0, total: 0,
                             localizer: localizer, locked: true)
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
    // painted: iOS keeps only its luminance and re-tints it. The white card
    // then disappears and the dark ink with it — the widget reads as an empty
    // plate. In those modes everything is redrawn light on nothing.

    private var isFullColor: Bool { mode == .fullColor }
    private var ink: Color      { isFullColor ? Theme.ink : .white }
    private var inkSoft: Color  { isFullColor ? Theme.inkSoft : .white.opacity(0.7) }

    public var body: some View {
        Group {
            if entry.locked {
                // The green is painted here as well as in the container
                // background: the previews inside the app are not WidgetKit
                // containers and would draw white words on the page.
                lockedCard
                    .background { if isFullColor { greenGround } }
            } else {
                card
            }
        }
        .localized(entry.localizer)
        // A locked widget opens the paywall; an open one just opens the app.
        .widgetURL(entry.locked ? Premium.unlockURL : nil)
        .containerBackground(for: .widget) {
            if !isFullColor {
                // Painting anything here would be re-read as luminance and
                // washed over the content; the system's own plate is what a
                // tinted home screen expects to see.
                Color.clear
            } else if entry.locked {
                greenGround
            } else {
                Theme.surface
            }
        }
    }

    @ViewBuilder
    private var card: some View {
            switch family {
            case .accessoryRectangular:
                // The lock screen has no page to set anything down on.
                accessory
            case .systemSmall:
                if isFullColor {
                    banded(band: 60, figure: 58, title: 13.5, showsCounter: false,
                           size: 15, floor: 0.45, arabic: 13, spacing: 5, inset: 12)
                } else {
                    bare(medallion: 30, title: 11, size: 14, floor: 0.45, arabic: 12, spacing: 5)
                }
            case .systemLarge:
                if isFullColor {
                    banded(band: 104, figure: 104, title: 21, showsCounter: true,
                           size: 20, floor: 0.5, arabic: 18, spacing: 9, inset: 16)
                } else {
                    bare(medallion: 40, title: 15, size: 19, floor: 0.5, arabic: 17, spacing: 8)
                }
            default:
                if isFullColor {
                    sided
                } else {
                    bare(medallion: 34, title: 13, size: 16, floor: 0.45, arabic: 14, spacing: 6)
                }
            }
    }

    // MARK: Locked — the widget is Salat Premium
    //
    // Without a subscription the widget says so and nothing else: the app's
    // green from edge to edge, the 3D padlock, and one line that tells where
    // to go. It is white on green in full colour and white on nothing when the
    // home screen is tinted, so it never depends on a dark ink to be read.

    @ViewBuilder
    private var lockedCard: some View {
        let title = entry.localizer.t("premium.title")
        let hint = entry.localizer.t("widget.locked.body")

        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(hint)
                    .font(.system(size: 12))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 14) {
                padlock(84)
                lockedWords(title: title, hint: hint, titleSize: 19, hintSize: 14,
                            alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            let large = family == .systemLarge
            VStack(spacing: large ? 14 : 6) {
                padlock(large ? 132 : 66)
                lockedWords(title: title, hint: hint,
                            titleSize: large ? 24 : 15, hintSize: large ? 16 : 12,
                            alignment: .center)
            }
            .padding(large ? 22 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func lockedWords(title: String, hint: String, titleSize: CGFloat,
                             hintSize: CGFloat, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(Theme.rounded(titleSize, .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(hint)
                .font(Theme.rounded(hintSize, .heavy))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
    }

    /// The 3D padlock of the app, or its silhouette on a tinted home screen
    /// (the render carries its shape in its alpha, like the figures do).
    @ViewBuilder
    private func padlock(_ size: CGFloat) -> some View {
        if let image = PositionAsset.image(named: "widget_lock", maxPixel: size * 3) {
            Image(uiImage: image)
                .renderingMode(isFullColor ? .original : .template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.6, weight: .black))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
    }

    // MARK: Full colour — the app's banner, at widget size
    //
    // The widget is the corner of the app that lives on the home screen, so it
    // is built like the app's own pages: a green ground carrying the 3D figure
    // and the step's name, and the words on white underneath. The widget draws
    // to its very edge (`contentMarginsDisabled` in the extension): the green
    // has to reach the corners to read as a banner and not as a box in a box.

    /// The banner's green with the house lattice in white.
    private var greenGround: some View {
        ZStack {
            Theme.primary
            StarLattice(spacing: 34, opacity: 0.16, color: .white)
        }
    }

    private func figure(_ size: CGFloat) -> some View {
        PositionMedallion(step: entry.step, size: size, framed: false)
    }

    /// Small and large: the green runs across the top.
    private func banded(band: CGFloat, figure side: CGFloat, title: CGFloat, showsCounter: Bool,
                        size: CGFloat, floor: CGFloat, arabic: CGFloat,
                        spacing: CGFloat, inset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                figure(side)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.step.name)
                        .font(Theme.rounded(title, .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .multilineTextAlignment(.leading)
                    if showsCounter { counter }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, inset - 6)
            .padding(.trailing, inset)
            .frame(maxWidth: .infinity)
            .frame(height: band)
            .background(greenGround)

            texts(size: size, floor: floor, arabic: arabic, spacing: spacing)
                .padding(.horizontal, inset)
                .padding(.vertical, inset * 0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Medium: the green stands on the leading side, the words get the width.
    private var sided: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                figure(106)
                counter
            }
            .frame(width: 118)
            .frame(maxHeight: .infinity)
            .background(greenGround)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.step.name)
                    .font(Theme.rounded(13, .black))
                    .foregroundStyle(Theme.primaryDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                texts(size: 17, floor: 0.45, arabic: 15, spacing: 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Tinted — light on nothing

    /// A tinted home screen keeps only luminance: no ground, no banner, the
    /// figure as a light silhouette and every text in white.
    private func bare(medallion: CGFloat, title: CGFloat, size: CGFloat,
                      floor: CGFloat, arabic: CGFloat, spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(spacing: 7) {
                PositionMedallion(step: entry.step, size: medallion, monochrome: true)
                Text(entry.step.name)
                    .font(Theme.title(title))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }

            texts(size: size, floor: floor, arabic: arabic, spacing: spacing)

            Spacer(minLength: 0)

            HStack {
                counter
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Pieces

    /// What changes from one size to the next is how much fits, and that is not
    /// decided here: `ViewThatFits` tries the fullest version first — the lead
    /// text plus both companions — and falls back a rung at a time until one
    /// fits the room it was given. A short formula on a large widget therefore
    /// gets all three texts; the Fatiha on a small one keeps the lead alone.
    ///
    /// *Which* text leads is `entry.focus` — the reader's pick, not the
    /// layout's. The lead is what never gets dropped; the other two are the
    /// rungs of the ladder.
    private func texts(size: CGFloat, floor: CGFloat, arabic: CGFloat, spacing: CGFloat) -> some View {
        ViewThatFits(in: .vertical) {
            block(size: size, floor: floor, arabic: arabic,
                  companions: companionOrder, spacing: spacing)
            block(size: size, floor: floor, arabic: arabic,
                  companions: [preferredCompanion], spacing: spacing)
            block(size: size, floor: floor, arabic: arabic,
                  companions: [], spacing: spacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(Theme.rounded(size * 0.72, kind == .phonetic ? .heavy : .semibold))
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
                    .font(Theme.rounded(size, .heavy))
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

    /// Where the cycle stands. Only ever drawn on the green ground or on a
    /// tinted home screen, so it is white on a veil in both.
    private var counter: some View {
        Text("\(entry.position) / \(entry.total)")
            .font(Theme.rounded(10.5, .black).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.22)))
    }
}
