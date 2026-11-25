import SwiftUI

/// One screen of the Qur'an feed, in small: a photograph under the dark
/// filter, the verse in white in the middle, its meaning under it, and the
/// column of actions on the right. The welcome and the paywall show the
/// Qur'an tab with it, so what they promise is what the tab looks like.
///
/// It does not open the Qur'an files (fifteen megabytes): the verses it
/// carries are lines of al-Fatiha from the prayer content, already loaded and
/// already translated into the reader's language.
struct QuranFeedCard: View {
    let arabic: String
    let translation: String?
    /// Which of the shipped `quranbg_*.jpg` to put behind it.
    var picture: Int = 0
    var liked = false
    /// Scales the type and the controls: 1 is a phone-sized card.
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 14 * scale) {
                Text(arabic)
                    .font(Theme.arabic(30 * scale))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .lineLimit(3)
                    .minimumScaleFactor(0.55)
                if let translation, !translation.isEmpty {
                    Text(translation)
                        .font(Theme.rounded(15 * scale, .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.vertical, 18 * scale)
            .padding(.horizontal, 16 * scale)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 20 * scale, style: .continuous))
            .padding(.leading, 18 * scale)
            .padding(.trailing, 58 * scale)

            actions
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 10 * scale)
                .padding(.bottom, 26 * scale)
        }
        .clipped()
        .accessibilityElement(children: .combine)
    }

    private var backdrop: some View {
        ZStack {
            if let image = Self.image(picture) {
                Color.black.overlay {
                    Image(uiImage: image).resizable().scaledToFill().saturation(0.82)
                }
                .clipped()
            } else {
                LinearGradient(colors: [Color(hex: 0x248657), Color(hex: 0x0F412B)],
                               startPoint: .top, endPoint: .bottom)
                StarLattice(spacing: 70, opacity: 0.07, color: .white)
            }
            Color.black.opacity(0.42)
        }
    }

    private var actions: some View {
        VStack(spacing: 14 * scale) {
            circle(liked ? "heart.fill" : "heart", tint: liked ? Color(hex: 0xFF4D6A) : .white)
                .scaleEffect(liked ? 1.12 : 1)
            circle("text.bubble.fill", tint: .white)
            circle("square.and.arrow.up", tint: .white)
        }
    }

    private func circle(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17 * scale, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 40 * scale, height: 40 * scale)
            .background(.white.opacity(0.16), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .contentTransition(.symbolEffect(.replace))
    }

    private static let cache = NSCache<NSNumber, UIImage>()

    static func image(_ index: Int) -> UIImage? {
        let urls = QuranBackground.urls
        guard !urls.isEmpty else { return nil }
        let i = ((index % urls.count) + urls.count) % urls.count
        if let cached = cache.object(forKey: NSNumber(value: i)) { return cached }
        guard let image = UIImage(contentsOfFile: urls[i].path) else { return nil }
        cache.setObject(image, forKey: NSNumber(value: i))
        return image
    }
}

extension AppSettings {
    /// Lines of al-Fatiha as (arabic, translation) pairs, for the cards that
    /// show the Qur'an feed outside the Qur'an tab.
    var feedSampleLines: [(String, String)] {
        guard let step = step("fatiha") else {
            return [("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", "")]
        }
        return zip(step.arabicLines, step.translationLines).map { ($0, $1) }
    }
}
