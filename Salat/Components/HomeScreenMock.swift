import SwiftUI
import WidgetKit

/// A drawn iPhone home screen, with the **real** widget on it.
///
/// Three places need to show "this is what you will see on your phone": the
/// widget's own page, its how-to guide, and the welcome. All three draw the
/// same thing, and the widget in it is `CarouselWidgetView` itself, scaled:
/// what a reader is promised here is literally what iOS will draw.

// MARK: - The widget, at any width

/// The real widget view on its canonical canvas, scaled to the width it is
/// given. Scaled rather than re-laid out: a widget drawn at another size would
/// wrap its text differently, and the picture would stop being the widget.
struct WidgetSnapshot: View {
    let entry: CarouselEntry
    var family: WidgetFamily = .systemMedium
    let width: CGFloat

    private var canvas: CGSize {
        family == .systemSmall ? CGSize(width: 170, height: 170) : CGSize(width: 364, height: 170)
    }

    var body: some View {
        let scale = width / canvas.width
        CarouselWidgetView(entry: entry, family: family, mode: .fullColor)
            .frame(width: canvas.width, height: canvas.height)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .scaleEffect(scale)
            .frame(width: canvas.width * scale, height: canvas.height * scale)
            .shadow(color: .black.opacity(0.22), radius: 8 * scale, y: 5 * scale)
            // The widget speaks the reader's language even when the mock-up
            // around it is pinned left-to-right.
            .accessibilityHidden(true)
    }
}

// MARK: - Wallpaper and icons

/// A deep-green wallpaper: dark enough that the white widget is the first
/// thing seen, green enough to still be this app.
struct HomeWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A8E60), Color(hex: 0x11472F)],
                           startPoint: .top, endPoint: .bottom)
            StarLattice(spacing: 58, opacity: 0.08, color: .white)
        }
    }
}

/// One row of four anonymous app icons. Pastel blanks on purpose: any drawn
/// glyph would read as a real app, and the eye should stay on the widget.
struct HomeIconRow: View {
    let side: CGFloat
    let gap: CGFloat
    var row = 0
    /// Edit mode: the icons jiggle, the way they do once the screen is held.
    var jiggle: Double?

    private static let tints: [Color] = [
        Color(hex: 0xFFF6E3), Color(hex: 0xFCE3A1), Color(hex: 0xBFE9D1), Color(hex: 0xF2B93B),
        Color(hex: 0xEAD9B8), Color(hex: 0x9FDDBB), Color(hex: 0xFFFFFF), Color(hex: 0xF7C9A8)
    ]

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<4, id: \.self) { column in
                let index = row * 4 + column
                RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
                    .fill(Self.tints[(index * 3 + row) % Self.tints.count].opacity(0.92))
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(jiggle.map { sin($0 * 14 + Double(index)) * 2.5 } ?? 0))
            }
        }
    }
}

// MARK: - The home screen

/// The top of a home screen: the widget across the width, the app's name under
/// it the way iOS labels a widget, then rows of icons.
struct HomeScreenMock: View {
    let entry: CarouselEntry
    var rows = 1
    /// The clock of the status bar, when the mock-up shows one.
    var clock: String?

    var body: some View {
        GeometryReader { geo in
            let pad = geo.size.width * 0.07
            let inner = geo.size.width - pad * 2
            let gap = inner * 0.075
            let side = (inner - gap * 3) / 4

            ZStack(alignment: .top) {
                HomeWallpaper()

                VStack(spacing: 0) {
                    if let clock {
                        Text(clock)
                            .font(Theme.rounded(inner * 0.052, .black).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, inner * 0.04)
                            .padding(.bottom, pad * 0.55)
                            .contentTransition(.numericText())
                    }

                    WidgetSnapshot(entry: entry, width: inner)
                        .id(entry.step.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))

                    Text(verbatim: "Salat")
                        .font(Theme.rounded(inner * 0.04, .heavy))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, inner * 0.022)
                        .padding(.bottom, gap * 0.7)

                    VStack(spacing: gap * 0.85) {
                        ForEach(0..<rows, id: \.self) { HomeIconRow(side: side, gap: gap, row: $0) }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.top, pad * (clock == nil ? 1 : 0.7))
            }
        }
        // A home screen is not mirrored content: the widget inside localises
        // itself, the furniture around it stays where iOS puts it.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}
