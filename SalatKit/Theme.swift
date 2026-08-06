import SwiftUI

/// Visual identity: cream paper, warm sand, muted gold. Sober, no imagery, no
/// hard black — the palette of an old manuscript rather than of an interface.
public enum Theme {

    // MARK: Palette

    public static let paper      = Color(hex: 0xFBF6EC) // main background
    public static let surface    = Color(hex: 0xFFFDF7) // cards
    public static let sand       = Color(hex: 0xEFE3CC) // filled blocks
    public static let border     = Color(hex: 0xE3D6B9)
    public static let gold       = Color(hex: 0xC1962C) // accent
    public static let goldSoft   = Color(hex: 0xE8D9A8)
    public static let ink        = Color(hex: 0x2E2A22) // primary text
    public static let inkSoft    = Color(hex: 0x7A6E5B) // secondary text
    public static let green      = Color(hex: 0x5C7A5A) // "learned" marker

    // MARK: Radii

    public enum Radius {
        public static let card: CGFloat = 22
        public static let chip: CGFloat = 12
        public static let bar: CGFloat  = 24
    }

    // MARK: Type

    /// Titles use a serif face — it reads as a book rather than as an app.
    public static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    public static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    public static func label(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// Arabic needs a face that carries the diacritics without crushing them.
    public static func arabic(_ size: CGFloat = 26) -> Font {
        .custom("Geeza Pro", size: size)
    }

    // MARK: Motion

    public static let spring = Animation.spring(response: 0.35, dampingFraction: 0.78)
    public static let softSpring = Animation.spring(response: 0.5, dampingFraction: 0.85)
}

// MARK: - Card surface

public struct CardBackground: ViewModifier {
    var radius: CGFloat = Theme.Radius.card
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.05), radius: 12, y: 4)
    }
}

public extension View {
    func card(radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardBackground(radius: radius))
    }
}

// MARK: - Geometric background pattern

/// A faint eight-point star lattice (khatam), drawn — never an image, so it
/// stays crisp at any size and adds no weight to the widget.
public struct StarLattice: View {
    public var spacing: CGFloat = 64
    public var opacity: Double = 0.055

    public init(spacing: CGFloat = 64, opacity: Double = 0.055) {
        self.spacing = spacing
        self.opacity = opacity
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
                        with: .color(Theme.gold.opacity(opacity)),
                        lineWidth: 1
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
