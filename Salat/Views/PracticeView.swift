import SwiftUI

/// The in-app twin of the widget: the same carousel, running while you watch.
/// Nothing to tap — that is the point. Passive exposure, on loop.
struct PracticeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    @State private var index = 0
    @State private var isPlaying = true
    @State private var elapsed: Double = 0

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 14) {
            header

            TabView(selection: $index) {
                ForEach(Array(settings.steps.enumerated()), id: \.offset) { i, step in
                    CarouselCard(step: step).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(Theme.softSpring, value: index)

            controls
            Color.clear.frame(height: 74)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .onReceive(tick) { _ in advanceIfNeeded() }
        .onChange(of: index) { _, _ in elapsed = 0 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc.t("practice.title"))
                .font(Theme.title(26))
                .foregroundStyle(Theme.ink)
            Text(loc.t("practice.hint"))
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        @Bindable var settings = settings

        return VStack(spacing: 12) {
            // Progress of the current step, so the loop never feels stalled.
            ProgressBar(value: elapsed, total: settings.stepSeconds)
                .frame(height: 8)

            HStack(spacing: 18) {
                circleButton("backward.fill") { step(-1) }

                Button {
                    withAnimation(Theme.spring) { isPlaying.toggle() }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 58, height: 54)
                }
                .chunky(Theme.gold, radius: 18, depth: 6, haptic: .press)
                .accessibilityIdentifier("practice.playpause")

                circleButton("forward.fill") { step(1) }
            }

            HStack(spacing: 10) {
                Text(loc.t("practice.speed"))
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.inkSoft)
                Slider(value: $settings.stepSeconds, in: 3...20, step: 1)
                    .tint(Theme.gold)
                Text("\(Int(settings.stepSeconds))s")
                    .font(Theme.pixel(11))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 46, height: 42)
        }
        .chunky(Theme.sand, radius: 14, depth: 4, haptic: .select)
    }

    private func step(_ delta: Int) {
        guard !settings.steps.isEmpty else { return }
        withAnimation(Theme.softSpring) {
            index = (index + delta + settings.steps.count) % settings.steps.count
        }
    }

    private func advanceIfNeeded() {
        guard isPlaying, !settings.steps.isEmpty else { return }
        elapsed += 0.1
        if elapsed >= settings.stepSeconds {
            elapsed = 0
            step(1)
        }
    }
}

// MARK: - Card

private struct CarouselCard: View {
    let step: PrayerStep
    @Environment(\.loc) private var loc

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content
                    // Short steps sit centred; long ones (the Fatiha) simply
                    // overflow and scroll.
                    .frame(minHeight: geo.size.height, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
        .card()
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    private var content: some View {
            VStack(spacing: 14) {
                PositionMedallion(step: step, size: 132)
                    .padding(.top, 18)

                Text(step.name)
                    .font(Theme.title(21))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                if step.spoken {
                    Text(step.arabic)
                        .font(Theme.arabic(23))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .environment(\.layoutDirection, .rightToLeft)
                        .lineSpacing(6)

                    Text(step.phonetic)
                        .font(Theme.body(15).italic())
                        .foregroundStyle(Theme.gold)
                        .multilineTextAlignment(.center)

                    Divider().background(Theme.border).padding(.horizontal, 40)
                }

                Text(step.translation)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)

                Color.clear.frame(height: 12)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
    }
}
