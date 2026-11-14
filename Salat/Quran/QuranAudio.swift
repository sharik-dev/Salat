import AVFoundation
import Observation

/// The recitation of the whole Qur'an, one file per verse.
///
/// The prayer's own clips ship in the bundle; these cannot: nine reciters
/// times 6236 verses is several gigabytes. Each verse is fetched from
/// everyayah.com (the same source, the same reciters) the first time it is
/// heard, and kept in the caches directory, which iOS may empty when the phone
/// runs short.
///
/// This is the one place the app downloads content. Nothing about the reader
/// goes up: the request is a plain GET for a public mp3.
enum QuranAudio {

    enum Failure: Error { case noSource, badResponse }

    private static let root: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("quran-audio", isDirectory: true)
    }()

    private static func name(surah: Int, verse: Int) -> String {
        String(format: "%03d%03d.mp3", surah, verse)
    }

    static func remote(reciter: Reciter, surah: Int, verse: Int) -> URL? {
        guard reciter.source.hasPrefix("https://") else { return nil }
        return URL(string: reciter.source)?.appendingPathComponent(name(surah: surah, verse: verse))
    }

    static func local(reciter: Reciter, surah: Int, verse: Int) -> URL {
        root.appendingPathComponent(reciter.id, isDirectory: true)
            .appendingPathComponent(name(surah: surah, verse: verse))
    }

    /// The verse on disk, downloaded first if it is not there yet.
    static func file(reciter: Reciter, surah: Int, verse: Int) async throws -> URL {
        let destination = local(reciter: reciter, surah: surah, verse: verse)
        if FileManager.default.fileExists(atPath: destination.path) { return destination }
        guard let source = remote(reciter: reciter, surah: surah, verse: verse) else {
            throw Failure.noSource
        }
        var request = URLRequest(url: source)
        request.timeoutInterval = 20
        let (temporary, response) = try await URLSession.shared.download(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.badResponse }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // Moved in one go, so a half-written file is never found by the next
        // call. Two calls for the same verse (the one playing and the one
        // fetching ahead) both get here; the loser's move fails and is ignored.
        try? FileManager.default.moveItem(at: temporary, to: destination)
        guard FileManager.default.fileExists(atPath: destination.path) else { throw Failure.badResponse }
        return destination
    }

    /// Keeps the cache under `limit`, oldest files first. Run once when the
    /// tab opens: someone who listens to a juz a day would otherwise carry
    /// every verse they ever heard.
    static func trim(limit: Int = 250_000_000) {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let walker = manager.enumerator(at: root, includingPropertiesForKeys: keys) else { return }
        var files: [(url: URL, size: Int, date: Date)] = []
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            files.append((url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast))
        }
        var total = files.reduce(0) { $0 + $1.size }
        guard total > limit else { return }
        for file in files.sorted(by: { $0.date < $1.date }) {
            try? manager.removeItem(at: file.url)
            total -= file.size
            if total <= limit * 4 / 5 { break }
        }
    }
}

/// Plays the feed's current verse and says when it is done, so the feed can
/// turn the page. Its own player rather than `RecitationPlayer`: that one
/// plays a queue of bundled files, this one waits for a download, and a verse
/// requested and then scrolled past must never start late over the next one.
///
/// A long verse is shown over several screens but is still **one recording**.
/// So a screen plays a *span* of the file (`from`…`until`, as fractions of it):
/// reaching `until` calls back without stopping, the feed turns the page, and
/// `carryOn` hands the same sound its next stop. The voice never restarts in
/// the middle of a verse it is simply running through.
@Observable
final class QuranPlayer: NSObject, AVAudioPlayerDelegate {

    enum State: Equatable { case idle, loading, playing, paused, failed }

    private(set) var state: State = .idle

    private var player: AVAudioPlayer?
    private var onFinish: (() -> Void)?
    /// Bumped by every request and every stop: an answer that comes back with
    /// an old number belongs to a page the reader has already left.
    private var token = 0
    private var holdsSession = false
    /// Which verse the loaded file is.
    private var loaded: (surah: Int, verse: Int)?
    private var from = 0.0
    /// Where the current screen's span ends; nil when it runs to the end of
    /// the file, which the delegate reports.
    private var until: Double?
    private var ticker: Timer?

    /// 0…1 through the span of the current screen. Polled by the progress bar.
    var progress: Double {
        guard let player, player.duration > 0 else { return 0 }
        let whole = player.currentTime / player.duration
        let end = until ?? 1
        guard end > from else { return 0 }
        return min(max((whole - from) / (end - from), 0), 1)
    }

    /// True while this verse's recording is sounding.
    func isSounding(surah: Int, verse: Int) -> Bool {
        state == .playing && loaded?.surah == surah && loaded?.verse == verse
    }

    @MainActor
    func play(reciter: Reciter, surah: Int, verse: Int,
              from: Double = 0, until: Double = 1, onFinish: @escaping () -> Void) {
        token += 1
        let mine = token
        halt()
        self.onFinish = onFinish
        state = .loading

        Task { @MainActor in
            do {
                let url = try await QuranAudio.file(reciter: reciter, surah: surah, verse: verse)
                guard mine == self.token else { return }
                guard let player = try? AVAudioPlayer(contentsOf: url) else {
                    // A file that will not decode would fail forever: drop it
                    // so the next visit downloads it again.
                    try? FileManager.default.removeItem(at: url)
                    self.state = .failed
                    return
                }
                player.delegate = self
                // Held across verses, released on stop: giving the session
                // back between two verses would let someone's paused podcast
                // start up in the half-second gap.
                if !self.holdsSession {
                    AudioSession.beginPlayback()
                    self.holdsSession = true
                }
                player.prepareToPlay()
                if from > 0 { player.currentTime = from * player.duration }
                player.play()
                self.player = player
                self.loaded = (surah, verse)
                self.from = from
                self.until = until < 0.999 ? until : nil
                self.state = .playing
                self.startTicker()
            } catch {
                guard mine == self.token else { return }
                self.state = .failed
            }
        }
    }

    /// The sound keeps running into the next screen of the same verse: only
    /// where it stops next, and whom it tells, change.
    func carryOn(from: Double, until: Double, onFinish: @escaping () -> Void) {
        self.from = from
        self.until = until < 0.999 ? until : nil
        self.onFinish = onFinish
    }

    /// A tap on the page: hold the voice, or let it go on.
    func togglePause() {
        switch state {
        case .playing:
            player?.pause()
            state = .paused
        case .paused:
            player?.play()
            state = .playing
        default:
            break
        }
    }

    /// Fetches a verse ahead of time, so turning the page does not wait.
    func prefetch(reciter: Reciter, surah: Int, verse: Int) {
        Task.detached(priority: .utility) {
            _ = try? await QuranAudio.file(reciter: reciter, surah: surah, verse: verse)
        }
    }

    func stop() {
        token += 1
        halt()
        state = .idle
        if holdsSession {
            AudioSession.release()
            holdsSession = false
        }
    }

    private func halt() {
        ticker?.invalidate()
        ticker = nil
        player?.stop()
        player = nil
        loaded = nil
        onFinish = nil
        until = nil
        from = 0
    }

    /// AVAudioPlayer has no callback for "reached this point", so the end of a
    /// span is watched for. Twenty times a second is finer than a page turn.
    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.state == .playing, let until = self.until,
                  let player = self.player, player.duration > 0,
                  player.currentTime / player.duration >= until else { return }
            // Told once: the feed answers with `carryOn` or with a new verse.
            self.until = nil
            let callback = self.onFinish
            self.onFinish = nil
            callback?()
        }
    }

    // MARK: AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        ticker?.invalidate()
        ticker = nil
        self.player = nil
        loaded = nil
        state = .idle
        let callback = onFinish
        onFinish = nil
        callback?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        halt()
        state = .failed
    }
}
