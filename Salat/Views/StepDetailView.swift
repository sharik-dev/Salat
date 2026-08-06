import SwiftUI

struct StepDetailView: View {
    let step: PrayerStep
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @Environment(\.dismiss) private var dismiss
    /// The verse the recitation panel is working on, when the step has several.
    @State private var recitationLine = 0

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            StarLattice().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    hero
                    section(loc.t("detail.posture"), icon: "figure.stand") {
                        Text(step.postureText)
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if step.spoken {
                        recitation
                        // The reciter, not the microphone: learning a step is
                        // hearing how it sounds. Recording yourself is a
                        // memorisation drill and belongs to *Revise*.
                        ReciterPanel(step: step, line: $recitationLine)
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
        .task { settings.noteStudied(step) }
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
                VStack(alignment: .leading, spacing: 10) {
                    Text(arabic)
                        .font(Theme.arabic(25))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .lineSpacing(8)

                    if let phonetic = line(step.phoneticLines, index), !phonetic.isEmpty {
                        Divider().background(Theme.border)
                        labelled(loc.t("detail.phonetic"), phonetic, italic: true, color: Theme.gold)
                    }

                    if let translation = line(step.translationLines, index), !translation.isEmpty {
                        Divider().background(Theme.border)
                        labelled(loc.t("detail.translation"), translation, italic: false, color: Theme.inkSoft)
                    }
                }
                .padding(16)
                .card()
            }
        }
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
