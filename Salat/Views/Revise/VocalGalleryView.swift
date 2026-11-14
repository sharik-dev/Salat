import SwiftUI

/// Which step do you want to work on? A grid rather than a list: the postures
/// are the thing you recognise, and fourteen names in a column all look alike.
///
/// Silent steps are left out — the niyyah is formed in the heart, and there is
/// nothing to say into a microphone.
struct VocalGalleryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(\.loc) private var loc

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    private var steps: [PrayerStep] { settings.steps.filter(\.spoken) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(steps) { step in
                        NavigationLink(value: ReviseRoute.step(step.id)) {
                            GalleryCard(step: step, recorded: recordedCount(step))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(loc.t("revise.tool.vocal.title"))
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
    }

    private var header: some View {
        Text(loc.t("revise.gallery.subtitle"))
            .font(Theme.rounded(15, .semibold))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How many lines of this step already have an attempt on disk. Read
    /// through `revision` so deleting a take updates the grid.
    private func recordedCount(_ step: PrayerStep) -> Int {
        _ = recorder.revision
        return (0..<step.arabicLines.count)
            .filter { VoiceRecorder.recording(step: step.id, line: $0) != nil }
            .count
    }
}

// MARK: - Card

private struct GalleryCard: View {
    let step: PrayerStep
    let recorded: Int

    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    private var hasReciter: Bool {
        Recitations.hasClips(step: step.id, reciter: Recitations.reciter(id: settings.reciterID))
    }

    var body: some View {
        VStack(spacing: 8) {
            PositionMedallion(step: step, size: 84)
                .overlay(alignment: .bottomTrailing) {
                    Text(String(step.order))
                        .font(Theme.rounded(12, .black).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Circle().fill(Theme.primary))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .offset(x: 2, y: 2)
                }

            Text(step.name)
                .font(Theme.rounded(15.5, .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity)

            // Two marks, two different facts: a voice exists to copy, and you
            // have already tried. Neither is a score.
            HStack(spacing: 6) {
                if hasReciter {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.gold)
                }
                if recorded > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11, weight: .black))
                        Text("\(recorded)")
                            .font(Theme.rounded(12, .black).monospacedDigit())
                    }
                    .foregroundStyle(Theme.green)
                }
            }
            .frame(height: 16)
        }
        .frame(maxWidth: .infinity)
        // A tile is narrow: the rim is what keeps a two-line step name from
        // ending flush against the outline.
        .card(radius: 22, padding: 12)
    }
}
