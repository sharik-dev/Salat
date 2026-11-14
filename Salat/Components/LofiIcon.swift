import SwiftUI

/// The app's 3D icons: real objects modelled and animated in Blender
/// (`tools/blender/icons.py`, built on the shared kit `~/Documents/tools/icon3d`),
/// rendered as seven transparent frames each and filed in
/// `Assets.xcassets/Icons3D` by the kit's `pack_icons.py`.
///
/// Anything that stands for an *object* is one of these. SF Symbols are kept
/// for pure controls only: close, chevrons, play, undo.
enum Icon3D: String, CaseIterable {
    // Tabs
    case book = "Book"
    case quran = "Quran"
    case bulb = "Bulb"
    case gear = "Gear"

    // The prayer's own furniture
    case mosque = "Mosque"
    case mat = "Mat"
    case lantern = "Lantern"
    case star = "Star"
    case moon = "Moon"
    case sparkle = "Sparkle"

    // Memorising tools
    case quiz = "Quiz"
    case cards = "Cards"
    case eraser = "Eraser"
    case mic = "Mic"
    case phone = "Phone"
    case headphones = "Headphones"

    // Status and progress
    case check = "Check"
    case sprout = "Sprout"
    case flame = "Flame"
    case calendar = "Calendar"
    case chart = "Chart"
    case trophy = "Trophy"

    // Settings
    case globe = "Globe"
    case bell = "Bell"
    case scroll = "Scroll"
    case shield = "Shield"
    case lock = "Lock"
    case trash = "Trash"

    /// Frames per animation; frame 0 is the resting pose.
    static let frameCount = 7

    func frame(_ index: Int) -> String { "Icon3D\(rawValue)_\(index)" }

    /// One frame, for decor that drives its own animation (the sparks of a
    /// celebration). `scale`: the object only fills part of its render, so the
    /// image is drawn larger than its layout frame.
    func image(frame index: Int = 0, width: CGFloat, scale: CGFloat = 1.24) -> some View {
        Image(frame(((index % Self.frameCount) + Self.frameCount) % Self.frameCount))
            .resizable()
            .interpolation(.high)
            .frame(width: width * scale, height: width * scale)
            .frame(width: width, height: width)
    }
}

/// A 3D icon at rest that plays its little "lofi" animation every `interval`
/// seconds: the rendered frames run at 8 per second with no cross-fade — the
/// stutter of frame-by-frame animation.
struct LofiIcon: View {
    let icon: Icon3D
    var size: CGFloat = 56
    /// Seconds between two plays.
    var interval: Double = 4
    var animated = true

    init(_ icon: Icon3D, size: CGFloat = 56, interval: Double = 4, animated: Bool = true) {
        self.icon = icon
        self.size = size
        self.interval = interval
        self.animated = animated
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let fps: Double = 8

    var body: some View {
        Group {
            if animated && !reduceMotion {
                // The clock only ticks during the seven frames, then goes quiet
                // until the next play: an icon at rest costs nothing.
                TimelineView(LofiSchedule(interval: interval, offset: offset)) { context in
                    image(frame(at: context.date))
                }
            } else {
                image(0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func image(_ index: Int) -> some View {
        Image(icon.frame(index))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

    /// An offset per icon (from its name) so they do not all move together.
    private var offset: Double {
        Double(icon.rawValue.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % 97) / 97 * interval
    }

    private func frame(at date: Date) -> Int {
        let t = date.timeIntervalSinceReferenceDate + offset
        let index = Int((t.truncatingRemainder(dividingBy: interval) * Self.fps).rounded(.down))
        return index < Icon3D.frameCount ? index : 0
    }
}

/// Update dates of a `LofiIcon`: eight tight beats at the start of each cycle
/// (the seven frames, then back to rest), nothing in between.
struct LofiSchedule: TimelineSchedule {
    let interval: Double
    let offset: Double

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        let step = 1 / LofiIcon.fps
        var cycle = ((startDate.timeIntervalSinceReferenceDate + offset) / interval).rounded(.down)
        var k = 0
        return AnyIterator {
            // Low-power mode (dimmed screen): only the resting pose each cycle.
            let frames = mode == .lowFrequency ? 1 : Icon3D.frameCount + 1
            if k >= frames { k = 0; cycle += 1 }
            let t = cycle * interval - offset + (Double(k) + 0.02) * step
            k += 1
            return Date(timeIntervalSinceReferenceDate: t)
        }
    }
}

/// An icon on its soft tile: the leading mark of a settings row, a tool, a stat.
struct IconTile: View {
    let icon: Icon3D
    var size: CGFloat = 52
    var fill: Color = Theme.primarySoft
    var animated = false

    var body: some View {
        LofiIcon(icon, size: size * 0.78, interval: 4, animated: animated)
            .frame(width: size, height: size)
            .background(fill, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
            ForEach(Icon3D.allCases, id: \.self) { LofiIcon($0, size: 80, interval: 2) }
        }
    }
}
