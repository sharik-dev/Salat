import SwiftUI
import CoreText

private final class ThemeBundleToken {}

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

    // MARK: Pixel face

    /// The pixel face from 5min, used **only for numbers and short uppercase
    /// labels** — step counters, "12 / 14", the small gold captions. Never for
    /// the prayer text, the translations or the Arabic: `04b_30` has no Arabic
    /// at all, and a sacred text set in an arcade face would be grotesque.
    /// This is the app's furniture, not its content.
    public static func pixel(_ size: CGFloat) -> Font {
        registerPixelFont()
        guard let family = pixelFamily else {
            // Rounded and heavy is the closest vector stand-in, and it covers
            // the accents 04b_30 is missing.
            return .system(size: size * 0.78, weight: .heavy, design: .rounded)
        }
        return .custom(family, size: snap(size))
    }

    /// The face is drawn on an 8px grid. A size that is not a multiple of 8
    /// falls between two pixels and the stems of an `M` stop matching — the
    /// whole point of a pixel face goes with it.
    public static func snap(_ size: CGFloat) -> CGFloat {
        max(8, (size / 8).rounded() * 8)
    }

    private static var pixelFamily: String?
    private static var pixelRegistrationTried = false

    /// Registering through CoreText rather than `UIAppFonts` avoids having to
    /// hand-write an Info.plist: the project builds with
    /// `GENERATE_INFOPLIST_FILE = YES`, and a hand-added plist would be
    /// overwritten. It also works from the widget extension unchanged.
    public static func registerPixelFont() {
        guard !pixelRegistrationTried else { return }
        pixelRegistrationTried = true
        let bundle = Bundle(for: ThemeBundleToken.self)
        guard let url = bundle.url(forResource: "04b30", withExtension: "ttf"),
              let data = NSData(contentsOf: url),
              let provider = CGDataProvider(data: data),
              let font = CGFont(provider) else { return }
        CTFontManagerRegisterGraphicsFont(font, nil)
        pixelFamily = font.postScriptName as String?
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

public extension View {
    /// Every card in the app is a `Plate` — an outlined face with a solid
    /// bottom face under it. See `Plate.swift` for why that beats a shadow.
    func card(radius: CGFloat = Theme.Radius.card) -> some View {
        plate(Theme.surface, radius: radius)
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

// MARK: - Step numeral

/// The step number as a pixel numeral on a sand chip.
///
/// It is a bare numeral rather than "Step 5" because `04b_30` has no `É`, and
/// the French "ÉTAPE" fell back glyph by glyph into a visible mix of two
/// typefaces. Digits are the one thing the pixel face renders identically in
/// every language the app ships.
public struct StepBadge: View {
    public let order: Int
    public var size: CGFloat = 12

    public init(order: Int, size: CGFloat = 12) {
        self.order = order
        self.size = size
    }

    public var body: some View {
        Text(String(format: "%02d", order))
            .font(Theme.pixel(size))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.sand)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1)
                    )
            )
    }
}
