import SwiftUI
import WidgetKit

/// How to put the widget on the home screen, in three pictures.
///
/// It used to be one sentence at the bottom of a card ("touch and hold the
/// wallpaper, tap +, …"), which nobody could follow with the app open and the
/// home screen out of sight. Each page is now a little phone that shows where
/// the finger goes, with one short line under it. The model is DoodleNest's
/// guide; the gestures are the ones iOS actually asks for.
struct WidgetGuideView: View {
    let entry: CarouselEntry?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var loc
    @State private var page = 0

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                LofiIcon(.phone, size: 52, interval: 3)
                Text(loc.t("guide.title"))
                    .font(Theme.title(25))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.primaryDeep)
                        .frame(width: 40, height: 40)
                }
                .chunky(Theme.surface, radius: 20, depth: 3)
                .accessibilityIdentifier("sheet.close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            TabView(selection: $page) {
                ForEach(0..<pageCount, id: \.self) { step in
                    VStack(spacing: 16) {
                        GuidePhone(step: step, entry: entry)
                            .frame(maxHeight: .infinity)

                        HStack(alignment: .top, spacing: 12) {
                            Text(String(step + 1))
                                .font(Theme.rounded(17, .black).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Theme.primary))
                            Text(loc.t("guide.step\(step + 1)"))
                                .font(Theme.rounded(17, .heavy))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)
                        // Three lines reserved: the phone above must not jump
                        // from one page to the next.
                        .frame(minHeight: 70, alignment: .top)
                    }
                    .padding(.top, 12)
                    .tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.primary : Theme.sand)
                        .frame(width: index == page ? 26 : 10, height: 10)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.35), value: page)
            .padding(.vertical, 14)
            .accessibilityHidden(true)

            Button {
                if page < pageCount - 1 {
                    withAnimation(Theme.spring) { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(loc.t(page < pageCount - 1 ? "drill.next" : "guide.done"))
            }
            .buttonStyle(.cta(.primary, height: 58))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityIdentifier("guide.primary")
        }
        .background(Theme.paper.ignoresSafeArea())
        .task {
            if let start = LaunchOptions.guidePage, (0..<pageCount).contains(start) { page = start }
        }
    }
}

// MARK: - The little phone

/// A drawn iPhone for one step of the guide. From step two on the icons jiggle
/// as they do in edit mode, and the thing to touch pulses.
private struct GuidePhone: View {
    let step: Int
    let entry: CarouselEntry?
    @Environment(\.loc) private var loc
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.5 : (sin(t * 4) + 1) / 2
            GeometryReader { geo in
                let height = geo.size.height
                let width = min(geo.size.width * 0.66, height * 0.5)
                ZStack {
                    RoundedRectangle(cornerRadius: width * 0.17, style: .continuous)
                        .fill(Theme.ink)
                    screen(t: t, pulse: pulse, width: width * 0.925, height: height - width * 0.075)
                        .clipShape(RoundedRectangle(cornerRadius: width * 0.14, style: .continuous))
                }
                .frame(width: width, height: height)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        // The phone is a picture of iOS, not of this app: never mirrored.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func screen(t: Double, pulse: Double, width: CGFloat, height: CGFloat) -> some View {
        let gap = width * 0.07
        let side = (width * 0.84 - gap * 3) / 4
        return ZStack(alignment: .top) {
            HomeWallpaper()

            VStack(spacing: gap * 1.1) {
                ForEach(0..<4, id: \.self) { row in
                    HomeIconRow(side: side, gap: gap, row: row, jiggle: step >= 1 ? t : nil)
                }
            }
            .padding(.top, height * 0.13)

            switch step {
            case 0:  hold(pulse: pulse, width: width, height: height)
            case 1:  editMenu(pulse: pulse, width: width, height: height)
            default: gallery(pulse: pulse, width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }

    private func bubble(_ text: String, size: CGFloat, color: Color = Theme.ink) -> some View {
        Text(text)
            .font(Theme.rounded(size, .black))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// Step 1: a finger held on an empty spot.
    private func hold(pulse: Double, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.85 - pulse * 0.6), lineWidth: 3)
                .frame(width: width * (0.22 + pulse * 0.18))
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: width * 0.16)
            bubble(loc.t("guide.hold"), size: width * 0.062)
                .padding(.horizontal, width * 0.05)
                .padding(.vertical, width * 0.025)
                .background(.white, in: Capsule())
                .frame(maxWidth: width * 0.8)
                .offset(y: width * 0.22)
        }
        .position(x: width * 0.5, y: height * 0.78)
    }

    /// Step 2: "Edit" in the top corner, then "Add Widget" in its menu.
    private func editMenu(pulse: Double, width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: width * 0.03) {
            bubble(loc.t("guide.edit"), size: width * 0.058)
                .padding(.horizontal, width * 0.05)
                .padding(.vertical, width * 0.025)
                .background(.white.opacity(0.92), in: Capsule())

            HStack(spacing: width * 0.03) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: width * 0.06, weight: .bold))
                    .foregroundStyle(Theme.primaryDeep)
                bubble(loc.t("guide.addWidget"), size: width * 0.058)
            }
            .padding(.horizontal, width * 0.055)
            .padding(.vertical, width * 0.045)
            .background(.white, in: RoundedRectangle(cornerRadius: width * 0.06, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
                    .stroke(Theme.gold, lineWidth: 2 + pulse * 3)
            )
            .frame(maxWidth: width * 0.86, alignment: .leading)
        }
        .padding(.top, height * 0.035)
        .padding(.leading, width * 0.06)
        .frame(width: width, height: height, alignment: .topLeading)
    }

    /// Step 3: the widget gallery, searched for the app's name, with the real
    /// widget in it and the add button under it.
    private func gallery(pulse: Double, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: width * 0.045) {
            Capsule().fill(Theme.border).frame(width: width * 0.16, height: 4)
                .padding(.top, width * 0.04)

            HStack(spacing: width * 0.03) {
                Image(systemName: "magnifyingglass")
                Text(verbatim: "Salat")
                Spacer(minLength: 0)
            }
            .font(Theme.rounded(width * 0.058, .heavy))
            .foregroundStyle(Theme.inkSoft)
            .padding(width * 0.04)
            .background(Theme.sand, in: RoundedRectangle(cornerRadius: width * 0.05, style: .continuous))

            if let entry {
                WidgetSnapshot(entry: entry, family: .systemSmall, width: width * 0.5)
            } else {
                RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
                    .fill(Theme.primary)
                    .frame(width: width * 0.5, height: width * 0.5)
            }

            HStack(spacing: width * 0.02) {
                Image(systemName: "plus")
                    .font(.system(size: width * 0.055, weight: .black))
                bubble(loc.t("guide.addWidget"), size: width * 0.058, color: .white)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, width * 0.07)
            .padding(.vertical, width * 0.04)
            .background(Theme.primary, in: Capsule())
            .scaleEffect(1 + pulse * 0.07)
            .frame(maxWidth: width * 0.9)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, width * 0.06)
        .frame(width: width, height: height * 0.7)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: width * 0.1,
                                                       topTrailingRadius: width * 0.1,
                                                       style: .continuous))
        .frame(width: width, height: height, alignment: .bottom)
    }
}
