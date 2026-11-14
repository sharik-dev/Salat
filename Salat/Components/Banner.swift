import SwiftUI

/// The green banner at the top of every tab: rounded bottom corners, the same
/// height everywhere, a 3D object on the right that says which room you are in.
///
/// It replaces the stack of title, subtitle, bar and button each screen used to
/// open with. One title, one optional pill (which can be a button), one object.
struct Banner<Trailing: View>: View {
    let title: String
    var subtitle: String?
    /// Makes the pill a button — the progress page hangs off the *Learn* pill.
    var subtitleAction: (() -> Void)?
    var subtitleID: String?
    var back: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    static var contentHeight: CGFloat { 96 }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let back { BannerBackButton(action: back) }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(Theme.title(27))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle { pill(subtitle) }
            }

            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: Self.contentHeight)
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 20)
        .background {
            BannerBackdrop()
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34,
                                                  style: .continuous))
                .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private func pill(_ text: String) -> some View {
        let label = HStack(spacing: 5) {
            Text(text)
                .font(Theme.rounded(14, .black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if subtitleAction != nil {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 10, weight: .black))
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.white, in: Capsule())

        if let subtitleAction {
            Button(action: subtitleAction) {
                label
                    .background(Capsule().fill(Theme.primaryDeep).offset(y: 3))
                    .padding(.bottom, 3)
                    .frame(minHeight: 36, alignment: .top)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PillPressStyle())
            .accessibilityIdentifier(subtitleID ?? "banner.pill")
        } else {
            label
        }
    }
}

extension Banner where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, back: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, subtitleAction: nil, subtitleID: nil,
                  back: back) { EmptyView() }
    }
}

/// The pill only dips: a full chunky face would be too much for a caption.
private struct PillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, down in if down { Haptic.tap.play() } }
    }
}

/// Round white "back" button set in a banner.
struct BannerBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.primary)
                .frame(width: 46, height: 46)
                .background(.white, in: Circle())
                .background(Circle().fill(Theme.primaryDeep).offset(y: 3))
                .padding(.bottom, 3)
        }
        .buttonStyle(PillPressStyle())
        .accessibilityIdentifier("banner.back")
    }
}

/// The green of the banner with its decor: the house lattice in white, two
/// soft halos, and a few gold sparks that twinkle out of step.
struct BannerBackdrop: View {
    var body: some View {
        ZStack {
            Theme.primary
            StarLattice(spacing: 60, opacity: 0.14, color: .white)
            GeometryReader { geo in
                Circle().fill(.white.opacity(0.08))
                    .frame(width: 230, height: 230)
                    .position(x: geo.size.width * 0.08, y: geo.size.height * 1.02)
                Circle().fill(.white.opacity(0.07))
                    .frame(width: 170, height: 170)
                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.05)
            }
            Twinkles()
        }
        .accessibilityHidden(true)
    }
}

/// A few 3D sparks breathing at their own pace. Twelve frames a second is
/// plenty for a twinkle, and it stops entirely under Reduce Motion.
struct Twinkles: View {
    /// (x, y) as fractions of the frame, size, speed, phase.
    var spots: [(CGFloat, CGFloat, CGFloat, Double, Double)] = [
        (0.56, 0.30, 16, 1.7, 0.0), (0.46, 0.82, 11, 2.3, 1.4), (0.93, 0.74, 13, 1.9, 2.6), (0.30, 0.16, 9, 2.6, 3.9),
    ]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ForEach(Array(spots.enumerated()), id: \.offset) { _, s in
                    let k = 0.55 + 0.45 * abs(sin(t * s.3 / 2 + s.4))
                    Icon3D.sparkle.image(width: s.2)
                        .scaleEffect(k)
                        .opacity(0.35 + 0.65 * k)
                        .position(x: s.0 * geo.size.width, y: s.1 * geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Small uppercase caption above a group of cards.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.rounded(12.5, .black))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

/// Thin separator between two rows of the same card.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 2)
    }
}
