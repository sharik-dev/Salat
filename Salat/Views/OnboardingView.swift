import SwiftUI

struct OnboardingStep: Identifiable {
    let id = UUID()
    let titleKey: String
    let bodyKey: String
    let icon: String
    let posture: Posture?
}

struct OnboardingView: View {
    @Environment(OnboardingManager.self) private var onboarding
    @Environment(\.loc) private var loc
    @State private var index = 0

    private let steps: [OnboardingStep] = [
        .init(titleKey: "onboarding.1.title", bodyKey: "onboarding.1.body", icon: "book.closed.fill", posture: nil),
        .init(titleKey: "onboarding.2.title", bodyKey: "onboarding.2.body", icon: "list.number", posture: .handsRaised),
        .init(titleKey: "onboarding.3.title", bodyKey: "onboarding.3.body", icon: "arrow.triangle.2.circlepath", posture: .bowing),
        .init(titleKey: "onboarding.4.title", bodyKey: "onboarding.4.body", icon: "square.grid.2x2", posture: .prostrating),
        .init(titleKey: "onboarding.5.title", bodyKey: "onboarding.5.body", icon: "checkmark.seal.fill", posture: .sitting)
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
                        .foregroundStyle(Theme.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.ink)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
                .accessibilityIdentifier("onboarding.primary")
            }
        }
    }

    private func page(_ step: OnboardingStep) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            ZStack {
                Circle().fill(Theme.sand).frame(width: 190, height: 190)
                Circle().strokeBorder(Theme.goldSoft, lineWidth: 1.5).frame(width: 190, height: 190)
                if let posture = step.posture {
                    PostureFigure(posture: posture).frame(width: 130, height: 130)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(Theme.gold)
                }
            }

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

/// The celebration on the last page. Confetti would break the tone here, so it
/// is gold dust drifting down — same beat, quieter.
private struct GoldDust: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<60 {
                    let seed = Double(i)
                    let x = (sin(seed * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let speed = 14 + (seed.truncatingRemainder(dividingBy: 7)) * 6
                    let y = ((t * speed + seed * 37).truncatingRemainder(dividingBy: size.height + 40)) - 20
                    let drift = sin(t * 0.6 + seed) * 10
                    let r = 1.2 + (seed.truncatingRemainder(dividingBy: 3)) * 0.7
                    let rect = CGRect(x: abs(x) * size.width + drift, y: y, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(Theme.gold.opacity(0.30)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
