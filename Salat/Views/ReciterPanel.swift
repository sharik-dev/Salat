import SwiftUI

/// The reciter's voice, and nothing else.
///
/// Hearing the model belongs to *learning* a step, not to drilling it: a
/// beginner needs the sound of the words long before they have anything to
/// record. So this panel sits in the step page of *Learn*, and again above the
/// microphone in *Revise* — you listen, then you say it. The recording half
/// lives in `RecitationPanel`, which is a memorisation tool and stays in
/// *Revise*.
struct ReciterPanel: View {
    let step: PrayerStep

    /// The verse being listened to. Owned by the screen, which lights that line
    /// up: two copies of this number would drift the moment either side moved.
    @Binding var line: Int

    /// The chips double as a map of what has already been recorded — true only
    /// where recording exists at all. In *Learn* there is no microphone, so a
    /// green dot there would point at nothing.
    var marksRecordings = false

    @Environment(AppSettings.self) private var settings
    @Environment(RecitationPlayer.self) private var player
    @Environment(\.loc) private var loc

    /// The voice heard on *this* step: the preferred one when it covers it,
    /// else whichever does — the adhkar live under the Hisn al-Muslim voice,
    /// and choosing Minshawy in the settings must not silence the tashahhud.
    private var reciter: Reciter? {
        Recitations.effectiveReciter(step: step.id,
                                     preferring: Recitations.reciter(id: settings.reciterID))
    }
    private var clipCount: Int { Recitations.lineCount(step: step.id, reciter: reciter) }
    private var hasClips: Bool { clipCount > 0 }
    private var clip: URL? { Recitations.clip(step: step.id, line: line, reciter: reciter) }
    /// The voices this step can be heard in — what the menu offers. One entry
    /// means there is no choice to make, so no menu is shown.
    private var choices: [Reciter] { Recitations.reciters(covering: step.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if hasClips {
                if clipCount > 1 { lineChips }
                listenRow
            } else {
                Text(loc.t(marksRecordings ? "audio.none" : "audio.none.listen"))
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .onDisappear { player.stop() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.wave.2")
                .font(.system(size: 11))
            // "The reciter", not "Recitation": the panel below is a recitation
            // too, and two headers saying the same word teach nothing about
            // which is which.
            Text(loc.t("audio.reciter").uppercased())
                .font(Theme.label(9))
                .tracking(0.8)
            Spacer()
            if hasClips, let reciter, choices.count > 1 {
                // A menu rather than a settings round-trip: switching voices is
                // something you do while listening, not before. Only the voices
                // that actually cover this step are offered.
                Menu {
                    ForEach(choices) { candidate in
                        Button {
                            settings.reciterID = candidate.id
                            Haptic.select.play()
                        } label: {
                            Label(
                                // The style is part of the name here too: the
                                // same reciter can appear twice, once teaching
                                // and once at pace.
                                candidate.name + " · " + loc.t(candidate.isTeaching ? "audio.style.teaching" : "audio.style.murattal"),
                                systemImage: candidate.id == reciter.id ? "checkmark" : "person.wave.2"
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(reciter.name)
                            .font(Theme.body(11))
                            // One line: a name wrapping onto two pushes the
                            // whole panel down and the header stops reading as
                            // a header.
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: 150, alignment: .trailing)
                }
            } else if hasClips, let reciter {
                // One voice covers this step: name it, offer no dead menu.
                Text(reciter.name)
                    .font(Theme.body(11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: 150, alignment: .trailing)
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
                    .overlay(alignment: .topTrailing) {
                        if marksRecordings, VoiceRecorder.recording(step: step.id, line: index) != nil {
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
            Button {
                if player.voice == .reciter {
                    player.stop()
                } else if let clip {
                    player.play(.reciter, line: line, url: clip)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: player.voice == .reciter ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(loc.t("audio.listen")).font(Theme.label(13))
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .chunky(Theme.goldSoft, radius: 12, depth: 3, haptic: .press, sparks: false)
            .accessibilityIdentifier("audio.listen")

            // One slow step, not a slider: below about 0.6× the pitch-corrected
            // recitation turns into a growl and stops being a model to copy.
            Button {
                player.rate = player.rate == 1 ? 0.6 : 1
                Haptic.select.play()
            } label: {
                // Not the pixel font: it has no "×" and the glyph came out as
                // an empty block next to the digit.
                Text(player.rate == 1 ? "1×" : "0.6×")
                    .font(Theme.label(12))
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
}
