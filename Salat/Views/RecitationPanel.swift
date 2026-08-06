import SwiftUI

/// Hear it, say it, look at the two side by side.
///
/// The comparison is deliberately *not* a score. Nothing here judges a
/// pronunciation — no app can, and one that pretended to would be lying about
/// something people take seriously. What it does is put the two recitations on
/// one shared time axis, so the ear has something to aim at and the eye can see
/// where an attempt rushed, dragged, or stopped short.
struct RecitationPanel: View {
    let step: PrayerStep

    @Environment(AppSettings.self) private var settings
    @Environment(RecitationPlayer.self) private var player
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(\.loc) private var loc

    /// Which line of the step is being worked on. Qur'anic steps are practised
    /// verse by verse — that is how they are taught, and a seven-verse take is
    /// too long to compare with anything.
    @State private var line = 0
    @State private var reciterTrace: Waveform.Trace?
    @State private var mineTrace: Waveform.Trace?
    @State private var progress: Double?

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var reciter: Reciter? { Recitations.reciter(id: settings.reciterID) }
    private var clipCount: Int { Recitations.lineCount(step: step.id, reciter: reciter) }
    private var hasClips: Bool { clipCount > 0 }
    private var clip: URL? { Recitations.clip(step: step.id, line: line, reciter: reciter) }

    /// Recomputed rather than stored: `recorder.revision` changes when a file is
    /// written or deleted, and reading it here is what re-runs this view.
    private var mine: URL? {
        _ = recorder.revision
        return VoiceRecorder.recording(step: step.id, line: line)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if hasClips {
                if clipCount > 1 { lineChips }
                listenRow
            } else {
                Text(loc.t("audio.none"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Theme.border)
            recordRow

            if mine != nil {
                compareBlock
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .card()
        .animation(Theme.spring, value: mine)
        .animation(Theme.spring, value: recorder.isRecording)
        .onAppear(perform: loadTraces)
        .onChange(of: line) { _, _ in loadTraces() }
        .onChange(of: recorder.revision) { _, _ in loadTraces() }
        .onChange(of: settings.reciterID) { _, _ in loadTraces() }
        .onReceive(tick) { _ in
            progress = player.isPlaying ? player.progress : nil
        }
        .onDisappear {
            player.stop()
            recorder.stop()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 11))
            Text(loc.t("audio.title").uppercased())
                .font(Theme.label(9))
                .tracking(0.8)
            Spacer()
            if hasClips, let reciter {
                // A menu rather than a settings round-trip: switching voices is
                // something you do while listening, not before.
                Menu {
                    ForEach(Recitations.reciters) { candidate in
                        Button {
                            settings.reciterID = candidate.id
                            Haptic.select.play()
                        } label: {
                            Label(
                                candidate.name + (candidate.isTeaching ? " · \(loc.t("audio.style.teaching"))" : ""),
                                systemImage: candidate.id == reciter.id ? "checkmark" : "person.wave.2"
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(reciter.name).font(Theme.body(11))
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .foregroundStyle(Theme.gold)
    }

    // MARK: Verse picker

    private var lineChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(0..<clipCount, id: \.self) { index in
                    let isOn = index == line
                    Button {
                        player.stop()
                        withAnimation(Theme.spring) { line = index }
                    } label: {
                        Text("\(index + 1)")
                            .font(Theme.pixel(11))
                            .foregroundStyle(isOn ? Theme.ink : Theme.inkSoft)
                            .frame(width: 30, height: 26)
                    }
                    .chunky(isOn ? Theme.goldSoft : Theme.sand,
                            radius: 9, depth: isOn ? 3 : 0,
                            haptic: .select, sparks: false)
                    // The recorded attempts, marked so the row doubles as a map
                    // of what has already been tried.
                    .overlay(alignment: .topTrailing) {
                        if VoiceRecorder.recording(step: step.id, line: index) != nil {
                            Circle().fill(Theme.green).frame(width: 5, height: 5).offset(x: 1, y: -1)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Listen

    private var listenRow: some View {
        HStack(spacing: 8) {
            transport(
                symbol: player.voice == .reciter ? "stop.fill" : "play.fill",
                title: loc.t("audio.listen"),
                tint: Theme.goldSoft
            ) {
                if player.voice == .reciter {
                    player.stop()
                } else if let clip {
                    player.play(.reciter, line: line, url: clip)
                }
            }

            // One slow step, not a slider: below about 0.6× the pitch-corrected
            // recitation turns into a growl and stops being a model to copy.
            Button {
                player.rate = player.rate == 1 ? 0.6 : 1
                Haptic.select.play()
            } label: {
                Text(player.rate == 1 ? "1×" : "0.6×")
                    .font(Theme.pixel(11))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 34)
            }
            .chunky(player.rate == 1 ? Theme.sand : Theme.goldSoft,
                    radius: 11, depth: player.rate == 1 ? 0 : 3,
                    haptic: .select, sparks: false)

            if clipCount > 1 {
                Button {
                    player.playAll(.reciter, urls: Recitations.clips(step: step.id, reciter: reciter))
                } label: {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 34)
                }
                .chunky(Theme.sand, radius: 11, depth: 0, haptic: .tap, sparks: false)
                .accessibilityLabel(loc.t("audio.all"))
            }
        }
    }

    // MARK: Record

    @ViewBuilder
    private var recordRow: some View {
        if recorder.state == .denied {
            Text(loc.t("audio.denied"))
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let active = recorder.isRecording(step: step.id, line: line)
            HStack(spacing: 10) {
                Button {
                    if active {
                        recorder.stop()
                    } else {
                        player.stop()
                        recorder.start(step: step.id, line: line)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: active ? "stop.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(active ? loc.t("audio.stop") : loc.t(mine == nil ? "audio.record" : "audio.retake"))
                            .font(Theme.label(13))
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .chunky(active ? Theme.gold : Theme.sand, radius: 13, depth: 4,
                        haptic: .press, sparks: false)
                .accessibilityIdentifier("audio.record")

                if active {
                    // The ring breathes with what the microphone hears: without
                    // it, a mic that is muted or covered looks exactly like one
                    // that is working, and you only find out on playback.
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.gold)
                            .frame(width: 10 + 12 * recorder.level, height: 10 + 12 * recorder.level)
                            .animation(.linear(duration: 0.05), value: recorder.level)
                            .frame(width: 22, height: 22)
                        Text(String(format: "%.1f", recorder.elapsed))
                            .font(Theme.pixel(11))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 34, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: Compare

    private var compareBlock: some View {
        let longest = max(reciterTrace?.duration ?? 0, mineTrace?.duration ?? 0, 0.001)

        return VStack(alignment: .leading, spacing: 10) {
            if hasClips {
                traceRow(
                    label: reciter?.name ?? loc.t("audio.reciter"),
                    trace: reciterTrace,
                    color: Theme.gold,
                    longest: longest,
                    voice: .reciter,
                    url: clip
                )
            }
            traceRow(
                label: loc.t("audio.mine"),
                trace: mineTrace,
                color: Theme.ink,
                longest: longest,
                voice: .mine,
                url: mine
            )

            HStack(spacing: 8) {
                if hasClips {
                    Button {
                        guard let clip, let mine else { return }
                        playBackToBack(clip: clip, mine: mine)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 11, weight: .bold))
                            Text(loc.t("audio.both")).font(Theme.label(12))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                    }
                    .chunky(Theme.goldSoft, radius: 11, depth: 3, haptic: .tap, sparks: false)
                }

                Button {
                    player.stop()
                    recorder.delete(step: step.id, line: line)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 42, height: 34)
                }
                .chunky(Theme.sand, radius: 11, depth: 0, haptic: .tap, sparks: false)
                .accessibilityLabel(loc.t("audio.delete"))
            }

            Text(loc.t("audio.compare.hint"))
                .font(Theme.body(11))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func traceRow(label: String, trace: Waveform.Trace?, color: Color,
                          longest: Double, voice: Voice, url: URL?) -> some View {
        let isPlaying = player.voice == voice

        return HStack(spacing: 10) {
            Button {
                if isPlaying {
                    player.stop()
                } else if let url {
                    player.play(voice, line: line, url: url)
                }
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 30)
            }
            .chunky(voice == .reciter ? Theme.goldSoft : Theme.sand,
                    radius: 10, depth: 0, haptic: .tap, sparks: false)
            .disabled(url == nil)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(label)
                        .font(Theme.label(9))
                        .tracking(0.6)
                        .foregroundStyle(color)
                        .lineLimit(1)
                    Spacer()
                    if let trace {
                        Text(String(format: "%.1fs", trace.duration))
                            .font(Theme.pixel(9))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Group {
                    if let trace {
                        WaveformView(
                            trace: trace,
                            color: color,
                            // Both rows share one axis — that is the whole
                            // comparison. Stretching each to its own width would
                            // make a rushed attempt look identical to the model.
                            scale: trace.duration / longest,
                            progress: isPlaying ? progress : nil
                        )
                    } else {
                        WaveformPlaceholder(color: color)
                    }
                }
                .frame(height: 30)
            }
        }
    }

    /// Them, a beat of silence, then you. The pause matters: without it the two
    /// run together and the ear cannot tell where one ends.
    private func playBackToBack(clip: URL, mine: URL) {
        player.play(.reciter, line: line, url: clip) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                player.play(.mine, line: line, url: mine)
            }
        }
    }

    // MARK: Traces

    private func loadTraces() {
        let clipURL = clip
        let mineURL = mine
        reciterTrace = clipURL.flatMap(Waveform.cached)
        mineTrace = mineURL.flatMap(Waveform.cached)

        Task {
            if let clipURL, reciterTrace == nil {
                let trace = await Waveform.load(clipURL)
                if clipURL == clip { reciterTrace = trace }
            }
            if let mineURL, mineTrace == nil {
                let trace = await Waveform.load(mineURL)
                if mineURL == mine { mineTrace = trace }
            }
        }
    }

    // MARK: Bits

    private func transport(symbol: String, title: String, tint: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                Text(title).font(Theme.label(13))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .chunky(tint, radius: 12, depth: 3, haptic: .press, sparks: false)
        .accessibilityIdentifier("audio.listen")
    }
}
