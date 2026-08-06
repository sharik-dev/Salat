import SwiftUI
import UIKit
import ImageIO

/// The praying figure, drawn rather than photographed.
///
/// Two deliberate constraints: the head is a plain form with **no facial
/// features at all**, and the body is a single flat silhouette — nothing that
/// could read as a portrait. It also costs nothing in a widget and stays sharp
/// at 40 pt or 400 pt.
///
/// If an illustration named after `PrayerStep.image` exists in the asset
/// catalogue, `PositionIllustration` uses it instead; this is the guaranteed
/// floor, not a placeholder to be embarrassed about.
public struct PostureFigure: View {
    public let posture: Posture
    public var tint: Color = Theme.ink.opacity(0.82)

    public init(posture: Posture, tint: Color = Theme.ink.opacity(0.82)) {
        self.posture = posture
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 100
            ZStack {
                figure
                    .fill(tint)
                    .scaleEffect(s, anchor: .topLeading)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Everything is expressed in a 100 × 100 box, feet on the ground line y = 92.
    private var figure: Path {
        var p = Path()
        switch posture {
        case .standing:    standing(&p, armsRaised: false)
        case .handsRaised: standing(&p, armsRaised: true)
        case .bowing:      bowing(&p)
        case .prostrating: prostrating(&p)
        case .sitting:     sitting(&p)
        }
        p.addRect(CGRect(x: 8, y: 92.5, width: 84, height: 1.4))   // ground line
        return p
    }

    // MARK: Postures

    private func standing(_ p: inout Path, armsRaised: Bool) {
        p.addEllipse(in: CGRect(x: 41, y: 8, width: 18, height: 19))          // head
        p.addRoundedRect(in: CGRect(x: 46, y: 25, width: 8, height: 6),
                         cornerSize: CGSize(width: 3, height: 3))             // neck

        // Thobe: shoulders narrow, hem wide — the silhouette of the garment.
        var robe = Path()
        robe.move(to: CGPoint(x: 38, y: 31))
        robe.addQuadCurve(to: CGPoint(x: 62, y: 31), control: CGPoint(x: 50, y: 27))
        robe.addLine(to: CGPoint(x: 69, y: 88))
        robe.addQuadCurve(to: CGPoint(x: 31, y: 88), control: CGPoint(x: 50, y: 91))
        robe.closeSubpath()
        p.addPath(robe)

        if armsRaised {
            // Hands up beside the head, palms forward — the opening Takbir.
            p.addPath(limb(from: CGPoint(x: 39, y: 34), to: CGPoint(x: 30, y: 14), width: 7))
            p.addPath(limb(from: CGPoint(x: 61, y: 34), to: CGPoint(x: 70, y: 14), width: 7))
            p.addEllipse(in: CGRect(x: 24, y: 6, width: 11, height: 13))
            p.addEllipse(in: CGRect(x: 65, y: 6, width: 11, height: 13))
        } else {
            // Right hand over the left, resting on the chest.
            p.addPath(limb(from: CGPoint(x: 38, y: 36), to: CGPoint(x: 50, y: 52), width: 7))
            p.addPath(limb(from: CGPoint(x: 62, y: 36), to: CGPoint(x: 50, y: 52), width: 7))
            p.addEllipse(in: CGRect(x: 44, y: 47, width: 13, height: 10))
        }

        p.addRoundedRect(in: CGRect(x: 30, y: 86, width: 17, height: 7),
                         cornerSize: CGSize(width: 3.5, height: 3.5))         // feet
        p.addRoundedRect(in: CGRect(x: 53, y: 86, width: 17, height: 7),
                         cornerSize: CGSize(width: 3.5, height: 3.5))
    }

    private func bowing(_ p: inout Path) {
        // Back flat, head in line with it, hands gripping the knees.
        var back = Path()
        back.move(to: CGPoint(x: 30, y: 34))
        back.addLine(to: CGPoint(x: 66, y: 30))
        back.addLine(to: CGPoint(x: 70, y: 52))
        back.addLine(to: CGPoint(x: 32, y: 50))
        back.closeSubpath()
        p.addPath(back)

        p.addEllipse(in: CGRect(x: 14, y: 30, width: 19, height: 18))          // head
        p.addPath(limb(from: CGPoint(x: 36, y: 40), to: CGPoint(x: 42, y: 66), width: 7)) // arm to knee
        p.addEllipse(in: CGRect(x: 37, y: 62, width: 12, height: 10))          // hand on knee

        // Legs vertical: the hips stay above the heels.
        p.addPath(limb(from: CGPoint(x: 62, y: 46), to: CGPoint(x: 58, y: 88), width: 13))
        p.addRoundedRect(in: CGRect(x: 46, y: 85, width: 24, height: 8),
                         cornerSize: CGSize(width: 4, height: 4))
    }

    private func prostrating(_ p: inout Path) {
        // Forehead on the ground at the left, hips raised at the right.
        var body = Path()
        body.move(to: CGPoint(x: 30, y: 78))
        body.addQuadCurve(to: CGPoint(x: 68, y: 52), control: CGPoint(x: 50, y: 60))
        body.addLine(to: CGPoint(x: 78, y: 66))
        body.addQuadCurve(to: CGPoint(x: 34, y: 90), control: CGPoint(x: 54, y: 80))
        body.closeSubpath()
        p.addPath(body)

        p.addEllipse(in: CGRect(x: 15, y: 74, width: 19, height: 18))          // head down
        p.addRoundedRect(in: CGRect(x: 20, y: 82, width: 20, height: 8),
                         cornerSize: CGSize(width: 4, height: 4))              // hands flat
        p.addPath(limb(from: CGPoint(x: 72, y: 62), to: CGPoint(x: 84, y: 88), width: 12)) // shins
        p.addRoundedRect(in: CGRect(x: 72, y: 85, width: 18, height: 8),
                         cornerSize: CGSize(width: 4, height: 4))              // toes
    }

    private func sitting(_ p: inout Path) {
        p.addEllipse(in: CGRect(x: 41, y: 16, width: 18, height: 19))          // head
        p.addRoundedRect(in: CGRect(x: 46, y: 33, width: 8, height: 6),
                         cornerSize: CGSize(width: 3, height: 3))

        var torso = Path()
        torso.move(to: CGPoint(x: 39, y: 39))
        torso.addQuadCurve(to: CGPoint(x: 61, y: 39), control: CGPoint(x: 50, y: 35))
        torso.addLine(to: CGPoint(x: 66, y: 74))
        torso.addLine(to: CGPoint(x: 34, y: 74))
        torso.closeSubpath()
        p.addPath(torso)

        // Folded legs, sitting on the left foot.
        p.addRoundedRect(in: CGRect(x: 24, y: 74, width: 54, height: 14),
                         cornerSize: CGSize(width: 7, height: 7))
        p.addRoundedRect(in: CGRect(x: 66, y: 66, width: 10, height: 22),
                         cornerSize: CGSize(width: 5, height: 5))              // right foot upright

        // Hands on the thighs, right index pointing forward.
        p.addPath(limb(from: CGPoint(x: 40, y: 44), to: CGPoint(x: 34, y: 70), width: 7))
        p.addPath(limb(from: CGPoint(x: 60, y: 44), to: CGPoint(x: 66, y: 70), width: 7))
        p.addEllipse(in: CGRect(x: 60, y: 66, width: 12, height: 10))
    }

    // MARK: Geometry helper

    /// A thick rounded segment — the only primitive limbs need.
    private func limb(from a: CGPoint, to b: CGPoint, width: CGFloat) -> Path {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let angle = atan2(dy, dx)
        let rect = CGRect(x: 0, y: -width / 2, width: length, height: width)
        let rounded = Path(roundedRect: rect, cornerRadius: width / 2)
        return rounded
            .applying(CGAffineTransform(rotationAngle: angle))
            .applying(CGAffineTransform(translationX: a.x, y: a.y))
    }
}

// MARK: - Generated illustrations

/// The illustrations ship as loose PNGs in the kit's resources rather than in
/// an asset catalogue, because the kit is compiled into both the app and the
/// widget extension and each needs its own copy.
public enum PositionAsset {
    private static var cache: [String: UIImage?] = [:]
    private static let lock = NSLock()

    /// Decodes at the size the medallion actually draws rather than at the
    /// file's 512 px. A widget extension is killed past 30 MB, and the carousel
    /// holds a whole timeline of entries at once: a full-size decode is 1 MB of
    /// pixels per posture, for a disc that is never wider than 104 pt.
    /// `CGImageSourceCreateThumbnailAtIndex` downsamples *while* decoding, so
    /// the full bitmap never exists in memory.
    public static func image(named name: String, maxPixel: CGFloat = 512) -> UIImage? {
        let side = max(64, min(512, (maxPixel / 32).rounded(.up) * 32))
        let key = "\(name)@\(Int(side))"

        lock.lock(); defer { lock.unlock() }
        if let hit = cache[key] { return hit }

        let bundle = Bundle(for: SalatKitBundleToken.self)
        let loaded = bundle.url(forResource: name, withExtension: "png").flatMap { url -> UIImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: side
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                .map { UIImage(cgImage: $0) }
        }
        cache[key] = loaded
        return loaded
    }
}

private final class SalatKitBundleToken {}

// MARK: - Framed illustration used on cards and in the widget

/// The generated illustration when there is one, the drawn figure otherwise.
/// The illustrations are cut out on transparency, so they sit on the sand disc
/// with no seam and can be inset far enough that no limb is ever clipped.
public struct PositionMedallion: View {
    public let step: PrayerStep
    public var size: CGFloat

    /// Drawn as a light silhouette instead of dark ink on sand. Used when the
    /// home screen is tinted: there, iOS keeps only the *luminance* of what the
    /// widget drew, and brown ink on cream comes out as an almost empty card.
    public var monochrome: Bool

    public init(step: PrayerStep, size: CGFloat = 120, monochrome: Bool = false) {
        self.step = step
        self.size = size
        self.monochrome = monochrome
    }

    public var body: some View {
        ZStack {
            Circle().fill(monochrome ? Color.white.opacity(0.16) : Theme.sand)

            if !monochrome {
                StarLattice(spacing: size / 2.6, opacity: 0.10)
                    .clipShape(Circle())
            }

            if let illustration = PositionAsset.image(named: step.image, maxPixel: size * 3) {
                // The cut-outs carry the figure in their alpha channel, so a
                // template render turns the same file into a light silhouette.
                Image(uiImage: illustration)
                    .renderingMode(monochrome ? .template : .original)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(size * 0.13)
            } else {
                PostureFigure(posture: step.posture,
                              tint: monochrome ? .white : Theme.ink.opacity(0.82))
                    .padding(size * 0.14)
            }

            Circle().strokeBorder(monochrome ? Color.white.opacity(0.45) : Theme.goldSoft,
                                  lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }
}
