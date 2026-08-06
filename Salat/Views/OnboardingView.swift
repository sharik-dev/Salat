import SwiftUI

struct OnboardingStep: Identifiable {
    let id = UUID()
    let titleKey: String
    let bodyKey: String
    let icon: String
    /// Name of the illustration to show, or nil for the SF Symbol in `icon`.
    let image: String?
}

struct OnboardingView: View {
    @Environment(OnboardingManager.self) private var onboarding
    @Environment(\.loc) private var loc
    @State private var index = 0

    /// The real illustrations, not the drawn fallback — this is the first
    /// thing anyone sees, and it walks through the prayer in order: standing,
    /// bowing, prostrating, sitting.
    private let steps: [OnboardingStep] = [
        .init(titleKey: "onboarding.1.title", bodyKey: "onboarding.1.body", icon: "book.closed.fill", image: "pos_qiyam"),
        .init(titleKey: "onboarding.2.title", bodyKey: "onboarding.2.body", icon: "list.number", image: "pos_takbir"),
        .init(titleKey: "onboarding.3.title", bodyKey: "onboarding.3.body", icon: "arrow.triangle.2.circlepath", image: "pos_ruku"),
        .init(titleKey: "onboarding.4.title", bodyKey: "onboarding.4.body", icon: "square.grid.2x2", image: "pos_sujud"),
        .init(titleKey: "onboarding.5.title", bodyKey: "onboarding.5.body", icon: "checkmark.seal.fill", image: "pos_tashahhud")
    ]

    private var isLast: Bool { index == steps.count - 1 }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            StarLattice(spacing: 74, opacity: 0.07).ignoresSafeArea()

            if isLast { GoldDust().ignoresSafeArea() }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLast {
                        Button(loc.t("onboarding.skip")) { finish() }
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.inkSoft)
                            .accessibilityIdentifier("onboarding.skip")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .frame(height: 40)

                TabView(selection: $index) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        page(step).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                dots.padding(.bottom, 22)

                Button {
                    if isLast { finish() } else { withAnimation(Theme.spring) { index += 1 } }
                } label: {
                    Text(isLast ? loc.t("onboarding.start") : loc.t("onboarding.next"))
                        .font(Theme.label(15))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .chunky(Theme.gold, radius: 18, haptic: isLast ? .win : .press)
                .padding(.horizontal, 26)
                .padding(.bottom, 26)
                .accessibilityIdentifier("onboarding.primary")
            }
        }
    }

    private func page(_ step: OnboardingStep) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            ZStack {
                Circle().fill(Theme.sand)
                Circle().strokeBorder(Theme.goldSoft, lineWidth: 1.5)
                StarLattice(spacing: 74, opacity: 0.10).clipShape(Circle())

                if let name = step.image, let illustration = PositionAsset.image(named: name) {
                    Image(uiImage: illustration)
                        .resizable()
                        .scaledToFit()
                        .padding(26)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(Theme.gold)
                }
            }
            .frame(width: 200, height: 200)

            VStack(spacing: 12) {
                Text(loc.t(step.titleKey))
                    .font(Theme.title(27))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(loc.t(step.bodyKey))
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 0)
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.gold : Theme.border)
                    .frame(width: i == index ? 20 : 7, height: 7)
                    .animation(Theme.spring, value: index)
            }
        }
    }

    private func finish() { onboarding.markSeen() }
}

/// The celebration on the last page: the same eight-pointed stars the buttons
/// throw, drifting down instead of being flung. Confetti would break the tone;
/// this is the page's own motif, falling.
private struct GoldDust: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<44 {
                    let seed = Double(i)
                    let x = (sin(seed * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let speed = 12 + (seed.truncatingRemainder(dividingBy: 7)) * 5
                    let y = ((t * speed + seed * 37).truncatingRemainder(dividingBy: size.height + 60)) - 30
                    let drift = sin(t * 0.6 + seed) * 12
                    let r = 3 + (seed.truncatingRemainder(dividingBy: 3)) * 2
                    let rect = CGRect(x: abs(x) * size.width + drift - r, y: y - r,
                                      width: r * 2, height: r * 2)
                    context.fill(EightPointStar().path(in: rect),
                                 with: .color(Theme.gold.opacity(0.32)))
                }
            }
        }
        .opacity(reduceMotion ? 0 : 1)
        .allowsHitTesting(false)
    }
}
