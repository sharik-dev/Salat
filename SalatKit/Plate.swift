import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The form language, borrowed from **SelfTransfer**: a rounded rectangle with
/// a thick *pastel* outline for anything you read (a card), and a slab sitting
/// on a darker edge for anything you press (a button). No blur, no drop shadow.
///
/// The outline is never ink. On white and beige a dark rule draws boxes; a
/// pastel one draws objects, and that is most of what makes the app friendly.

public extension Theme {
    /// Outline weight of cards and buttons.
    static let stroke: CGFloat = 2.5

    /// How far a button's face travels down onto its edge.
    static let chunk: CGFloat = 5
    static let chunkPressed: CGFloat = 0

    /// The same hue, darkened: the edge of a button of an arbitrary colour.
    static func shade(_ color: Color, _ amount: CGFloat = 0.2) -> Color {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(s * 1.15, 1), brightness: b * (1 - amount), opacity: a)
        #else
        return color.opacity(0.7)
        #endif
    }

    /// The outline (and, for a button, the edge) that goes with a face colour.
    /// The house colours get a hand-picked partner; anything else is darkened.
    static func edge(for color: Color) -> Color {
        switch color {
        case Theme.surface, Theme.paper: return Theme.border
        case Theme.sand:                 return Color(hex: 0xDFD0AC)
        case Theme.primary, Theme.green: return Theme.primaryDeep
        case Theme.primarySoft, Theme.greenSoft: return Theme.primaryBorder
        case Theme.gold:                 return Theme.goldDeep
        case Theme.goldSoft:             return Color(hex: 0xEFD286)
        case Theme.danger:               return Color(hex: 0xC2402F)
        default:                         return shade(color)
        }
    }
}

// MARK: - The plate (a card)

/// A flat face and a pastel outline. `depth` adds a solid edge underneath for
/// the rare card that should read as an object you could pick up.
public struct Plate<Content: View>: View {
    var color: Color
    var radius: CGFloat
    var depth: CGFloat
    var border: CGFloat
    var stroke: Color?
    @ViewBuilder var content: () -> Content

    public init(color: Color = Theme.surface,
                radius: CGFloat = Theme.Radius.card,
                depth: CGFloat = 0,
                border: CGFloat = Theme.stroke,
                stroke: Color? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self.color = color
        self.radius = radius
        self.depth = depth
        self.border = border
        self.stroke = stroke
        self.content = content
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let edge = stroke ?? Theme.edge(for: color)
        content()
            .background(
                ZStack {
                    if depth > 0 { shape.fill(edge).offset(y: depth) }
                    shape.fill(color)
                    shape.strokeBorder(edge, lineWidth: border)
                }
            )
            .padding(.bottom, depth)
    }
}

public extension View {
    /// Sets any view down on a plate.
    func plate(_ color: Color = Theme.surface,
               radius: CGFloat = Theme.Radius.card,
               depth: CGFloat = 0,
               border: CGFloat = Theme.stroke,
               stroke: Color? = nil) -> some View {
        Plate(color: color, radius: radius, depth: depth, border: border, stroke: stroke) { self }
    }
}

// MARK: - The button that sinks

/// A slab on its edge, the way Duolingo does it: on press the face drops in one
/// go until it covers the edge (no bounce, no squash); on release it comes back
/// up on a spring that overshoots a little. A lightning tap stays down for
/// `minDown`, so the press is always seen.
///
/// The haptic fires on the way *down* — that is the only moment it coincides
/// with what the thumb is doing.
struct ChunkyFace<Label: View>: View {
    let isPressed: Bool
    let label: Label
    let color: Color
    var edge: Color?
    let radius: CGFloat
    let depth: CGFloat
    let haptic: Haptic?
    let sparks: Bool

    private let minDown: Double = 0.09

    @State private var down = false
    @State private var downAt = Date.distantPast
    @State private var token = 0
    @State private var bursts: [UUID] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let rim = edge ?? Theme.edge(for: color)

        // Both shapes go in `background`, never in a `ZStack` with the label: a
        // RoundedRectangle is greedy and would impose its size instead of
        // receiving it.
        label
            .background(shape.fill(color))
            .overlay(shape.fill(.black.opacity(down ? 0.05 : 0)).allowsHitTesting(false))
            .overlay(shape.strokeBorder(rim, lineWidth: Theme.stroke).allowsHitTesting(false))
            .overlay(
                ZStack {
                    ForEach(bursts, id: \.self) { _ in
                        PopRing(color: Theme.gold, radius: radius)
                        StarBurst()
                    }
                }
                .allowsHitTesting(false)
            )
            // The face comes down onto the edge, which never moves.
            .offset(y: down ? depth : 0)
            .background(shape.fill(rim).offset(y: depth))
            .padding(.bottom, depth)
            .onChange(of: isPressed) { _, isDown in
                token += 1
                if isDown {
                    downAt = .now
                    haptic?.play()
                    withAnimation(.easeOut(duration: 0.05)) { down = true }
                } else {
                    let mine = token
                    let wait = max(0, minDown - Date.now.timeIntervalSince(downAt))
                    Task { @MainActor in
                        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                        guard mine == token else { return }
                        withAnimation(reduceMotion ? .easeOut(duration: 0.12)
                                                   : .spring(duration: 0.32, bounce: 0.5)) {
                            down = false
                        }
                        if sparks { fireBurst() }
                    }
                }
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

/// The free-form chunky button: the call site brings its own label, padding
/// and colours. Used for chips, rows and anything that is not *the* button of
/// the screen — that one is `.cta()`.
public struct ChunkyButtonStyle: ButtonStyle {
    var color: Color
    var radius: CGFloat
    var depth: CGFloat
    /// What the finger feels on the way down. `nil` for a silent button.
    var haptic: Haptic?
    /// Whether gold sparks are thrown on release. Off by default: sparks are a
    /// reward, and a reward on every tap is wallpaper.
    var sparks: Bool

    public init(color: Color = Theme.sand,
                radius: CGFloat = Theme.Radius.chip,
                depth: CGFloat = Theme.chunk,
                haptic: Haptic? = .tap,
                sparks: Bool = false) {
        self.color = color
        self.radius = radius
        self.depth = depth
        self.haptic = haptic
        self.sparks = sparks
    }

    public func makeBody(configuration: Configuration) -> some View {
        ChunkyFace(isPressed: configuration.isPressed, label: configuration.label,
                   color: color, radius: radius, depth: depth, haptic: haptic, sparks: sparks)
    }
}

public extension View {
    func chunky(_ color: Color = Theme.sand,
                radius: CGFloat = Theme.Radius.chip,
                depth: CGFloat = Theme.chunk,
                haptic: Haptic? = .tap,
                sparks: Bool = false) -> some View {
        buttonStyle(ChunkyButtonStyle(color: color, radius: radius, depth: depth,
                                      haptic: haptic, sparks: sparks))
    }
}

// MARK: - The button of the screen

/// One wide button that owns the bottom of a screen: *Continue*, *Check*,
/// *Start a round*. The style brings the type, the colours and the width, so
/// every main action in the app is the same object.
public struct CTAButtonStyle: ButtonStyle {
    public enum Kind { case primary, secondary, gold, danger }

    var kind: Kind
    var height: CGFloat
    var haptic: Haptic
    var sparks: Bool

    public init(kind: Kind = .primary, height: CGFloat = 58,
                haptic: Haptic = .press, sparks: Bool = false) {
        self.kind = kind
        self.height = height
        self.haptic = haptic
        self.sparks = sparks
    }

    public func makeBody(configuration: Configuration) -> some View {
        CTABody(configuration: configuration, kind: kind, height: height,
                haptic: haptic, sparks: sparks)
    }
}

private struct CTABody: View {
    let configuration: ButtonStyleConfiguration
    let kind: CTAButtonStyle.Kind
    let height: CGFloat
    let haptic: Haptic
    let sparks: Bool
    @Environment(\.isEnabled) private var isEnabled

    private var fill: Color {
        guard isEnabled else { return Theme.sand }
        switch kind {
        case .primary:   return Theme.primary
        case .secondary: return Theme.surface
        case .gold:      return Theme.goldSoft
        case .danger:    return Theme.danger
        }
    }

    private var foreground: Color {
        guard isEnabled else { return Theme.inkSoft.opacity(0.7) }
        switch kind {
        case .primary, .danger: return .white
        case .secondary:        return Theme.primaryDeep
        case .gold:             return Theme.ink
        }
    }

    var body: some View {
        ChunkyFace(
            isPressed: configuration.isPressed,
            label: configuration.label
                .font(Theme.rounded(18, .black))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: height),
            color: fill, radius: min(height / 2.4, 24), depth: isEnabled ? 6 : 3,
            haptic: haptic, sparks: sparks
        )
    }
}

public extension ButtonStyle where Self == CTAButtonStyle {
    static func cta(_ kind: CTAButtonStyle.Kind = .primary, height: CGFloat = 58,
                    haptic: Haptic = .press, sparks: Bool = false) -> CTAButtonStyle {
        CTAButtonStyle(kind: kind, height: height, haptic: haptic, sparks: sparks)
    }
}
