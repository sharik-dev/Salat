import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The form language borrowed from **5min**: a rounded rectangle with a thick
/// ink outline and a solid bottom face extruded straight down — no blur, no
/// drop shadow. That bottom face is what makes a block read as an *object set
/// down* rather than a coloured area, and it is what makes the app feel warm
/// and handled rather than printed.
///
/// Only the shapes are borrowed. 5min sits on dark felt with saturated
/// accents; here the same forms are cut in cream, sand and gold, and the
/// outline is the brown ink — a near-black rule on cream would punch holes in
/// the page instead of drawing edges.

public extension Theme {
    /// Outline weight. Thinner than 5min's 3pt: the contrast between brown ink
    /// and cream is already high, and 3pt on this palette reads as a border,
    /// not as an edge.
    static let stroke: CGFloat = 2

    /// Extrusion at rest, and once pressed. It is this delta that is felt —
    /// not a colour change, which a thumb covers anyway.
    static let chunk: CGFloat = 5
    static let chunkPressed: CGFloat = 1.5

    /// The bottom face of `color`: the same hue, darkened.
    static func shade(_ color: Color, _ amount: CGFloat = 0.28) -> Color {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(s * 1.10, 1), brightness: b * (1 - amount), opacity: a)
        #else
        return color.opacity(0.7)
        #endif
    }
}

// MARK: - The plate

/// A flat top face, an ink outline, and a bottom face of the same hue darkened.
/// The base is drawn as its own shape offset downward rather than as a thicker
/// bottom border, because a border can only be one colour and two are needed:
/// ink around, darkened hue underneath.
public struct Plate<Content: View>: View {
    var color: Color
    var radius: CGFloat
    var depth: CGFloat
    var border: CGFloat
    @ViewBuilder var content: () -> Content

    public init(color: Color = Theme.surface,
                radius: CGFloat = Theme.Radius.card,
                depth: CGFloat = Theme.chunk,
                border: CGFloat = Theme.stroke,
                @ViewBuilder content: @escaping () -> Content) {
        self.color = color
        self.radius = radius
        self.depth = depth
        self.border = border
        self.content = content
    }

    public var body: some View {
        content()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Theme.shade(color))
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(Theme.ink, lineWidth: border)
                        )
                        .offset(y: depth)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(color)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(Theme.ink, lineWidth: border)
                        )
                }
            )
            .padding(.bottom, depth)
    }
}

public extension View {
    /// Sets any view down on a plate.
    func plate(_ color: Color = Theme.surface,
               radius: CGFloat = Theme.Radius.card,
               depth: CGFloat = Theme.chunk,
               border: CGFloat = Theme.stroke) -> some View {
        Plate(color: color, radius: radius, depth: depth, border: border) { self }
    }
}

// MARK: - The button that sinks

/// The top face travels down onto its base and the thickness shrinks. The
/// haptic fires on the way *down* — that is the only moment it coincides with
/// what the thumb is doing; played on release it lands after the fact.
public struct ChunkyButtonStyle: ButtonStyle {
    var color: Color
    var radius: CGFloat
    var depth: CGFloat
    /// What the finger feels on the way down. `nil` for a silent button.
    var haptic: Haptic?
    /// Whether gold stars are thrown on release.
    var sparks: Bool

    public init(color: Color = Theme.goldSoft,
                radius: CGFloat = Theme.Radius.chip,
                depth: CGFloat = Theme.chunk,
                haptic: Haptic? = .tap,
                sparks: Bool = true) {
        self.color = color
        self.radius = radius
        self.depth = depth
        self.haptic = haptic
        self.sparks = sparks
    }

    public func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonBody(configuration: configuration, color: color,
                         radius: radius, depth: depth,
                         haptic: haptic, sparks: sparks)
    }
}

/// The body is its own view rather than the contents of `makeBody`: it needs a
/// `@State` to hold the live bursts, and a `ButtonStyle` has none.
private struct ChunkyButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    let radius: CGFloat
    let depth: CGFloat
    let haptic: Haptic?
    let sparks: Bool

    /// One entry per live burst. Rapid taps stack instead of cutting each
    /// other — an interrupted effect makes the second tap feel unregistered.
    @State private var bursts: [UUID] = []

    var body: some View {
        let pressed = configuration.isPressed
        let travel = depth - Theme.chunkPressed

        // Both shapes go in `background`, never in a `ZStack` with the label: a
        // RoundedRectangle is greedy and would impose its size instead of
        // receiving it, which blows a tab button up to fill the screen.
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: Theme.stroke)
                    )
            )
            // The stars sit on the face and travel with it: they leave the
            // button, not the spot the button used to occupy.
            .overlay(
                ZStack {
                    ForEach(bursts, id: \.self) { _ in
                        PopRing(color: Theme.gold, radius: radius)
                        StarBurst()
                    }
                }
                .allowsHitTesting(false)
            )
            .offset(y: pressed ? travel : 0)
            .background(
                // The base never moves: it is the ground. It takes the label's
                // size, since `offset` does not change the layout frame.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.shade(color))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: Theme.stroke)
                    )
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
            .animation(.spring(response: 0.16, dampingFraction: 0.7), value: pressed)
            .onChange(of: pressed) { _, isPressed in
                // Down: the only instant the vibration coincides with what the
                // finger is doing. Played on release it arrives after the fact.
                if isPressed { haptic?.play() } else if sparks { fireBurst() }
            }
    }

    private func fireBurst() {
        let id = UUID()
        bursts.append(id)
        // Bursts do not remove themselves: without this sweep a hundred
        // invisible views pile up over a session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            bursts.removeAll { $0 == id }
        }
    }
}

public extension View {
    func chunky(_ color: Color = Theme.goldSoft,
                radius: CGFloat = Theme.Radius.chip,
                depth: CGFloat = Theme.chunk,
                haptic: Haptic? = .tap,
                sparks: Bool = true) -> some View {
        buttonStyle(ChunkyButtonStyle(color: color, radius: radius, depth: depth,
                                      haptic: haptic, sparks: sparks))
    }
}
