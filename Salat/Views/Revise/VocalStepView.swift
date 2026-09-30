import SwiftUI

/// One step, worked line by line.
///
/// The rule of this screen: **whatever is being said is the only thing lit**.
/// While a voice sounds, its line sits centred, on a gold plate, at full
/// contrast, and the rest of the step steps back. Following a recitation means
/// knowing where you are in it — a page of evenly-black text leaves the reader
/// to find that out for themselves, which is exactly the work the app is
/// supposed to do.
struct VocalStepView: View {
    let step: PrayerStep

    @Environment(AppSettings.self) private var settings
    @Environment(RecitationPlayer.self) private var player
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(\.loc) private var loc

    /// The line under work. Shared with the panel below, so choosing a verse
    /// there lights it up here.
    @State private var line = 0

    /// What is sounding right now, if anything. Playback wins over the
    /// selection: the ear leads, the finger follows.
    private var activeLine: Int {
        player.isPlaying ? (player.line ?? line) : line
    }

    /// Effective, not preferred: the adhkar play under the Hisn al-Muslim
    /// voice whatever the settings say, and the spans must follow the voice
    /// that actually sounds.
    private var reciter: Reciter? {
        Recitations.effectiveReciter(step: step.id,
                                     preferring: Recitations.reciter(id: settings.reciterID))
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: 16) {
                    hero

                    // The model first, and visible without scrolling: on the
                    // Fatiha the eleven verse cards buried it at the bottom of
                    // the page, where a listen button might as well not exist.
                    ReciterPanel(step: step, line: $line, marksRecordings: true)

                    VStack(spacing: 10) {
                        ForEach(Array(step.arabicLines.enumerated()), id: \.offset) { index, arabic in
                            LineCard(
                                arabic: arabic,
                                phonetic: text(step.phoneticLines, index),
                                translation: text(step.translationLines, index),
                                isActive: index == activeLine,
                                isSounding: player.voice == .reciter && index == activeLine,
                                // The cursor data, only for the sounding line:
                                // handing spans to fourteen idle cards would
                                // make them all poll the clock for nothing.
                                spans: player.voice == .reciter && index == activeLine
                                    ? Recitations.wordSpans(step: step.id, line: index, reciter: reciter)
                                    : nil,
                                spokenWords: recorder.isRecording(step: step.id, line: index)
                                    ? recorder.matchedWords : nil
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation(Theme.spring) { line = index }
                                Haptic.select.play()
                            }
                        }
                    }

                    // The microphone stays under the text: you record after
                    // having read, and it is the only thing here that needs a
                    // deliberate trip to the bottom of the page.
                    RecitationPanel(step: step, line: $line)

                    Color.clear.frame(height: 92)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            // Follows the voice through a multi-verse recitation: without this,
            // "play every verse" lights up lines that have scrolled off screen.
            .onChange(of: activeLine) { _, index in
                withAnimation(Theme.softSpring) {
                    scroller.scrollTo(index, anchor: .center)
                }
            }
        }
        .navigationTitle(step.name)
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
        .task {
            if LaunchOptions.autoRecites {
                player.playAll(.reciter, urls: Recitations.clips(step: step.id, reciter: reciter))
            }
        }
        .onDisappear { player.stop() }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            PositionMedallion(step: step, size: 108)
            StepBadge(order: step.order, size: 12)

            if step.repetitions > 1 {
                Text(loc.t("detail.repeat", step.repetitions))
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.sand))
            }

            if step.arabicLines.count > 1 {
                Text(loc.t("vocal.tap_hint"))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func text(_ lines: [String], _ index: Int) -> String? {
        guard index < lines.count, !lines[index].isEmpty else { return nil }
        return lines[index]
    }
}

// MARK: - Line

/// A single line of the step, centred. Three states, and they say three
/// different things: sounding now, selected, and neither.
///
/// Two cursors can run over it, never at once (playing stops recording and
/// vice versa): the **gold** word is the one the reciter is saying, timed by
/// quran-align; the **green** words are the ones the phone has heard the user
/// say, straight from on-device speech recognition. Green marks position, not
/// correctness — the app does not grade recitation, here or anywhere.
private struct LineCard: View {
    let arabic: String
    let phonetic: String?
    let translation: String?
    let isActive: Bool
    let isSounding: Bool
    /// When each arabic word sounds, if this voice has timing data.
    var spans: [ClosedRange<Double>]?
    /// How many words of the line the user has been heard saying, if a
    /// recording with recognition is running on this line.
    var spokenWords: Int?

    @Environment(RecitationPlayer.self) private var player
    @Environment(\.loc) private var loc

    private var arabicWordCount: Int {
        arabic.split(separator: " ", omittingEmptySubsequences: true).count
    }

    var body: some View {
        Group {
            if spans != nil || spokenWords != nil {
                // The clock only ticks under a live cursor. AVAudioPlayer has
                // no per-word callback, so the view samples `player.time` a
                // few times a second while the line sounds.
                TimelineView(.periodic(from: .now, by: 0.08)) { _ in
                    content(arabicCursor: currentWord)
                }
            } else {
                content(arabicCursor: nil)
            }
        }
        .padding(.vertical, isActive ? 16 : 12)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        // The lit line is a gold plate; the others are the ordinary cream card.
        .plate(isActive ? Theme.goldSoft : Theme.surface,
               radius: Theme.Radius.card,
               depth: isActive ? 5 : 2)
        // Dimmed rather than greyed: the ink stays ink, so a line you have not
        // selected is still readable if you look at it on purpose.
        .opacity(isActive ? 1 : 0.72)
        .overlay(alignment: .topTrailing) {
            if isSounding {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .padding(10)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(loc.t("audio.listen"))
            } else if spokenWords != nil {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.green)
                    .padding(10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: isActive)
        .animation(Theme.spring, value: isSounding)
    }

    /// The reciter's word under the clock, or nil when nothing sounds.
    private var currentWord: Int? {
        guard isSounding, let spans else { return nil }
        return Karaoke.wordIndex(at: player.time, in: spans)
    }

    private func content(arabicCursor: Int?) -> some View {
        // Two different figures on purpose: the reciter's cursor is a single
        // moving gold word (a trail turned the whole line gold on the gold
        // plate and nothing stood out any more); the user's is cumulative
        // green — the words the phone has heard stay lit, because that is
        // the information.
        let userCount = spokenWords ?? 0
        let arabicActive = arabicCursor ?? (userCount > 0 ? userCount - 1 : nil)
        let tint = arabicCursor != nil ? Theme.gold : Theme.green
        let trail = arabicCursor != nil ? nil : Theme.green.opacity(0.55)

        return VStack(spacing: 8) {
            Karaoke.line(arabic, active: arabicActive, base: Theme.ink, tint: tint, saidTint: trail)
                .font(Theme.arabic(isActive ? 27 : 24))
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
                .lineSpacing(8)
                .frame(maxWidth: .infinity)

            if let phonetic {
                phoneticText(cursor: arabicActive)
                    .font(Theme.body(isActive ? 16 : 14).italic())
                    .multilineTextAlignment(.center)
            }

            if let translation, isActive {
                // The meaning only on the line being worked: shown on all of
                // them, it triples the height of the page and the eye stops
                // finding the Arabic.
                Text(translation)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }

    /// The phonetic cursor is the arabic one projected onto however many
    /// words the transliteration uses — a guide, not a measurement (see
    /// `Karaoke`), which is why it never runs without the arabic one.
    private func phoneticText(cursor: Int?) -> Text {
        guard let phonetic else { return Text(verbatim: "") }
        let base = isActive ? Theme.ink : Theme.gold
        guard let cursor else {
            return Text(phonetic).foregroundColor(base)
        }
        let count = phonetic.split(separator: " ", omittingEmptySubsequences: true).count
        let projected = Karaoke.projected(cursor, from: arabicWordCount, onto: count)
        let reciting = spokenWords == nil
        return Karaoke.line(phonetic, active: projected, base: base,
                            tint: reciting ? Theme.gold : Theme.green,
                            saidTint: reciting ? nil : Theme.green.opacity(0.55))
    }
}
