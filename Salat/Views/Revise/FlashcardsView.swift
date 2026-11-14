import SwiftUI

/// The deck: one line per card, the meaning up front, the words on the back.
/// This is recall, not recognition — the drill already asks "which of these
/// four"; here nothing is offered, you say the line and then turn the card to
/// see whether you were right. The verdict is yours: no answer is checked,
/// so nothing here writes into `DrillLog` — a self-report is not a score.
///
/// A card judged "not yet" goes back under the deck and comes up again; the
/// sitting ends when every card has left on "I knew it".
struct FlashcardsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    @State private var deck: [Flashcard] = []
    /// How many cards the sitting started with — the denominator of the
    /// counter. `deck.count` shrinks as cards leave, and grows back when a
    /// missed card is re-buried.
    @State private var dealt = 0
    @State private var revealed = false
    @State private var seed = UInt64(Date().timeIntervalSince1970)

    private var pool: Set<String> { settings.learned.union(settings.learningNow) }

    var body: some View {
        content
            .navigationTitle(loc.t("revise.tool.flash.title"))
            .navigationBarTitleDisplayMode(.inline)
            .paperToolbar()
            .preference(key: TabBarHiddenKey.self, value: !deck.isEmpty)
            .task { deal() }
    }

    @ViewBuilder
    private var content: some View {
        if dealt == 0 {
            ScrollView { emptyState.padding(18) }
                .scrollIndicators(.hidden)
        } else if deck.isEmpty {
            summary
        } else {
            sitting(deck[0])
        }
    }

    // MARK: The sitting

    private func sitting(_ card: Flashcard) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ProgressBar(value: Double(dealt - deck.count), total: Double(dealt))
                    .frame(height: 14)
                Text("\(dealt - deck.count)/\(dealt)")
                    .font(Theme.rounded(14, .black).monospacedDigit())
                    .foregroundStyle(Theme.primaryDeep)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                cardFace(card)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)

            actionBar
        }
        .animation(Theme.spring, value: revealed)
        .animation(Theme.spring, value: deck)
    }

    /// The front asks, the back answers. Turning the card is a tap anywhere
    /// on it — the wide button below does the same, so the gesture cannot be
    /// missed.
    private func cardFace(_ card: Flashcard) -> some View {
        Button {
            if !revealed { reveal() }
        } label: {
            VStack(spacing: 18) {
                Text(card.meaning)
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if revealed {
                    Rectangle()
                        .fill(Theme.gold.opacity(0.6))
                        .frame(height: 1.5)
                        .frame(maxWidth: 120)

                    Text(card.arabic)
                        .font(Theme.arabic(28))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .environment(\.layoutDirection, .rightToLeft)

                    if let reading = card.reading {
                        Text(reading)
                            .font(Theme.body(16))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    LofiIcon(.cards, size: 84, interval: 3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityIdentifier("flash.card")
    }

    // MARK: The action bar

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            if revealed {
                HStack(spacing: 10) {
                    Button {
                        again()
                    } label: {
                        Text(loc.t("flash.again"))
                    }
                    .buttonStyle(.cta(.secondary, haptic: .select))
                    .accessibilityIdentifier("flash.again")

                    Button {
                        knew()
                    } label: {
                        Text(loc.t("flash.know"))
                    }
                    .buttonStyle(.cta(.primary, haptic: .press))
                    .accessibilityIdentifier("flash.know")
                }
            } else {
                Button {
                    reveal()
                } label: {
                    Text(loc.t("flash.reveal"))
                }
                .buttonStyle(.cta(.primary, haptic: .press))
                .accessibilityIdentifier("flash.reveal")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(alignment: .top) {
            Theme.surface
                .overlay(alignment: .top) { Theme.line.frame(height: 2.5) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Flow

    private func deal() {
        deck = Flashcards.deck(steps: settings.steps, pool: pool, seed: seed)
        dealt = deck.count
        revealed = false
    }

    private func reveal() {
        revealed = true
        Haptic.select.play()
    }

    /// Working a card is studying its step, whichever way it is judged —
    /// the same journal an answered drill question feeds.
    private func note(_ card: Flashcard) {
        if let step = settings.step(card.stepID) { settings.noteStudied(step) }
    }

    private func knew() {
        guard revealed, let card = deck.first else { return }
        note(card)
        deck.removeFirst()
        revealed = false
        if deck.isEmpty { Haptic.win.play() }
    }

    /// Back under the deck, not to the very next slot: seeing the same card
    /// twice in a row tests nothing but the last ten seconds.
    private func again() {
        guard revealed, let card = deck.first else { return }
        note(card)
        deck.removeFirst()
        deck.append(card)
        revealed = false
        Haptic.tap.play()
    }

    // MARK: Ends of the road

    private var summary: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                LofiIcon(.star, size: 128, interval: 1.6)
                Text(loc.t("flash.done.title"))
                    .font(Theme.title(24))
                    .foregroundStyle(Theme.ink)
                Text("\(dealt)")
                    .font(Theme.rounded(40, .black).monospacedDigit())
                    .foregroundStyle(Theme.primary)
                Text(loc.t("flash.done.body"))
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .card()
            .accessibilityIdentifier("flash.summary")
            Spacer()
            Button {
                seed &+= 0x9E37
                deal()
            } label: {
                Text(loc.t("flash.restart"))
            }
            .buttonStyle(.cta(.primary, haptic: .press))
            .accessibilityIdentifier("flash.restart")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        Text(loc.t("drill.empty"))
            .font(Theme.body(15))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityIdentifier("flash.empty")
    }
}
