import Foundation

/// A voice the app ships. `style` is `muallim` (the teaching recording — slow,
/// each verse detached) or `murattal` (recited at normal pace).
struct Reciter: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let name: String
    let style: String
    /// Where the files came from — shown in the credits, and the only way to
    /// trace an attribution once the mp3 sits in the bundle.
    let source: String

    var isTeaching: Bool { style == "muallim" }
}

/// The bundled recitation clips: one file per *line* of a step, which is the
/// granularity the cards already use.
///
/// Only the two Qur'anic steps have clips. The takbir, the tasbih of the ruku,
/// the tashahhud are not Qur'an, and there is no openly-licensed corpus of them
/// cut phrase by phrase — so those steps carry no reciter rather than an
/// amateur clip passing for one. Every screen has to cope with `clips` being
/// empty; that is the normal case, not the edge case.
enum Recitations {

    private struct Manifest: Decodable {
        let reciters: [Reciter]
        /// reciter id → step id → resource name per line, in line order.
        let clips: [String: [String: [String]]]
    }

    private static let manifest: Manifest? = {
        guard let url = Bundle.main.url(forResource: "recitations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }()

    static var reciters: [Reciter] { manifest?.reciters ?? [] }

    /// The one to start people on: the teaching recording if it shipped.
    static var defaultReciter: Reciter? {
        reciters.first { $0.isTeaching } ?? reciters.first
    }

    static func reciter(id: String?) -> Reciter? {
        guard let id else { return defaultReciter }
        return reciters.first { $0.id == id } ?? defaultReciter
    }

    /// How many lines of this step a reciter covers. Zero for every non-Qur'anic
    /// step — callers branch on this, not on the step id.
    static func lineCount(step: String, reciter: Reciter?) -> Int {
        guard let reciter else { return 0 }
        return manifest?.clips[reciter.id]?[step]?.count ?? 0
    }

    static func hasClips(step: String, reciter: Reciter?) -> Bool {
        lineCount(step: step, reciter: reciter) > 0
    }

    static func clip(step: String, line: Int, reciter: Reciter?) -> URL? {
        guard let reciter,
              let names = manifest?.clips[reciter.id]?[step],
              names.indices.contains(line) else { return nil }
        return Bundle.main.url(forResource: names[line], withExtension: "mp3")
    }

    static func clips(step: String, reciter: Reciter?) -> [URL] {
        (0..<lineCount(step: step, reciter: reciter))
            .compactMap { clip(step: step, line: $0, reciter: reciter) }
    }
}
