import AVFoundation
import Observation

/// Whose voice is sounding. The same player handles both so that "listen to
/// them, then to yourself" is one queue rather than two objects taking turns.
enum Voice: Equatable {
    case reciter
    case mine
}

/// Plays a step line by line and says which line is sounding, so the card can
/// light the verse being recited.
@Observable
final class RecitationPlayer: NSObject, AVAudioPlayerDelegate {

    /// Nil when silent. Reading this is how views know to pause the carousel.
    private(set) var voice: Voice?
    private(set) var line: Int?

    /// Slowed down for repeating after. Below ~0.55 the pitch correction turns
    /// the recitation into a growl, so the UI only offers one slow step.
    var rate: Float = 1.0

    private var player: AVAudioPlayer?
    private var queue: [(voice: Voice, line: Int, url: URL)] = []
    private var onFinish: (() -> Void)?

    var isPlaying: Bool { voice != nil }

    /// 0…1 through the clip that is sounding. Not observable — AVAudioPlayer
    /// has no callback for it — so views poll it on a timer while `isPlaying`.
    var progress: Double {
        guard let player, player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    // MARK: Playing

    /// One line, or one whole recording of the user.
    func play(_ voice: Voice, line: Int, url: URL, onFinish: (() -> Void)? = nil) {
        play(queue: [(voice, line, url)], onFinish: onFinish)
    }

    /// Every line of a step, back to back.
    func playAll(_ voice: Voice, urls: [URL], onFinish: (() -> Void)? = nil) {
        play(queue: urls.enumerated().map { (voice, $0.offset, $0.element) }, onFinish: onFinish)
    }

    private func play(queue items: [(voice: Voice, line: Int, url: URL)],
                      onFinish: (() -> Void)?) {
        stop()
        guard !items.isEmpty else { return }
        self.onFinish = onFinish
        queue = items
        AudioSession.beginPlayback()
        playNext()
    }

    private func playNext() {
        guard !queue.isEmpty else { return finish() }
        let item = queue.removeFirst()
        guard let player = try? AVAudioPlayer(contentsOf: item.url) else { return finish() }
        player.delegate = self
        // `enableRate` has to be set before `prepareToPlay`, otherwise the rate
        // is silently ignored and the slow button does nothing.
        player.enableRate = true
        player.rate = rate
        player.prepareToPlay()
        self.player = player
        voice = item.voice
        line = item.line
        player.play()
    }

    func stop() {
        player?.stop()
        player = nil
        queue = []
        voice = nil
        line = nil
        let callback = onFinish
        onFinish = nil
        callback?()
        AudioSession.release()
    }

    /// Same as `stop` but does not cut a queue that is still running.
    private func finish() {
        player = nil
        voice = nil
        line = nil
        let callback = onFinish
        onFinish = nil
        callback?()
        AudioSession.release()
    }

    // MARK: AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playNext()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        finish()
    }
}
