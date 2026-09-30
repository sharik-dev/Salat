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

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            StarLattice().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    hero

                    // Above the text, not under it. On the Fatiha the seven
                    // verse cards are a screen and a half: a listen button at
                    // the bottom of that is a button nobody ever finds, and
                    // hearing the words is the first thing to do, not the last.
                    if step.spoken, hasReciter {
                        ReciterPanel(step: step, line: $recitationLine)
                    }

                    section(loc.t("detail.posture"), icon: "figure.stand") {
                        Text(step.postureText)
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if step.spoken {
                        recitation
                    } else {
                        section(loc.t("detail.translation"), icon: "heart.text.square") {
                            Text(step.translation)
                                .font(Theme.body(15))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    noteBlock
                    statusButtons
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
        }
        // Opening the step *is* the study session — that is what the calendar
        // on the analytics page counts and what the reminders measure staleness
        // against. Ticking a box afterwards is an opinion; being here is a fact.
        .task {
            settings.noteStudied(step)
            // Same flag as the vocal page: the cursor only exists while a
            // voice sounds, and nobody is here to press play for a screenshot.
            if LaunchOptions.autoRecites, step.spoken, hasReciter {
                player.playAll(.reciter, urls: Recitations.clips(step: step.id, reciter: stepReciter))
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
            }
            .chunky(Theme.sand, radius: 12, depth: 3)
            .padding(16)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 10) {
            PositionMedallion(step: step, size: 168)

            StepBadge(order: step.order, size: 14)

            Text(step.name)
                .font(Theme.title(26))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            if step.repetitions > 1 {
                Text(loc.t("detail.repeat", step.repetitions))
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.sand))
            }
        }
        .padding(.top, 10)
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
        .card()
    }

    private func recitationBody(index: Int, arabic: String, cursor: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // One moving word, no trail: with a trail the whole line ends up
            // gold and the cursor stops being a cursor.
            Karaoke.line(arabic, active: cursor, base: Theme.ink, tint: Theme.gold)
                .font(Theme.arabic(25))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .lineSpacing(8)

            if let phonetic = line(step.phoneticLines, index), !phonetic.isEmpty {
                Divider().background(Theme.border)
                labelledKaraoke(loc.t("detail.phonetic"), phonetic,
                                arabic: arabic, cursor: cursor)
            }

            if let translation = line(step.translationLines, index), !translation.isEmpty {
                Divider().background(Theme.border)
                labelled(loc.t("detail.translation"), translation, italic: false, color: Theme.inkSoft)
            }
        }
    }

    /// The phonetic row, with the arabic cursor projected onto its words —
    /// a guide for the eye, not a measurement (see `Karaoke`).
    private func labelledKaraoke(_ title: String, _ value: String,
                                 arabic: String, cursor: Int?) -> some View {
        let text: Text
        if let cursor {
            let arabicCount = arabic.split(separator: " ", omittingEmptySubsequences: true).count
            let count = value.split(separator: " ", omittingEmptySubsequences: true).count
            text = Karaoke.line(value,
                                active: Karaoke.projected(cursor, from: arabicCount, onto: count),
                                base: Theme.ink, tint: Theme.gold)
        } else {
            text = Text(value)
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(Theme.label(9))
                .foregroundStyle(Theme.gold)
                .tracking(0.8)
            text
                .font(Theme.body(16).italic())
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labelled(_ title: String, _ value: String, italic: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(Theme.label(9))
                .foregroundStyle(color)
                .tracking(0.8)
            Text(value)
                .font(italic ? Theme.body(16).italic() : Theme.body(15))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lamp.desk")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.t("detail.note").uppercased())
                        .font(Theme.label(9))
                        .foregroundStyle(Theme.gold)
                        .tracking(0.8)
                    Text(step.note)
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                    .fill(Theme.sand.opacity(0.6))
            )
        }
    }

    // MARK: Where the step stands

    /// Two answers, not one. "I'm learning it" is the state most steps are
    /// actually in, and saying so out loud is what lets the app come back with
    /// the right one later — a step nobody ever claimed is indistinguishable
    /// from a step nobody wants.
    private var statusButtons: some View {
        let status = settings.status(of: step)
        return VStack(spacing: 10) {
            Button {
                withAnimation(Theme.spring) { settings.setStatus(.learning, for: step) }
            } label: {
                statusLabel(icon: status == .learning ? "book.fill" : "book",
                            text: status == .learning ? loc.t("detail.learning.on")
                                                      : loc.t("detail.learning"),
                            filled: status == .learning)
            }
            // No fanfare here: starting is not finishing. The gold burst is kept
            // for the one moment that deserves it.
            .chunky(status == .learning ? Theme.gold : Theme.sand,
                    radius: 16, haptic: .select, sparks: false)

            Button {
                let wasKnown = status == .known
                withAnimation(Theme.spring) { settings.setStatus(.known, for: step) }
                // Marking a step acquired is an answer, not a setting: the screen
                // has nothing left to say, so it steps aside and the list shows
                // the seal and the progress bar moving. The delay is the burst's
                // own duration (0.6 s in `Plate`) — leaving before it plays would
                // swallow the one fanfare the app has. Un-marking is a correction,
                // not an answer: it stays, otherwise a mis-tap throws the reader
                // out of the step.
                if !wasKnown {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { dismiss() }
                }
            } label: {
                statusLabel(icon: status == .known ? "checkmark.seal.fill" : "seal",
                            text: status == .known ? loc.t("detail.unmark") : loc.t("detail.mark"),
                            filled: status == .known)
            }
            // Learning a step is the one thing in the app worth a fanfare.
            .chunky(status == .known ? Theme.green : Theme.goldSoft,
                    radius: 16,
                    haptic: status == .known ? .tap : .win)
        }
    }

    private func statusLabel(icon: String, text: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(Theme.label(14))
        .foregroundStyle(filled ? Theme.paper : Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private func section<Content: View>(_ title: String, icon: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title.uppercased()).font(Theme.label(9)).tracking(0.8)
            }
            .foregroundStyle(Theme.gold)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
