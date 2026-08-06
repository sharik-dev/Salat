import AVFoundation
import Observation

/// Records the user saying one line of one step, and keeps it on disk so it is
/// still there tomorrow — the point is to hear last week's attempt against
/// today's.
///
/// The files stay in the app's own Documents, not in the App Group: a voice
/// memo of someone praying is nobody else's business, and the widget has no use
/// for it.
@Observable
final class VoiceRecorder: NSObject, AVAudioRecorderDelegate {

    enum State: Equatable {
        case idle
        case recording(step: String, line: Int)
        /// The user said no to the microphone. The UI stops offering to record
        /// and points at Settings instead of failing silently.
        case denied
    }

    private(set) var state: State = .idle
    /// 0…1, smoothed — drives the ring that pulses while recording so the user
    /// can see the mic is actually hearing them.
    private(set) var level: Double = 0
    private(set) var elapsed: Double = 0

    /// Bumped every time a recording is written or deleted. Views observe it to
    /// re-read the disk, which is otherwise invisible to SwiftUI.
    private(set) var revision = 0

    private var recorder: AVAudioRecorder?
    private var meter: Timer?

    var isRecording: Bool { if case .recording = state { return true }; return false }

    func isRecording(step: String, line: Int) -> Bool {
        state == .recording(step: step, line: line)
    }

    // MARK: Files

    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func url(step: String, line: Int) -> URL {
        directory.appendingPathComponent("\(step)_\(line).m4a")
    }

    static func recording(step: String, line: Int) -> URL? {
        let url = url(step: step, line: line)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func delete(step: String, line: Int) {
        try? FileManager.default.removeItem(at: Self.url(step: step, line: line))
        Waveform.forget(Self.url(step: step, line: line))
        revision += 1
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: Self.directory)
        revision += 1
    }

    /// How many attempts are on disk — the one honest number for a "clear my
    /// recordings" button in Settings.
    static var count: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?
            .filter { $0.hasSuffix(".m4a") }.count ?? 0
    }

    // MARK: Permission

    /// Asked for the first time the record button is pressed, not at launch: an
    /// app that demands the microphone on the first screen gets refused.
    func requestPermission(_ then: @escaping (Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            then(true)
        case .denied:
            state = .denied
            then(false)
        default:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if !granted { self.state = .denied }
                    then(granted)
                }
            }
        }
    }

    // MARK: Recording

    func start(step: String, line: Int) {
        requestPermission { [weak self] granted in
            guard let self, granted else { return }
            self.begin(step: step, line: line)
        }
    }

    private func begin(step: String, line: Int) {
        stop()
        AudioSession.beginRecording()

        // AAC at 44.1 kHz mono: small enough to keep dozens of attempts, and
        // the same container the waveform reader handles for the mp3 clips.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let url = Self.url(step: step, line: line)
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else { return }

        self.recorder = recorder
        state = .recording(step: step, line: line)
        elapsed = 0
        level = 0
        Waveform.forget(url)

        meter = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    private func sample() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        // averagePower is dBFS: −160 silent, 0 clipping. Anything under −50 is
        // room noise, so the ring stays still instead of trembling forever.
        let db = Double(recorder.averagePower(forChannel: 0))
        let normalized = max(0, (db + 50) / 50)
        level += (normalized - level) * 0.35

        // A hard ceiling, so a recording left running while the phone is in a
        // pocket does not grow without end.
        if elapsed > 60 { stop() }
    }

    func stop() {
        meter?.invalidate()
        meter = nil
        recorder?.stop()
        recorder = nil
        level = 0
        elapsed = 0
        if isRecording { state = .idle }
        revision += 1
        AudioSession.release()
    }

    // MARK: AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        revision += 1
    }
}
