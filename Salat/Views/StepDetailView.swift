import SwiftUI

struct StepDetailView: View {
    let step: PrayerStep
    @Environment(AppSettings.self) private var settings
    @Environment(RecitationPlayer.self) private var player
    @Environment(\.loc) private var loc
    @Environment(\.dismiss) private var dismiss
    /// The verse the recitation panel is working on, when the step has several.
    @State private var recitationLine = 0

    /// Twelve of the fourteen steps are not Qur'an and have no recording. Here
    /// the panel simply stays away: in *Learn* the microphone is not offered
    /// either, so its "no recitation" line would be a sentence about nothing,
    /// sitting at the top of the page. *Memorise* still shows it, because there
    /// the sentence explains why there is nothing to copy.
    /// The voice this step actually plays in — the preferred reciter when he
    /// covers it, else the fallback voice (Hisn al-Muslim for the adhkar).
    private var stepReciter: Reciter? {
        Recitations.effectiveReciter(step: step.id,
                                     preferring: Recitations.reciter(id: settings.reciterID))
    }

    private var hasReciter: Bool {
        Recitations.hasClips(step: step.id, reciter: stepReciter)
    }

    /// The big moment, played over the sheet before it closes.
    @State private var celebrating = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    hero

                    VStack(spacing: 16) {
                        // Above the text, not under it. On the Fatiha the seven
                        // verse cards are a screen and a half: a listen button at
                        // the bottom of that is a button nobody ever finds, and
                        // hearing the words is the first thing to do, not the last.
                        if step.spoken, hasReciter {
                            ReciterPanel(step: step, line: $recitationLine)
                        }

                        section(loc.t("detail.posture")) {
                            Text(step.postureText)
                                .font(Theme.body(16))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if step.spoken {
                            recitation
                        } else {
                            section(loc.t("detail.translation")) {
                                Text(step.translation)
                                    .font(Theme.body(16))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        noteBlock
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)

            statusBar
        }
        .background(Theme.paper.ignoresSafeArea())
        // Opening the step *is* the study session — that is what the calendar
        // on the analytics page counts and what the reminders measure staleness
        // against. Ticking a box afterwards is an opinion; being here is a fact.
        .task {
            settings.noteStudied(step)
            Telemetry.shared.track("step_open", props: ["step": step.id])
            // Same flag as the vocal page: the cursor only exists while a
            // voice sounds, and nobody is here to press play for a screenshot.
            if LaunchOptions.autoRecites, step.spoken, hasReciter {
                player.playAll(.reciter, urls: Recitations.clips(step: step.id, reciter: stepReciter))
            }
            if LaunchOptions.celebrates { celebrating = true }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.primaryDeep)
                    .frame(width: 38, height: 38)
            }
            .chunky(Theme.surface, radius: 19, depth: 3)
            .padding(16)
            .accessibilityIdentifier("detail.close")
        }
        .overlay {
            if celebrating {
                CelebrationView(icon: settings.learned.count == settings.steps.count ? .trophy : .check,
                                title: step.name,
                                caption: loc.t("learn.learned")) {
                    celebrating = false
                    dismiss()
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: Hero

    /// The posture, large, on its own mint ground — the top of the sheet is the
    /// picture of what the body does, before a single word.
    private var hero: some View {
        VStack(spacing: 10) {
            PositionMedallion(step: step, size: 176, framed: false)

            HStack(spacing: 8) {
                StepBadge(order: step.order, size: 14, fill: .white)
                if step.repetitions > 1 {
                    Text(loc.t("detail.repeat", step.repetitions))
                        .font(Theme.rounded(12.5, .black))
                        .foregroundStyle(Theme.goldDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Theme.goldSoft))
                }
            }

            Text(step.name)
                .font(Theme.title(27))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Theme.primarySoft
                StarLattice(spacing: 62, opacity: 0.5, color: .white)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34,
                                              style: .continuous))
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Recitation — the heart of the screen

    /// Arabic, its pronunciation and its meaning are shown *line by line* so
    /// the eye can map one to the other. That mapping is the whole point; a
    /// single block of Arabic above a single block of translation teaches
    /// nothing.
    private var recitation: some View {
        VStack(spacing: 12) {
            ForEach(Array(step.arabicLines.enumerated()), id: \.offset) { index, arabic in
                recitationCard(index: index, arabic: arabic)
            }
        }
    }

    private func recitationCard(index: Int, arabic: String) -> some View {
        // The word cursor follows the voice here too: reading along while the
        // reciter says the words *is* the lesson of this screen.
        let sounding = player.voice == .reciter && player.line == index
        let spans = sounding
            ? Recitations.wordSpans(step: step.id, line: index, reciter: stepReciter)
            : nil

        return Group {
            if let spans {
                TimelineView(.periodic(from: .now, by: 0.08)) { _ in
                    recitationBody(index: index, arabic: arabic,
                                   cursor: Karaoke.wordIndex(at: player.time, in: spans))
                }
            } else {
                recitationBody(index: index, arabic: arabic, cursor: nil)
            }
        }
        .padding(Theme.cardPadding)
        // The line that sounds is the only one lit: a green rim, like a
        // selected answer.
        .plate(Theme.surface, stroke: sounding ? Theme.primary : nil)
        .animation(Theme.spring, value: sounding)
    }

    /// Three voices of the same line, told apart by their type rather than by
    /// three captions: the Arabic is large, the way to say it is heavy ink,
    /// what it means is quieter. The captions said it once per verse, seven
    /// times down the Fatiha.
    private func recitationBody(index: Int, arabic: String, cursor: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // One moving word, no trail: with a trail the whole line ends up
            // gold and the cursor stops being a cursor.
            Karaoke.line(arabic, active: cursor, base: Theme.ink, tint: Theme.gold)
                .font(Theme.arabic(26))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .lineSpacing(8)

            if let phonetic = line(step.phoneticLines, index), !phonetic.isEmpty {
                RowDivider()
                phoneticText(phonetic, arabic: arabic, cursor: cursor)
                    .font(Theme.rounded(17, .heavy))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let translation = line(step.translationLines, index), !translation.isEmpty {
                Text(translation)
                    .font(Theme.rounded(15, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The phonetic row, with the arabic cursor projected onto its words —
    /// a guide for the eye, not a measurement (see `Karaoke`).
    private func phoneticText(_ value: String, arabic: String, cursor: Int?) -> Text {
        guard let cursor else { return Text(value) }
        let arabicCount = arabic.split(separator: " ", omittingEmptySubsequences: true).count
        let count = value.split(separator: " ", omittingEmptySubsequences: true).count
        return Karaoke.line(value,
                            active: Karaoke.projected(cursor, from: arabicCount, onto: count),
                            base: Theme.ink, tint: Theme.gold)
    }

    /// Locale files may have fewer lines than the Arabic (a translator may
    /// merge two verses); pairing degrades instead of crashing.
    private func line(_ lines: [String], _ index: Int) -> String? {
        guard index < lines.count else { return nil }
        return lines[index]
    }

    // MARK: Note

    @ViewBuilder
    private var noteBlock: some View {
        if !step.note.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                LofiIcon(.lantern, size: 40, animated: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.t("detail.note"))
                        .font(Theme.rounded(12.5, .black))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Theme.goldDeep)
                    Text(step.note)
                        .font(Theme.rounded(14.5, .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plate(Theme.goldSoft, radius: 22)
        }
    }

    // MARK: Where the step stands

    /// Two answers, not one, and always within reach: the bar is pinned under
    /// the page instead of waiting at the bottom of seven verses. "I'm learning
    /// it" is the state most steps are actually in, and saying so out loud is
    /// what lets the app come back with the right one later.
    private var statusBar: some View {
        let status = settings.status(of: step)
        return HStack(spacing: 10) {
            Button {
                withAnimation(Theme.spring) { settings.setStatus(.learning, for: step) }
            } label: {
                HStack(spacing: 6) {
                    LofiIcon(.sprout, size: 28, animated: false)
                    Text(status == .learning ? loc.t("detail.learning.on") : loc.t("detail.learning"))
                }
            }
            // No fanfare here: starting is not finishing.
            .buttonStyle(.cta(status == .learning ? .gold : .secondary, height: 54, haptic: .select))
            .accessibilityIdentifier("detail.learning")

            Button {
                let wasKnown = status == .known
                withAnimation(Theme.spring) { settings.setStatus(.known, for: step) }
                // Marking a step acquired is an answer, not a setting: the screen
                // has nothing left to say, so it celebrates and steps aside — the
                // list then shows the badge and the bar moving. Un-marking is a
                // correction, not an answer: it stays, otherwise a mis-tap throws
                // the reader out of the step.
                if !wasKnown {
                    Nudges.shared.stepAcquired()
                    withAnimation(.easeOut(duration: 0.2)) { celebrating = true }
                }
            } label: {
                HStack(spacing: 6) {
                    if status == .known {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .black))
                    }
                    Text(status == .known ? loc.t("detail.unmark") : loc.t("detail.mark"))
                }
            }
            .buttonStyle(.cta(.primary, height: 54, haptic: status == .known ? .tap : .press))
            .accessibilityIdentifier("detail.known")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(alignment: .top) { Theme.line.frame(height: 2.5) }
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.rounded(12.5, .black))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Theme.primaryDeep)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
