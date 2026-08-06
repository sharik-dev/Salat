import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// What the hand gets back: a vibration the instant the button sinks, a click
/// in the ear, and a spray of gold stars when it comes back up. Ported from
/// **5min**, where the rule is that the three tell the same gesture — without
/// the haptic the press is only an animation, without the burst the tap has no
/// consequence.

// MARK: - Haptics

/// Four sensations, one per role. **Do not reach in here to decorate**: an app
/// that buzzes at every graze ends up with vibration switched off in Settings,
/// and then the ones that matter are lost too.
public enum Haptic {
    /// A graze: closing, going back, changing tab.
    case tap
    /// A press: play, mark as learned, finishing the onboarding.
    case press
    /// Stepping through a series: picking a language, a speed.
    case select
    /// A step has been learned. The only fanfare.
    case win

    #if canImport(UIKit)
    // The generators are kept alive: making one per press gives the Taptic
    // engine time to go to sleep between two buttons, and the first vibration
    // of a run then arrives late.
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notice = UINotificationFeedbackGenerator()
    #endif

    /// The vibration and the sound leave together: they are two faces of the
    /// same feedback, and separating them would eventually leave a button that
    /// buzzes without sounding.
    public func play() {
        #if canImport(UIKit)
        switch self {
        case .tap:    Self.light.impactOccurred(intensity: 0.7); Self.light.prepare(); Sound.shared.click()
        case .press:  Self.soft.impactOccurred();                Self.soft.prepare();  Sound.shared.click()
        case .select: Self.selection.selectionChanged();         Self.selection.prepare(); Sound.shared.nav()
        case .win:    Self.notice.notificationOccurred(.success); Sound.shared.nav()
        }
        #endif
    }

    /// Wakes the engine at launch. A cold generator takes a hundred
    /// milliseconds to answer — long enough for the vibration to land *after*
    /// the button has sunk, which breaks the very link it is meant to create.
    public static func warmUp() {
        #if canImport(UIKit)
        light.prepare(); soft.prepare(); selection.prepare()
        #endif
        Sound.shared.warmUp()
    }
}

// MARK: - Sound

/// Two sounds, no more: the key click for a button that sinks, the blip for a
/// change of screen.
///
/// Category `ambient`: the iPhone's silent switch mutes the app, and the
/// user's own music keeps playing over it. An app that cuts someone's Qur'an
/// recitation to play a click gets closed.
public final class Sound {
    public static let shared = Sound()

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private var players: [String: [AVAudioPlayer]] = [:]

    /// An interface sound plays *under* everything else; at full volume it
    /// reads as an alert.
    private static let bank: [String: Float] = ["ui-click": 0.34, "ui-nav": 0.30]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    public func click() { play("ui-click") }
    public func nav()   { play("ui-nav") }

    private func play(_ name: String) {
        guard enabled else { return }
        // Two players per sound, taken in turn: two quick taps overlap instead
        // of the second cutting the first.
        var pool = players[name] ?? []
        if pool.isEmpty {
            let bundle = Bundle(for: SoundBundleToken.self)
            guard let url = bundle.url(forResource: name, withExtension: "mp3"),
                  let data = try? Data(contentsOf: url) else { return }
            pool = (0..<2).compactMap { _ in
                let player = try? AVAudioPlayer(data: data)
                player?.volume = Self.bank[name] ?? 0.34
                player?.prepareToPlay()
                return player
            }
            guard !pool.isEmpty else { return }
            players[name] = pool
        }
        let free = pool.first { !$0.isPlaying } ?? pool[0]
        free.currentTime = 0
        free.play()
    }

    /// Decodes both sounds one run-loop turn later, so the first click of the
    /// session is on time without delaying the first screen.
    public func warmUp() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let wasEnabled = self.enabled
            guard wasEnabled else { return }
            for name in Self.bank.keys where self.players[name] == nil {
                let bundle = Bundle(for: SoundBundleToken.self)
                guard let url = bundle.url(forResource: name, withExtension: "mp3"),
                      let data = try? Data(contentsOf: url) else { continue }
                self.players[name] = (0..<2).compactMap { _ in
                    let player = try? AVAudioPlayer(data: data)
                    player?.volume = Self.bank[name] ?? 0.34
                    player?.prepareToPlay()
                    return player
                }
            }
        }
    }
}

private final class SoundBundleToken {}

// MARK: - The spark burst

/// A spray of small **four-pointed sparkles** thrown out of the button,
/// falling and fading.
///
/// Four thin rays tapering to a point, cut in the page's own cream and closed
/// by a beige outline. Flat gold chips read as confetti on cream, and a glowing
/// orange one reads as a stray effect from another app; an outlined cream shape
/// reads as a piece of the page that came loose.
///
/// Deliberately **not** the eight-pointed khatam: that motif belongs to the
/// page (the background lattice, the onboarding), where it is drawn large and
/// still. At 10 pt, thrown and spinning, its eight points blur into a blob.
public struct StarBurst: View {
    public var face: Color = Theme.sparkFace
    public var edge: Color = Theme.sparkEdge
    public var count: Int = 10
    /// Far enough to **leave the face**: a spray that stays on the button
    /// reads as a shimmer, not as something thrown.
    public var spread: ClosedRange<CGFloat> = 30...70

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bits: [Bit] = []
    @State private var t: CGFloat = 0

    public init(face: Color = Theme.sparkFace, edge: Color = Theme.sparkEdge,
                count: Int = 10, spread: ClosedRange<CGFloat> = 30...70) {
        self.face = face
        self.edge = edge
        self.count = count
        self.spread = spread
    }

    fileprivate struct Bit: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let side: CGFloat
        let spin: Double
    }

    public var body: some View {
        ZStack {
            ForEach(bits) { bit in
                let radians = bit.angle * .pi / 180
                Spark(face: face, edge: edge)
                    .frame(width: bit.side, height: bit.side)
                    .rotationEffect(.degrees(bit.spin * Double(t)))
                    // A spark burns out: it shrinks to its point as it fades,
                    // instead of staying full size and simply going
                    // transparent.
                    .scaleEffect(1 - 0.45 * t)
                    .offset(
                        x: cos(radians) * bit.distance * t,
                        // Gravity: the t² term makes them fall instead of
                        // flying out in a perfect star. Without it the spray
                        // reads as a pictogram, not as thrown matter.
                        y: sin(radians) * bit.distance * t + 30 * t * t
                    )
                    .opacity(Double(1 - t))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // Reduce Motion: the vibration and the sinking already say the tap
            // was taken. Nothing is thrown.
            guard !reduceMotion else { return }
            bits = (0..<count).map { i in
                // A regular base plus a wobble: a purely random spray clumps
                // and leaves holes.
                let base = Double(i) / Double(count) * 360
                return Bit(angle: base + .random(in: -18...18),
                           distance: .random(in: spread),
                           // Bigger than the old chips: most of a sparkle is
                           // thin ray and halo, so a 8 pt one is invisible.
                           side: .random(in: 12...22),
                           // Barely turning. A four-pointed star that spins
                           // fast stops reading as light and starts reading
                           // as a rotating pictogram.
                           spin: .random(in: -70...70))
            }
            withAnimation(.easeOut(duration: 0.5)) { t = 1 }
        }
    }
}

/// One sparkle: a cream face with a beige outline. The same two-part
/// construction as every other object in the app — a filled shape and the
/// line that closes it — only very small.
///
/// The outline is what does the work: cream on cream is invisible, so the
/// spark is legible by its edge, exactly like the plates and the tab bar.
/// The stroke width is **fixed**, not scaled with the spark: a line that
/// thickens with the shape turns a 22 pt spark into a ring.
public struct Spark: View {
    public var face: Color
    public var edge: Color
    public var lineWidth: CGFloat

    public init(face: Color = Theme.sparkFace,
                edge: Color = Theme.sparkEdge,
                lineWidth: CGFloat = 1.3) {
        self.face = face
        self.edge = edge
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            FourPointStar().fill(face)
            FourPointStar().stroke(edge, lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }
}

/// A four-pointed sparkle: four tips joined by curves that pinch in towards
/// the centre, so each ray tapers to a needle instead of being a triangle.
/// `waist` is how far the curve's control point sits from the centre — small
/// waist, thin rays.
public struct FourPointStar: Shape {
    public var waist: CGFloat

    public init(waist: CGFloat = 0.085) {
        self.waist = waist
    }

    public func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        let wx = rx * waist, wy = ry * waist
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - ry))
        path.addQuadCurve(to: CGPoint(x: c.x + rx, y: c.y),
                          control: CGPoint(x: c.x + wx, y: c.y - wy))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + ry),
                          control: CGPoint(x: c.x + wx, y: c.y + wy))
        path.addQuadCurve(to: CGPoint(x: c.x - rx, y: c.y),
                          control: CGPoint(x: c.x - wx, y: c.y + wy))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - ry),
                          control: CGPoint(x: c.x - wx, y: c.y - wy))
        path.closeSubpath()
        return path
    }
}

/// The khatam: two squares at 45° to each other. The same figure the page's
/// background lattice is drawn from, filled here instead of stroked. Still
/// used by the page itself (background lattice, onboarding) — only the burst
/// stopped using it.
public struct EightPointStar: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for rotation in [0.0, Double.pi / 4] {
            var first = true
            for corner in 0..<4 {
                let a = rotation + Double(corner) * .pi / 2
                let p = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
                if first { path.move(to: p); first = false } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
        return path
    }
}

/// The shockwave: the button's own outline, growing a hair and fading. It is
/// what gives the release weight — the finger leaves, something stays for a
/// fraction of a second.
public struct PopRing: View {
    public var color: Color
    public var radius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: CGFloat = 0

    public init(color: Color, radius: CGFloat) {
        self.color = color
        self.radius = radius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(color, lineWidth: 2.5)
            .scaleEffect(1 + 0.13 * t)
            .opacity(reduceMotion ? 0 : Double(0.5 * (1 - t)))
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.32)) { t = 1 }
            }
    }
}
