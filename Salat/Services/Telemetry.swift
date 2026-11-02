import Foundation
import UIKit

/// Anonymous usage metrics sent to the `app-metrics` server
/// (`~/Documents/tools/app-metrics`, live at sharik.fr/metrics/), the same
/// one MeowTube and Last Soldier report to.
///
/// What leaves the phone: an install id drawn at random here (no IDFA, no
/// device id; deleting the app erases it), the version, the language, and
/// events without content: sessions, which step was opened, which tool was
/// used, how a drill round went. Never a recording, never a recognised word.
///
/// Events pile up in memory and leave in batches: every 60 s while the app is
/// in front (that heartbeat is also what counts the install as "online") and
/// when it goes to the background. A failed send keeps its batch for the next.
final class Telemetry {

    static let shared = Telemetry()

    private let endpoint = URL(string: "https://sharik.fr/metrics/api/collect")!
    private let app = "salat"
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "telemetry")

    private var pending: [[String: Any]] = []
    private var sessionStart: Date?
    private var timer: Timer?
    private var sending = false
    private var started = false

    private enum Keys {
        static let install = "telemetryInstallId"
        static let pending = "telemetryPending"
    }

    private lazy var install: String = {
        if let id = defaults.string(forKey: Keys.install) { return id }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: Keys.install)
        return id
    }()

    private init() {}

    /// Called once at launch.
    func start() {
        guard !started else { return }
        started = true
        queue.sync {
            pending = (defaults.array(forKey: Keys.pending) as? [[String: Any]]) ?? []
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(didBecomeActive),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(didEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    // MARK: - Recording

    /// `props` go into the dashboard's per-property breakdown: low-cardinality
    /// values only (a step id, a tool, yes/no), never free text.
    func track(_ name: String, value: Double? = nil, props: [String: String] = [:]) {
        var event: [String: Any] = ["n": name, "t": Int(Date().timeIntervalSince1970 * 1000)]
        if let value { event["v"] = value }
        if !props.isEmpty { event["p"] = props }
        queue.async { self.pending.append(event) }
    }

    // MARK: - Life cycle

    @objc private func didBecomeActive() {
        guard sessionStart == nil else { return }
        sessionStart = Date()
        // The language actually on screen, and whether it was picked by hand.
        let manual = SharedStore.storedLanguagePreference != .system
        track("session_start", props: ["lang": SharedStore.language.rawValue,
                                       "lang_source": manual ? "manual" : "system"])
        flush()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.flush() }
    }

    @objc private func didEnterBackground() {
        timer?.invalidate()
        timer = nil
        if let start = sessionStart {
            track("session_end", value: Date().timeIntervalSince(start).rounded())
            sessionStart = nil
        }
        // iOS leaves a suspended app a few seconds: enough to finish the send.
        var task = UIBackgroundTaskIdentifier.invalid
        task = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(task) }
        flush { UIApplication.shared.endBackgroundTask(task) }
    }

    // MARK: - Sending

    private func flush(done: (() -> Void)? = nil) {
        queue.async {
            // One send at a time; past 500 waiting events (days offline) the
            // most recent are kept.
            self.pending = Array(self.pending.suffix(500))
            self.defaults.set(self.pending, forKey: Keys.pending)
            guard !self.sending else { done?(); return }

            let batch = Array(self.pending.prefix(200))
            self.sending = true
            self.post(batch) { ok in
                self.queue.async {
                    self.sending = false
                    if ok {
                        self.pending.removeFirst(min(batch.count, self.pending.count))
                        self.defaults.set(self.pending, forKey: Keys.pending)
                    }
                    done?()
                }
            }
        }
    }

    /// What goes with every batch: the install, never the person.
    private var context: [String: Any] {
        var version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        #if DEBUG
        version += "-debug"
        #endif
        return [
            "app": app,
            "install": install,
            "platform": "ios",
            "version": version,
            "os": UIDevice.current.systemVersion,
            "locale": AppLanguage.devicePreferredLanguages.first ?? "",
        ]
    }

    private func post(_ events: [[String: Any]], completion: @escaping (Bool) -> Void) {
        var body = context
        body["events"] = events
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 400 = batch refused by the server: sending it again changes nothing.
            completion((200..<300).contains(status) || status == 400)
        }.resume()
    }
}
