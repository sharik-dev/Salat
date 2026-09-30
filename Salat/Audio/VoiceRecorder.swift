import AVFoundation
import Observation
import Speech

/// Records the user saying one line of one step, and keeps it on disk so it is
/// still there tomorrow — the point is to hear last week's attempt against
/// today's.
///
/// The files stay in the app's own Documents, not in the App Group: a voice
/// memo of someone praying is nobody else's business, and the widget has no use
/// for it.
///
/// While the microphone is open, the same buffers also feed **on-device**
/// speech recognition, which is what moves the green word cursor on the line
/// being recited. Two hard rules keep that honest:
///
/// - `requiresOnDeviceRecognition` is always on. The privacy page says nothing
///   leaves the phone; a cloud recognizer would make that page a lie. On a
///   device that cannot recognise Arabic locally, the cursor simply stays off
///   and recording works exactly as before.
/// - The cursor marks **position, not correctness**. It advances when a word
///   is heard; it never scores, colours a mistake, or blocks anything. No app
///   can grade tajwid, and this one does not pretend to.
@Observable
final class VoiceRecorder: NSObject {

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

    /// How many words of the line being recorded have been heard so far — the
    /// user's karaoke cursor. Monotonic within one take; stays at 0 when the
    /// recognizer is unavailable, unauthorised, or simply has heard nothing.
    private(set) var matchedWords = 0

    /// Bumped every time a recording is written or deleted. Views observe it to
    /// re-read the disk, which is otherwise invisible to SwiftUI.
    private(set) var revision = 0

    private var engine: AVAudioEngine?
    private var file: AVAudioFile?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// The line's arabic words, stripped down to what recognition can match.
    private var target: [String] = []

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

    /// `arabic` is the line being recited. When it is given and the device can
    /// recognise Arabic locally, the word cursor runs; without it this is a
    /// plain recording, which is also what it degrades to on refusal.
    func start(step: String, line: Int, arabic: String? = nil) {
        requestPermission { [weak self] granted in
            guard let self, granted else { return }
            self.begin(step: step, line: line, arabic: arabic)
        }
    }

    private func begin(step: String, line: Int, arabic: String?) {
        stop()
        AudioSession.beginRecording()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        // Same AAC-in-m4a as the old AVAudioRecorder wrote: small enough to
        // keep dozens of attempts, and what the waveform reader handles.
        let url = Self.url(step: step, line: line)
        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let file = try? AVAudioFile(forWriting: url, settings: settings,
                                          commonFormat: format.commonFormat,
                                          interleaved: format.isInterleaved) else { return }

        self.file = file
        matchedWords = 0
        target = arabic.map { $0.split(separator: " ").map(Self.strippedArabic) } ?? []

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.consume(buffer)
        }

        engine.prepare()
        guard (try? engine.start()) != nil else {
            input.removeTap(onBus: 0)
            self.file = nil
            return
        }

        self.engine = engine
        state = .recording(step: step, line: line)
        elapsed = 0
        level = 0
        Waveform.forget(url)

        if !target.isEmpty { startRecognition() }
    }

    /// Runs on the audio thread: write the file, meter the level, feed the
    /// recognizer, and hop to the main thread with nothing but numbers.
    private func consume(_ buffer: AVAudioPCMBuffer) {
        try? file?.write(from: buffer)
        request?.append(buffer)

        var rms = 0.0
        if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
            rms = Double(sum / Float(buffer.frameLength)).squareRoot()
        }
        // dBFS as before: −160 silent, 0 clipping. Anything under −50 is room
        // noise, so the ring stays still instead of trembling forever.
        let db = 20 * log10(max(rms, 1e-8))
        let normalized = max(0, (db + 50) / 50)
        let seconds = Double(buffer.frameLength) / buffer.format.sampleRate

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.level += (normalized - self.level) * 0.35
            self.elapsed += seconds
            // A hard ceiling, so a recording left running while the phone is
            // in a pocket does not grow without end.
            if self.elapsed > 60 { self.stop() }
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        // Dropping the file is what finalises the m4a header; it must happen
        // before `revision` sends the views off to read it.
        file = nil
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        target = []
        matchedWords = 0
        level = 0
        elapsed = 0
        if isRecording { state = .idle }
        revision += 1
        AudioSession.release()
    }

    // MARK: Recognition

    private func startRecognition() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self, self.isRecording, status == .authorized else { return }
                self.attachRecognizer()
            }
        }
    }

    private func attachRecognizer() {
        // Recitation is closest to Modern Standard Arabic as the ar-SA model
        // hears it. On-device only — see the type comment; no fallback to the
        // network, ever.
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA")),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            let heard = result.bestTranscription.formattedString
                .split(separator: " ").map(Self.strippedArabic)
            DispatchQueue.main.async {
                guard self.isRecording else { return }
                // Monotonic: a partial result that re-hears the start of the
                // line must not yank back words the user already said.
                self.matchedWords = max(self.matchedWords,
                                        Self.matchCount(heard: heard, target: self.target))
            }
        }
    }

    /// How far into `target` the transcript plausibly reaches. Greedy, one
    /// word of tolerance: recognizers drop small words mid-stream, and a
    /// cursor frozen on a missed وَ never catches up.
    static func matchCount(heard: [String], target: [String]) -> Int {
        var position = 0
        for word in heard where position < target.count {
            if similar(word, target[position]) {
                position += 1
            } else if position + 1 < target.count, similar(word, target[position + 1]) {
                position += 2
            }
        }
        return position
    }

    /// Same word to a listener: identical once stripped, or one edit apart —
    /// the recognizer writes plain orthography, the Qur'an text is fully
    /// pointed, and the two never agree byte for byte.
    private static func similar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a.count >= 3, a.hasPrefix(b) || b.hasPrefix(a) { return true }
        guard abs(a.count - b.count) <= 1 else { return false }
        return editDistance(a, b) <= 1
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var previous = row[0]
            row[0] = i
            for j in 1...b.count {
                let substitution = a[i - 1] == b[j - 1] ? previous : previous + 1
                previous = row[j]
                row[j] = min(substitution, row[j] + 1, row[j - 1] + 1)
            }
        }
        return row[b.count]
    }

    /// Drops everything short recitation and plain orthography disagree on:
    /// diacritics, elongation marks, tatweel, and the letter variants
    /// (أ إ آ ٱ / ى / ة / ؤ / ئ) recognizers normalise away.
    static func strippedArabic(_ word: some StringProtocol) -> String {
        var out = ""
        for scalar in word.unicodeScalars {
            switch scalar {
            case "\u{064B}"..."\u{065F}", "\u{0670}", "\u{06D6}"..."\u{06ED}", "\u{0640}":
                continue
            case "\u{0622}", "\u{0623}", "\u{0625}", "\u{0671}":
                out.append("ا")
            case "\u{0649}":
                out.append("ي")
            case "\u{0629}":
                out.append("ه")
            case "\u{0624}":
                out.append("و")
            case "\u{0626}":
                out.append("ي")
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
