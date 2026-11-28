import Foundation

/// The App Store's **real** rating of Salat, for the paywall's laurels
/// (27/11/2026, Marvin's paywall research: social proof reassures).
///
/// Read from Apple's public lookup API (`itunes.apple.com/lookup`, no key;
/// nothing about the reader leaves the phone but the country), cached for a
/// day. The laurels only show when the rating deserves showing
/// (`minAverage`) **and** rests on enough ratings (`minCount`): « 5 ★ · 2
/// ratings » does more harm than nothing. Never a number written in the code
/// or invented: that is rule 5.6, and the welcome's own rule.
@MainActor
@Observable
final class StoreRating {
    static let shared = StoreRating()

    static let appID = "6798837070"
    static let minCount = 10
    static let minAverage = 4.5

    private(set) var average: Double?
    private(set) var count = 0

    var showable: Bool { (average ?? 0) >= Self.minAverage && count >= Self.minCount }

    private let cacheKey = "storeRating.v1"
    private let maxAge: TimeInterval = 86_400

    private init() {
        if let cache = UserDefaults.standard.dictionary(forKey: cacheKey) {
            average = cache["avg"] as? Double
            count = cache["count"] as? Int ?? 0
        }
        #if DEBUG
        // `-debugRating "4.8 124"`: the laurels without a real rating.
        if let forced = UserDefaults.standard.string(forKey: "debugRating")?.split(separator: " "),
           forced.count == 2, let avg = Double(forced[0]), let n = Int(forced[1]) {
            average = avg
            count = n
        }
        #endif
    }

    func refresh() async {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "debugRating") != nil { return }
        #endif
        if let cache = UserDefaults.standard.dictionary(forKey: cacheKey),
           let at = cache["at"] as? Double, Date().timeIntervalSince1970 - at < maxAge { return }
        let country = (Locale.current.region?.identifier ?? "US").lowercased()
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(Self.appID)&country=\(country)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first else { return }
        average = first["averageUserRating"] as? Double
        count = first["userRatingCount"] as? Int ?? 0
        UserDefaults.standard.set(["avg": average ?? 0, "count": count,
                                   "at": Date().timeIntervalSince1970], forKey: cacheKey)
    }
}
