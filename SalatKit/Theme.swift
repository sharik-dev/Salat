import SwiftUI

/// Visual identity « Jardin » : warm beige page, white cards, a frank garden
/// green for everything you can press, and gold kept as the one accent — the
/// word being recited, a step in progress, a reward.
///
/// The shapes and the motion come from SelfTransfer (rounded SF, thick pastel
/// outlines, buttons that sink on their edge, 3D clay icons). Only the palette
/// is Salat's own.
public enum Theme {

    // MARK: Palette

    public static let paper       = Color(hex: 0xFAF4E6) // page background
    public static let surface     = Color(hex: 0xFFFFFF) // cards
    public static let sand        = Color(hex: 0xF3EAD6) // filled beige blocks, quiet buttons
    public static let border      = Color(hex: 0xE7DBC1) // card outlines
    public static let line        = Color(hex: 0xF0E7D3) // separators inside a card

    /// The green of the banner, the main button, the active tab.
    public static let primary       = Color(hex: 0x2FA56F)
    /// The edge under a green button, links, green text on a light ground.
    public static let primaryDeep   = Color(hex: 0x1E7A50)
    /// Selected rows, the active tab's pill, the posture medallion.
    public static let primarySoft   = Color(hex: 0xE1F4E8)
    public static let primaryBorder = Color(hex: 0xB9E4CB)

    /// The accent: the word being said, a step in progress, a reward.
    public static let gold        = Color(hex: 0xDE9A12)
    public static let goldSoft    = Color(hex: 0xFCECC2)
    public static let goldDeep    = Color(hex: 0xB67A0A)

    public static let ink         = Color(hex: 0x1F3329) // primary text
    public static let inkSoft     = Color(hex: 0x6C7B70) // secondary text

    /// "Acquired", a right answer. Same hue as `primary` on purpose: knowing a
    /// step and pressing the main button are the same good news.
    public static let green       = Color(hex: 0x2FA56F)
    public static let greenSoft   = Color(hex: 0xD3F0DF)

    public static let danger      = Color(hex: 0xE5604F)

    /// The sparks thrown when a button comes back up: gold on any ground.
    public static let sparkFace   = Color(hex: 0xFFD45E)
    public static let sparkEdge   = Color(hex: 0xDE9A12)

    // MARK: Radii

    public enum Radius {
        public static let card: CGFloat = 26
        public static let chip: CGFloat = 16
        public static let bar: CGFloat  = 24
    }

    /// The margin between a card's outline and whatever it holds. One value for
    /// the whole app: cards of the same family with different rims read as
    /// misaligned, and a thin rim lets a long word touch the edge.
    public static let cardPadding: CGFloat = 18

    // MARK: Type

    /// Everything is SF Rounded: it is what makes the app read as friendly
    /// rather than as a manuscript.
    public static func rounded(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    public static func title(_ size: CGFloat) -> Font { rounded(size, .black) }

    public static func body(_ size: CGFloat = 16) -> Font { rounded(size, .semibold) }

    public static func label(_ size: CGFloat = 12) -> Font { rounded(size, .heavy) }

    /// Numbers — step counters, "12 / 14", seconds. It used to be a pixel face;
    /// the name stayed because every counter in the app calls it.
    public static func pixel(_ size: CGFloat) -> Font {
        rounded(size * 0.92, .black).monospacedDigit()
    }

    /// Kept for the call sites that sized the old pixel face on its grid.
    public static func snap(_ size: CGFloat) -> CGFloat { size }

    /// Nothing to register any more; the app and the widget still call it.
    public static func registerPixelFont() {}

    /// Arabic needs a face that carries the diacritics without crushing them.
    public static func arabic(_ size: CGFloat = 26) -> Font {
        .custom("Geeza Pro", size: size)
    }

    // MARK: Motion

    public static let spring = Animation.spring(duration: 0.4, bounce: 0.25)
    public static let softSpring = Animation.spring(duration: 0.5, bounce: 0.15)
}

// MARK: - Card surface

public extension View {
    /// Every card in the app is a `Plate` — a white face with a thick pastel
    /// outline. See `Plate.swift`.
    ///
    /// The inner margin belongs to the card, not to the call site: a card is an
    /// object with a rim, and text that runs into that rim reads as a bug. Pass
    /// `padding:` to narrow it; `0` is for the rare card whose content must
    /// reach the edge itself (a scroll view, an image).
    func card(radius: CGFloat = Theme.Radius.card,
              padding: CGFloat = Theme.cardPadding) -> some View {
        self.padding(padding)
            // A card with no padding holds rows that reach its edge: clipped,
            // so a pressed first or last row keeps the card's rounded corners.
            .clipShape(RoundedRectangle(cornerRadius: padding == 0 ? radius : 0, style: .continuous))
            .plate(Theme.surface, radius: radius)
    }
}

// MARK: - Geometric background pattern

/// A faint eight-point star lattice (khatam), drawn — never an image, so it
/// stays crisp at any size and adds no weight to the widget.
public struct StarLattice: View {
    public var spacing: CGFloat = 64
    public var opacity: Double = 0.05
    public var color: Color = Theme.gold

    public init(spacing: CGFloat = 64, opacity: Double = 0.05, color: Color = Theme.gold) {
        self.spacing = spacing
        self.opacity = opacity
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let r = spacing * 0.30
            var y: CGFloat = 0
            var row = 0
            while y < size.height + spacing {
                var x: CGFloat = (row % 2 == 0) ? 0 : spacing / 2
                while x < size.width + spacing {
                    context.stroke(
                        Self.star(center: CGPoint(x: x, y: y), radius: r),
                        with: .color(color.opacity(opacity)),
                        lineWidth: 1.5
                    )
                    x += spacing
                }
                y += spacing
                row += 1
            }
        }
        .allowsHitTesting(false)
    }

    /// Two squares at 45° — the simplest islamic star, and the most legible small.
    static func star(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for rotation in [0.0, Double.pi / 4] {
            var first = true
            for corner in 0..<4 {
                let a = rotation + Double(corner) * .pi / 2
                let p = CGPoint(x: center.x + radius * CGFloat(cos(a)),
                                y: center.y + radius * CGFloat(sin(a)))
                if first { path.move(to: p); first = false } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Hex colour

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Step numeral

/// The step number in a small green pill. A bare numeral rather than "Step 5":
/// digits are the one thing that reads identically in the fourteen languages.
public struct StepBadge: View {
    public let order: Int
    public var size: CGFloat = 12
    /// White when the badge sits on a mint ground, where its own mint vanishes.
    public var fill: Color = Theme.primarySoft

    public init(order: Int, size: CGFloat = 12, fill: Color = Theme.primarySoft) {
        self.order = order
        self.size = size
        self.fill = fill
    }

    public var body: some View {
        Text(String(order))
            .font(Theme.rounded(size, .black).monospacedDigit())
            .foregroundStyle(Theme.primaryDeep)
            .padding(.horizontal, size * 0.62)
            .padding(.vertical, size * 0.2)
            .frame(minWidth: size * 2)
            .background(Capsule().fill(fill))
    }
}
