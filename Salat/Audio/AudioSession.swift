import AVFoundation

/// One place decides what the audio session is, because the category is a
/// process-wide setting: `Sound` (the UI clicks) and the recitation player
/// would otherwise fight over it and whoever spoke last would win.
enum AudioSession {

    /// Deliberate listening: audible even with the ring switch off, and it
    /// takes the airwaves — someone who presses play wants to hear the reciter,
    /// not the reciter under their podcast.
    static func beginPlayback() {
        set(.playback, options: [])
    }

    /// Recording. `.defaultToSpeaker` matters: without it `.playAndRecord`
    /// routes the playback that follows to the earpiece, and the user thinks
    /// their recording came out silent.
    static func beginRecording() {
        set(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
    }

    /// Back to the idle stance: the UI clicks obey the silent switch again and,
    /// above all, whatever the user was listening to before resumes. An app
    /// about prayer that permanently kills a background recitation is an app
    /// that gets closed.
    static func release() {
        set(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private static func set(_ category: AVAudioSession.Category,
                            options: AVAudioSession.CategoryOptions) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(category, mode: .default, options: options)
        try? session.setActive(true)
    }
}
