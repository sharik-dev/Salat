import SwiftUI

// MARK: - Gallery

/// Which step do you want to carry? The same grid as the vocal gallery, for
/// the same reason: the postures are what you recognise. Silent steps are
/// left out — there is nothing to recite from memory.
struct FadeGalleryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    private var steps: [PrayerStep] { settings.steps.filter(\.spoken) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("revise.gallery.subtitle"))
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(steps) { step in
                        NavigationLink(value: ReviseRoute.fadeStep(step.id)) {
                            FadeGalleryCard(step: step)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(loc.t("revise.tool.fade.title"))
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
    }
}

private struct FadeGalleryCard: View {
    let step: PrayerStep

    var body: some View {
        VStack(spacing: 8) {
            PositionMedallion(step: step, size: 78)
            StepBadge(order: step.order, size: 10)
            Text(step.name)
                .font(Theme.title(15))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .card(radius: 18, padding: 12)
    }
}

// MARK: - The step, fading

/// The memorisation ladder: the whole step on screen, and one button that
/// hides a few more words each time. You recite aloud at every rung; the last
/// rung shows nothing, and that recitation is the one that counts. The plan
/// (`Fade.hiddenWords`) is deterministic, so climbing back down re-reveals
/// exactly the words that vanished.
struct FadeStepView: View {
    let step: PrayerStep

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    @State private var level = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        PositionMedallion(step: step, size: 62)
                        Text(loc.t("fade.hint"))
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    ForEach(step.arabicLines.indices, id: \.self) { i in
                        lineCard(i)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)

            actionBar
        }
        .animation(Theme.spring, value: level)
        .navigationTitle(step.name)
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
        .preference(key: TabBarHiddenKey.self, value: true)
        .task {
            #if DEBUG
            // `-fadeLevel 2` — arrive with words already hidden; the rungs
            // are the picture, and nobody is here to climb before the shot.
            if let rung = LaunchOptions.fadeLevel {
                level = min(max(rung, 0), Fade.levels - 1)
            }
            #endif
        }
    }

    // MARK: One line

    /// Arabic and reading fade together, each on its own word count; the
    /// meaning never fades — it is the prompt that names the line, not the
    /// thing being memorised.
    @ViewBuilder
    private func lineCard(_ i: Int) -> some View {
        let readings = step.readingLines
        let phonetic = readings != step.arabicLines

        VStack(alignment: .leading, spacing: 10) {
            masked(step.arabicLines[i], line: i)
                .font(Theme.arabic(24))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)

            if phonetic, readings.indices.contains(i) {
                masked(readings[i], line: i)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step.translationLines.indices.contains(i) {
                Text(step.translationLines[i])
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// A hidden word keeps its width — non-breaking spaces under a gold
    /// underline, the same slot the drill draws for a blank. Collapsing the
    /// word would reflow the line and lose the shape you are reciting over.
    private func masked(_ text: String, line: Int) -> Text {
        let words = text.split(separator: " ").map(String.init)
        let hidden = Fade.hiddenWords(stepID: step.id, lineIndex: line,
                                      wordCount: words.count, level: level)
        var out = Text("")
        for (i, word) in words.enumerated() {
            if i > 0 { out = out + Text(" ") }
            if hidden.contains(i) {
                out = out + Text(String(repeating: "\u{00A0}",
                                        count: max(word.count, 2)))
                    .underline(true, color: Theme.gold)
            } else {
                out = out + Text(word)
            }
        }
        return out
    }

    // MARK: The action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Text("\(level)/\(Fade.levels - 1)")
                .font(Theme.pixel(14))
                .foregroundStyle(Theme.gold)

            Button {
                climb(by: 1)
            } label: {
                Text(loc.t(level < Fade.levels - 1 ? "fade.hide" : "fade.show"))
                    .font(Theme.label(15))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .chunky(Theme.goldSoft, radius: 16, haptic: .press, sparks: false)
            .accessibilityIdentifier("fade.step")

            Button {
                climb(by: -1)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
            }
            .chunky(Theme.surface, radius: 16, haptic: .select, sparks: false)
            .disabled(level == 0)
            .opacity(level == 0 ? 0.55 : 1)
            .accessibilityIdentifier("fade.back")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.bar,
                                   topTrailingRadius: Theme.Radius.bar,
                                   style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.bar,
                                           topTrailingRadius: Theme.Radius.bar,
                                           style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: Theme.stroke)
                )
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Climbing the ladder is working the step — the first hidden word makes
    /// this a recitation from memory, and that is a study session. The wrap
    /// from the top rung goes back to everything shown.
    private func climb(by delta: Int) {
        if delta > 0, level >= Fade.levels - 1 {
            level = 0
            return
        }
        let next = level + delta
        guard (0..<Fade.levels).contains(next) else { return }
        if next == 1, level == 0 { settings.noteStudied(step) }
        level = next
    }
}
