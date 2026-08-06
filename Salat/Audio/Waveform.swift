import AVFoundation
import SwiftUI

/// Turns an audio file into a handful of loudness values — enough to draw the
/// shape of a recitation, not enough to be an oscilloscope.
///
/// The reciter's mp3 and the user's m4a go through the *same* reader on
/// purpose: two different measures (say, decoded peaks on one side and the
/// recorder's dB meter on the other) would draw two shapes that cannot honestly
/// be laid over each other.
enum Waveform {

    /// How many bars a trace is drawn with. Small: the eye compares silhouettes
    /// and pauses, not individual samples.
    static let buckets = 64

    struct Trace: Equatable, Sendable {
        var samples: [Float]      // 0…1, normalised on its own peak
        var duration: Double      // seconds
    }

    private static var cache: [URL: Trace] = [:]
    private static let lock = NSLock()

    static func cached(_ url: URL) -> Trace? {
        lock.lock(); defer { lock.unlock() }
        return cache[url]
    }

    static func forget(_ url: URL) {
        lock.lock(); defer { lock.unlock() }
        cache[url] = nil
    }

    static func load(_ url: URL) async -> Trace? {
        if let hit = cached(url) { return hit }
        guard let trace = await read(url) else { return nil }
        lock.lock()
        cache[url] = trace
        lock.unlock()
        return trace
    }

    // MARK: Reading

    private static func read(_ url: URL) async -> Trace? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let duration = try? await asset.load(.duration).seconds,
              duration.isFinite, duration > 0,
              let reader = try? AVAssetReader(asset: asset)
        else { return nil }

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }

        // RMS over fixed-size windows first, then resampled to `buckets`: the
        // total number of frames is not known ahead of decoding, so the bucket
        // width cannot be computed up front.
        var windows: [Float] = []
        var sum: Double = 0
        var count = 0
        let window = 2_048

        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil,
                                              totalLengthOut: &length,
                                              dataPointerOut: &pointer) == noErr,
                  let pointer else { continue }

            pointer.withMemoryRebound(to: Int16.self, capacity: length / 2) { samples in
                for index in 0..<(length / 2) {
                    let value = Double(samples[index]) / 32_768
                    sum += value * value
                    count += 1
                    if count == window {
                        windows.append(Float((sum / Double(window)).squareRoot()))
                        sum = 0
                        count = 0
                    }
                }
            }
            CMSampleBufferInvalidate(buffer)
        }
        if count > 0 { windows.append(Float((sum / Double(count)).squareRoot())) }
        guard !windows.isEmpty else { return nil }

        return Trace(samples: normalise(resample(windows, to: buckets)), duration: duration)
    }

    private static func resample(_ values: [Float], to size: Int) -> [Float] {
        guard values.count > size else {
            return values + Array(repeating: 0, count: size - values.count)
        }
        let width = Double(values.count) / Double(size)
        return (0..<size).map { index in
            let start = Int(Double(index) * width)
            let end = min(values.count, Int(Double(index + 1) * width))
            guard end > start else { return values[start] }
            // Peak, not mean: averaging a second of speech into one bar flattens
            // every consonant and all the traces end up looking alike.
            return values[start..<end].max() ?? 0
        }
    }

    /// Each trace is normalised on its own peak, so a quiet phone recording and
    /// a studio one are compared on *shape and timing* — the two things the user
    /// can actually act on — rather than on how loud they were.
    private static func normalise(_ values: [Float]) -> [Float] {
        guard let peak = values.max(), peak > 0.0001 else { return values }
        return values.map { min(1, $0 / peak) }
    }
}

// MARK: - Drawing

/// A trace, drawn as symmetric bars. `scale` is the fraction of the shared time
/// axis this clip occupies: two traces on the same axis show at a glance who
/// took longer, which no pair of independently-stretched waveforms ever could.
struct WaveformView: View {
    let trace: Waveform.Trace?
    var color: Color
    var scale: Double = 1
    /// 0…1 while playing, nil when silent — the played part is drawn solid.
    var progress: Double?

    var body: some View {
        GeometryReader { geo in
            let samples = trace?.samples ?? []
            let width = geo.size.width * max(0.02, min(1, scale))
            let barWidth = max(1, width / CGFloat(max(1, samples.count)) - 1.4)

            HStack(alignment: .center, spacing: 1.4) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, value in
                    let played = progress.map { Double(index) / Double(samples.count) <= $0 } ?? false
                    Capsule()
                        .fill(color.opacity(progress == nil ? 0.85 : (played ? 1 : 0.28)))
                        .frame(
                            width: barWidth,
                            // A floor of 2 pt: silence still draws a thin line,
                            // so a gap reads as a pause and not as a bug.
                            height: max(2, CGFloat(value) * geo.size.height)
                        )
                }
            }
            .frame(width: width, height: geo.size.height, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.linear(duration: 0.1), value: progress ?? -1)
        }
    }
}

/// The placeholder while a trace decodes, and the resting state of a slot with
/// nothing in it. Deliberately flat rather than a spinner: a spinner in an empty
/// row reads as "loading forever".
struct WaveformPlaceholder: View {
    var color: Color

    var body: some View {
        Capsule()
            .fill(color.opacity(0.22))
            .frame(height: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
