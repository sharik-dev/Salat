import SwiftUI

struct StepDetailView: View {
    let step: PrayerStep
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @Environment(\.dismiss) private var dismiss

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
                    learnedButton
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
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

    // MARK: Learned

    private var learnedButton: some View {
        let isLearned = settings.isLearned(step)
        return Button {
            withAnimation(Theme.spring) { settings.toggleLearned(step) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isLearned ? "checkmark.seal.fill" : "seal")
                Text(isLearned ? loc.t("detail.unmark") : loc.t("detail.mark"))
            }
            .font(Theme.label(14))
            .foregroundStyle(isLearned ? Theme.paper : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        // Learning a step is the one thing in the app worth a fanfare.
        .chunky(isLearned ? Theme.green : Theme.goldSoft,
                radius: 16,
                haptic: isLearned ? .tap : .win)
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
