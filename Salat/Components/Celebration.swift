import SwiftUI

/// The one big moment: a step has been acquired. The screen dims, a 3D object
/// drops in the middle of a spray of sparks, with the fanfare haptic. A tap
/// anywhere skips it; otherwise it puts itself away.
///
/// Ported from SelfTransfer's `Celebration`. It is an overlay you hang on the
/// screen that earned it (the step sheet), not a global layer: the sheet is
/// what is on top at that moment, and a root overlay would play underneath it.
struct CelebrationView: View {
    var icon: Icon3D = .check
    let title: String
    var caption: String?
    var duration: Double = 1.9
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var shown = false
    @State private var sparks: [Spark] = (0..<16).map { _ in Spark() }

    struct Spark {
        let angle = Double.random(in: 0..<(2 * .pi))
        let distance = CGFloat.random(in: 110...190)
        let size = CGFloat.random(in: 12...26)
        let delay = Double.random(in: 0...0.15)
        let spin = Double.random(in: -90...90)
    }

    var body: some View {
        ZStack {
            // Deep green, not black: the dim is the page's own colour, turned down.
            Color(hex: 0x0E2A1C).opacity(shown ? 0.97 : 0)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    if !reduceMotion {
                        TimelineView(.animation) { context in
                            let t = context.date.timeIntervalSince(start) - 0.25
                            ring(t)
                            ForEach(Array(sparks.enumerated()), id: \.offset) { _, s in spark(s, t: t) }
                        }
                    }
                    Circle()
                        .fill(RadialGradient(colors: [Theme.primary.opacity(0.6), .clear],
                                             center: .center, startRadius: 10, endRadius: 150))
                        .frame(width: 300, height: 300)
                        .scaleEffect(shown ? 1 : 0.3)
                        .opacity(shown ? 1 : 0)
                    LofiIcon(icon, size: 180, interval: 1.2)
                        .scaleEffect(shown ? 1 : 0.2)
                        .rotationEffect(.degrees(shown ? 0 : -35))
                        .offset(y: shown ? 0 : -260)
                }
                .frame(height: 240)

                VStack(spacing: 12) {
                    Text(title)
                        .font(Theme.title(32))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caption {
                        Text(caption)
                            .font(Theme.rounded(17, .heavy))
                            .foregroundStyle(Theme.primaryDeep)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(.white, in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 30)
                .animation(.spring(duration: 0.5, bounce: 0.3).delay(0.25), value: shown)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { close() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { close() }
        .task {
            start = .now
            withAnimation(.spring(duration: 0.6, bounce: 0.45)) { shown = true }
            try? await Task.sleep(for: .seconds(0.25))
            Haptic.win.play()
            try? await Task.sleep(for: .seconds(duration))
            close()
        }
    }

    /// A white ripple that widens as the object lands.
    private func ring(_ t: Double) -> some View {
        let k = min(max(t / 0.7, 0), 1)
        return Circle()
            .stroke(.white.opacity(0.7 * (1 - k)), lineWidth: 6 * (1 - k) + 1)
            .frame(width: 80 + 300 * k, height: 80 + 300 * k)
    }

    /// A 3D spark thrown from the centre, then burning out.
    private func spark(_ s: Spark, t: Double) -> some View {
        let k = min(max((t - s.delay) / 0.9, 0), 1)
        let ease = 1 - pow(1 - k, 3)
        return Icon3D.sparkle.image(width: s.size * 2)
            .rotationEffect(.degrees(s.spin * k))
            .scaleEffect(k < 0.15 ? k / 0.15 : 1 - (k - 0.15) * 0.6)
            .opacity(k <= 0 ? 0 : 1 - pow(k, 3))
            .offset(x: cos(s.angle) * s.distance * ease, y: sin(s.angle) * s.distance * ease)
    }
}
