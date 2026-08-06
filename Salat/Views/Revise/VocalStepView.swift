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

    @Environment(RecitationPlayer.self) private var player
    @Environment(\.loc) private var loc

    /// The line under work. Shared with the panel below, so choosing a verse
    /// there lights it up here.
    @State private var line = 0

    /// What is sounding right now, if anything. Playback wins over the
    /// selection: the ear leads, the finger follows.
    private var activeLine: Int {
        player.isPlaying ? (player.line ?? line) : line
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: 16) {
                    hero

                    VStack(spacing: 10) {
                        ForEach(Array(step.arabicLines.enumerated()), id: \.offset) { index, arabic in
                            LineCard(
                                arabic: arabic,
                                phonetic: text(step.phoneticLines, index),
                                translation: text(step.translationLines, index),
                                isActive: index == activeLine,
                                isSounding: player.isPlaying && index == activeLine
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation(Theme.spring) { line = index }
                                Haptic.select.play()
                            }
                        }
                    }

                    // Listen first, say it after: the model sits above the
                    // microphone, in that order, because that is the order of
                    // the gesture.
                    ReciterPanel(step: step, line: $line, marksRecordings: true)
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
private struct LineCard: View {
    let arabic: String
    let phonetic: String?
    let translation: String?
    let isActive: Bool
    let isSounding: Bool

    @Environment(\.loc) private var loc

    var body: some View {
        VStack(spacing: 8) {
            Text(arabic)
                .font(Theme.arabic(isActive ? 27 : 24))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
                .lineSpacing(8)
                .frame(maxWidth: .infinity)

            if let phonetic {
                Text(phonetic)
                    .font(Theme.body(isActive ? 16 : 14).italic())
                    .foregroundStyle(isActive ? Theme.ink : Theme.gold)
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
            }
        }
        .animation(Theme.spring, value: isActive)
        .animation(Theme.spring, value: isSounding)
    }
}
