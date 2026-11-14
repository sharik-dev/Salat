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
    private func trackListen(all: Bool) {
        Telemetry.shared.track("reciter_play", props: ["step": step.id,
                                                      "reciter": reciter?.id ?? "none",
                                                      "all": all ? "yes" : "no"])
    }

    private var clip: URL? { Recitations.clip(step: step.id, line: line, reciter: reciter) }
    /// The voices this step can be heard in — what the menu offers. One entry
    /// means there is no choice to make, so no menu is shown.
    private var choices: [Reciter] { Recitations.reciters(covering: step.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if hasClips {
                if clipCount > 1 { lineChips }
                listenRow
            } else {
                Text(loc.t(marksRecordings ? "audio.none" : "audio.none.listen"))
                    .font(Theme.rounded(14, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .onDisappear { player.stop() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(icon: .headphones, size: 46, animated: player.voice == .reciter)

            VStack(alignment: .leading, spacing: 1) {
                // "The reciter", not "Recitation": the panel below is a recitation
                // too, and two headers saying the same word teach nothing about
                // which is which.
                Text(loc.t("audio.reciter"))
                    .font(Theme.rounded(12.5, .black))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Theme.primaryDeep)

                if hasClips, let reciter {
                    if choices.count > 1 {
                        // A menu rather than a settings round-trip: switching
                        // voices is something you do while listening, not
                        // before. Only the voices that cover this step are
                        // offered.
                        Menu {
                            ForEach(choices) { candidate in
                                Button {
                                    settings.reciterID = candidate.id
                                    Haptic.select.play()
                                } label: {
                                    Label(
                                        // The style is part of the name here
                                        // too: the same reciter can appear
                                        // twice, once teaching and once at pace.
                                        candidate.name + " · " + loc.t(candidate.isTeaching ? "audio.style.teaching" : "audio.style.murattal"),
                                        systemImage: candidate.id == reciter.id ? "checkmark" : "person.wave.2"
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                name(reciter)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    } else {
                        // One voice covers this step: name it, offer no dead menu.
                        name(reciter)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func name(_ reciter: Reciter) -> some View {
        Text(reciter.name)
            .font(Theme.rounded(16, .heavy))
            .foregroundStyle(Theme.ink)
            // One line: a name wrapping onto two pushes the whole panel down.
            .lineLimit(1)
            .truncationMode(.tail)
    }

    // MARK: Verse picker

    private var lineChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(0..<clipCount, id: \.self) { index in
                    let isOn = index == line
                    Button {
                        player.stop()
                        withAnimation(Theme.spring) { line = index }
                    } label: {
                        Text("\(index + 1)")
                            .font(Theme.rounded(15, .black).monospacedDigit())
                            .foregroundStyle(isOn ? .white : Theme.inkSoft)
                            .frame(width: 38, height: 34)
                    }
                    .chunky(isOn ? Theme.primary : Theme.sand,
                            radius: 13, depth: isOn ? 4 : 0, haptic: .select)
                    .padding(.top, isOn ? 0 : 4)
                    .overlay(alignment: .topTrailing) {
                        if marksRecordings, VoiceRecorder.recording(step: step.id, line: index) != nil {
                            Circle().fill(Theme.gold)
                                .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                                .frame(width: 10, height: 10)
                                .offset(x: 3, y: isOn ? -3 : 1)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Listen

    private var listenRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                if player.voice == .reciter {
                    player.stop()
                } else if let clip {
                    player.play(.reciter, line: line, url: clip)
                    trackListen(all: false)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: player.voice == .reciter ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .black))
                    Text(loc.t("audio.listen"))
                }
            }
            .buttonStyle(.cta(.primary, height: 50))
            .accessibilityIdentifier("audio.listen")

            // One slow step, not a slider: below about 0.6× the pitch-corrected
            // recitation turns into a growl and stops being a model to copy.
            Button {
                player.rate = player.rate == 1 ? 0.6 : 1
            } label: {
                Text(player.rate == 1 ? "1×" : "0.6×")
                    .font(Theme.rounded(15, .black))
                    .foregroundStyle(player.rate == 1 ? Theme.inkSoft : Theme.goldDeep)
                    .frame(width: 54, height: 50)
            }
            .chunky(player.rate == 1 ? Theme.sand : Theme.goldSoft, radius: 18, depth: 6, haptic: .select)

            if clipCount > 1 {
                Button {
                    player.playAll(.reciter, urls: Recitations.clips(step: step.id, reciter: reciter))
                    trackListen(all: true)
                } label: {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Theme.primaryDeep)
                        .frame(width: 54, height: 50)
                }
                .chunky(Theme.primarySoft, radius: 18, depth: 6, haptic: .tap)
                .accessibilityLabel(loc.t("audio.all"))
            }
        }
    }
}
