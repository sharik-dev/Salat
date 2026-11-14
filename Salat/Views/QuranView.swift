import SwiftUI

/// The *Qur'an* tab: the whole book as a feed, built like a short-video app.
///
/// One short screen at a time, full bleed: a picture behind, the verse in the
/// middle, the chosen reciter saying it, and when he is done the next screen
/// comes up by itself. On the side, the reader's own marks, as on any feed: a
/// heart, and a thread of notes that only they will ever read. The model is
/// Sharik's own `localShort` (glass buttons down the side, notes under a
/// video), asked for on 14/11/2026 after a first version that read like a
/// page of a book.
///
/// What holds the screen together:
///
/// - **A screen is short.** A verse of more than a few words is cut into
///   excerpts (`QuranExcerpt`), on the mushaf's own pause signs. Nothing is
///   dropped: the excerpts, in order, are the verse.
/// - **What is on screen is what is being recited.** The verse is one
///   recording; each excerpt plays its share of it and the sound runs through
///   the page turn without restarting. The basmala that opens a surah has its
///   own page, because the reciters' files keep it out of verse 1.
/// - **The voice follows the thumb.** A page reached by hand starts its own
///   excerpt; only an excerpt that ran to its end turns the page. With the
///   sound off nothing turns on its own.
/// - **A heart and a note belong to the verse**, not to the excerpt, and stay
///   on the phone (`QuranJournal`).
struct QuranView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @Environment(\.scenePhase) private var scenePhase

    @State private var player = QuranPlayer()
    @State private var journal = QuranJournal()
    @State private var position: Int?
    @State private var translation: QuranTranslation?
    @State private var showsSurahs = false
    @State private var showsReciters = false
    @State private var showsNotes = false
    @State private var showsSaved = false
    /// Bumped on every arrival: a page that was only passed through must not
    /// start reciting half a second after the thumb has moved on.
    @State private var arrival = 0
    /// The page the feed turned to by itself. Arriving there is not a new
    /// start: the verse's recording is already running.
    @State private var turnedTo: Int?
    /// The big heart thrown by a double tap.
    @State private var heartBurst = 0
    /// How far the page the feed is turning by itself has faded: the words
    /// only inside a verse, the picture too between two verses.
    @State private var turning: Turn = .still

    private enum Turn { case still, words, scene }

    private let quran = Quran.shared

    init() {
        guard let quran = Quran.shared else { return }
        let start = LaunchOptions.quranStart ?? QuranBookmark.load()
        _position = State(initialValue: quran.pageID(surah: start.surah, verse: start.verse))
    }

    private var reciter: Reciter? {
        Recitations.effectiveReciter(step: "fatiha",
                                     preferring: Recitations.reciter(id: settings.reciterID))
    }

    private var covered: Bool { showsSurahs || showsReciters || showsNotes || showsSaved }

    var body: some View {
        Group {
            if let quran {
                feed(quran)
            } else {
                Color.clear
            }
        }
        .background(Color(hex: 0x0F412B).ignoresSafeArea(edges: .top))
        .task(id: settings.resolvedLanguage) { await loadTranslation() }
        .task {
            QuranAudio.trim()
            Telemetry.shared.track("tool_open", props: ["tool": "quran"])
            if LaunchOptions.opensSurahs { showsSurahs = true }
            if LaunchOptions.opensQuranNotes { showsNotes = true }
            if LaunchOptions.opensQuranSaved { showsSaved = true }
        }
        .onAppear { arrive() }
        .onDisappear { player.stop() }
        .onChange(of: position) { _, _ in arrive() }
        .onChange(of: settings.quranMuted) { _, muted in
            if muted { player.stop() } else { arrive() }
        }
        .onChange(of: settings.reciterID) { _, _ in arrive() }
        // A sheet over the feed is a pause: the reciter must not keep turning
        // pages behind a list the reader is looking at.
        .onChange(of: covered) { _, covered in
            if covered { player.stop() } else { arrive() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { arrive() } else { player.stop() }
        }
        .sheet(isPresented: $showsSurahs) {
            if let quran {
                SurahPickerView(quran: quran, current: quran.page(position).surah) { surah in
                    showsSurahs = false
                    position = quran.pageID(surah: surah, verse: 0)
                }
                .localized(settings.localizer)
            }
        }
        .sheet(isPresented: $showsReciters) {
            ReciterPickerView()
                .localized(settings.localizer)
                .environment(settings)
        }
        .sheet(isPresented: $showsNotes) {
            if let quran {
                let page = quran.page(position)
                QuranNotesView(journal: journal,
                               ref: VerseRef(surah: page.surah, verse: page.verse),
                               title: reference(page, in: quran),
                               arabic: quran.verse(page))
                    .localized(settings.localizer)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showsSaved) {
            if let quran {
                QuranSavedView(journal: journal, quran: quran) { ref in
                    showsSaved = false
                    position = quran.pageID(surah: ref.surah, verse: ref.verse)
                }
                .localized(settings.localizer)
            }
        }
    }

    private func reference(_ page: QuranPage, in quran: Quran) -> String {
        "\(quran.surah(page.surah).latin) \(page.surah):\(page.verse)"
    }

    // MARK: Feed

    private func feed(_ quran: Quran) -> some View {
        let current = quran.page(position)
        return ZStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(quran.pages) { page in
                        QuranPageView(page: page,
                                      surah: quran.surah(page.surah),
                                      arabic: quran.arabic(page),
                                      basmala: quran.basmala,
                                      translation: translation?.text(page, weights: quran.weights(page)),
                                      faded: turning != .still)
                            .containerRelativeFrame(.vertical)
                            .contentShape(Rectangle())
                            // Two taps love the verse, one tap holds the voice:
                            // the two gestures every feed has taught.
                            .onTapGesture(count: 2) { love(page) }
                            .onTapGesture { player.togglePause() }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
            // Full bleed: the picture runs under the status bar.
            .ignoresSafeArea(edges: .top)

            // Between two verses the picture changes too: it is swapped under
            // a moment of dark, never seen jumping.
            Color.black
                .opacity(turning == .scene ? 0.82 : 0)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

            heart
            if player.state == .paused { pausedMark }
        }
        .overlay(alignment: .top) { topBar(quran.surah(current.surah), page: current) }
        .overlay(alignment: .bottom) { bottom(current, in: quran) }
        .accessibilityIdentifier("quran.feed")
    }

    // MARK: Top

    private func topBar(_ surah: Surah, page: QuranPage) -> some View {
        HStack(spacing: 10) {
            Button { showsSurahs = true } label: {
                HStack(spacing: 7) {
                    Text(verbatim: "\(surah.number). \(surah.latin)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .black))
                }
                .font(Theme.rounded(15, .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 42)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(QuranControlStyle())
            .accessibilityIdentifier("quran.surahs")
            // A reference always reads left to right.
            .environment(\.layoutDirection, .leftToRight)

            Spacer(minLength: 0)

            Button { settings.quranMuted.toggle() } label: {
                GlassCircle(size: 42) {
                    Image(systemName: settings.quranMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(QuranControlStyle())
            .accessibilityLabel(loc.t(settings.quranMuted ? "quran.sound.off" : "quran.sound.on"))
            .accessibilityIdentifier("quran.mute")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Bottom: who, where, and the reader's marks

    private func bottom(_ page: QuranPage, in quran: Quran) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                caption(page, in: quran)
                Spacer(minLength: 0)
                if !page.isOpening { actions(page, in: quran) }
            }
            .padding(.horizontal, 12)

            progressLine
        }
        .padding(.bottom, 10)
        .environment(\.colorScheme, .dark)
        .animation(Theme.spring, value: player.state)
    }

    /// Bottom left, where a feed names its author and its sound: the verse's
    /// reference, how far through a long verse this screen is, and the
    /// reciter, who is the "sound" and opens the list of voices.
    private func caption(_ page: QuranPage, in quran: Quran) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if player.state == .failed {
                HStack(spacing: 7) {
                    Image(systemName: "wifi.slash").font(.system(size: 12, weight: .black))
                    Text(loc.t("quran.offline"))
                        .font(Theme.rounded(12.5, .heavy))
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.goldSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity)
            }

            if !page.isOpening {
                Text(verbatim: reference(page, in: quran))
                    .font(Theme.rounded(16, .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                    .environment(\.layoutDirection, .leftToRight)

                if page.parts > 1 {
                    // One dash per excerpt, like the bars of a story.
                    HStack(spacing: 4) {
                        ForEach(0..<page.parts, id: \.self) { index in
                            Capsule()
                                .fill(.white.opacity(index <= page.part ? 0.95 : 0.32))
                                .frame(width: min(22, 150 / CGFloat(page.parts)), height: 4)
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityHidden(true)
                }
            }

            if let reciter {
                Button { showsReciters = true } label: {
                    HStack(spacing: 7) {
                        if player.state == .loading {
                            ProgressView().controlSize(.mini).tint(.white)
                        } else {
                            Image(systemName: "headphones")
                                .font(.system(size: 12, weight: .black))
                        }
                        Text(reciter.name)
                            .font(Theme.rounded(13, .heavy))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 32)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(QuranControlStyle())
                .accessibilityLabel(loc.t("audio.reciter"))
                .accessibilityIdentifier("quran.reciter")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Down the right side, as on every feed: love it, write on it, send it,
    /// and find again what was loved.
    private func actions(_ page: QuranPage, in quran: Quran) -> some View {
        let ref = VerseRef(surah: page.surah, verse: page.verse)
        let liked = journal.isLiked(ref)
        let notes = journal.notes(for: ref).count
        let marked = journal.marked.count

        return VStack(spacing: 14) {
            Button {
                Haptic.select.play()
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) { journal.toggleLike(ref) }
            } label: {
                ActionLabel(symbol: liked ? "heart.fill" : "heart",
                            tint: liked ? Color(hex: 0xFF4D5E) : .white, caption: nil)
                    .scaleEffect(liked ? 1.08 : 1)
            }
            .accessibilityLabel(loc.t("quran.like"))
            .accessibilityAddTraits(liked ? .isSelected : [])
            .accessibilityIdentifier("quran.like")

            Button { showsNotes = true } label: {
                ActionLabel(symbol: notes > 0 ? "bubble.left.fill" : "bubble.left",
                            tint: .white, caption: notes > 0 ? String(notes) : nil)
            }
            .accessibilityLabel(loc.t("quran.notes.title"))
            .accessibilityIdentifier("quran.notes")

            ShareLink(item: shareText(page, in: quran)) {
                ActionLabel(symbol: "arrowshape.turn.up.right.fill", tint: .white, caption: nil)
            }
            .accessibilityLabel(loc.t("quran.share"))

            Button { showsSaved = true } label: {
                ActionLabel(symbol: "bookmark.fill", tint: Theme.sparkFace,
                            caption: marked > 0 ? String(marked) : nil)
            }
            .accessibilityLabel(loc.t("quran.saved.title"))
            .accessibilityIdentifier("quran.saved")
        }
        .buttonStyle(QuranControlStyle())
    }

    private func shareText(_ page: QuranPage, in quran: Quran) -> String {
        var lines = [quran.verse(page)]
        if let meaning = translation?.text(page) { lines.append(meaning) }
        lines.append(reference(page, in: quran))
        return lines.joined(separator: "\n\n")
    }

    /// A hairline that fills while the excerpt sounds.
    private var progressLine: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            GeometryReader { geo in
                let sounding = player.state == .playing || player.state == .paused
                Capsule().fill(.white.opacity(sounding ? 0.22 : 0))
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white)
                            .frame(width: sounding ? max(geo.size.width * player.progress, 4) : 0)
                    }
            }
            .frame(height: 3)
            // Time runs left to right in every language.
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
    }

    // MARK: Heart and pause

    private func love(_ page: QuranPage) {
        guard !page.isOpening else { return }
        Haptic.win.play()
        withAnimation(.spring(duration: 0.3, bounce: 0.5)) {
            journal.like(VerseRef(surah: page.surah, verse: page.verse))
        }
        heartBurst += 1
    }

    private var heart: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 110, weight: .black))
            .foregroundStyle(Color(hex: 0xFF4D5E))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .keyframeAnimator(initialValue: HeartFrame(), trigger: heartBurst) { view, frame in
                view.scaleEffect(frame.scale).opacity(frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.15, duration: 0.22, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.2)
                    CubicKeyframe(1.35, duration: 0.3)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.08)
                    LinearKeyframe(1, duration: 0.4)
                    LinearKeyframe(0, duration: 0.24)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct HeartFrame {
        var scale = 0.3
        var opacity = 0.0
    }

    private var pausedMark: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 54, weight: .black))
            .foregroundStyle(.white.opacity(0.85))
            .padding(26)
            .background(.ultraThinMaterial, in: Circle())
            .environment(\.colorScheme, .dark)
            .transition(.scale.combined(with: .opacity))
            .allowsHitTesting(false)
    }

    // MARK: Flow

    private func loadTranslation() async {
        let code = settings.resolvedLanguage.rawValue
        translation = await Task.detached(priority: .userInitiated) {
            QuranTranslation.load(code: code)
        }.value
    }

    /// Called whenever the page under the eye may have changed, or whenever
    /// something that decides whether it sounds has. Remembers the place, then
    /// starts the excerpt a moment later, if the thumb has not moved on.
    private func arrive() {
        guard let quran else { return }
        let page = quran.page(position)
        QuranBookmark.save(page)
        arrival += 1
        let mine = arrival
        let audible = !settings.quranMuted && !covered && scenePhase == .active

        // The feed turned this page itself, inside a verse that is still
        // sounding: the recording runs on, it is only told where to stop next.
        let running = turnedTo == page.id && !page.isOpening && !page.isFirstPart
            && player.isSounding(surah: page.surah, verse: page.verse)
        turnedTo = nil
        let next = { advance(from: page, token: mine) }
        let span = quran.span(page)

        if running, audible {
            player.carryOn(from: span.from, until: span.to, onFinish: next)
            return
        }

        player.stop()
        guard audible, let reciter else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            guard mine == arrival else { return }

            if page.isOpening {
                guard quran.surah(page.surah).hasBasmala else {
                    // Nothing is recited on this page (the Fatiha, where the
                    // basmala is verse 1, and at-Tawba): the title is read,
                    // then the page turns.
                    try? await Task.sleep(for: .seconds(1.6))
                    next()
                    return
                }
                // The basmala as the reciter says it: verse 1 of the Fatiha.
                player.play(reciter: reciter, surah: 1, verse: 1, onFinish: next)
            } else {
                player.play(reciter: reciter, surah: page.surah, verse: page.verse,
                            from: span.from, until: span.to, onFinish: next)
            }

            // The next verse, fetched while this one sounds.
            let following = quran.page(quran.pageID(surah: page.surah, verse: page.verse + 1))
            if following.verse == page.verse + 1 {
                player.prefetch(reciter: reciter, surah: following.surah, verse: following.verse)
            }
        }
    }

    /// The excerpt ran to its end: the next page. Straight on inside a verse
    /// (the voice has not stopped), after a breath between two verses. Only if
    /// the reader is still on that page.
    ///
    /// The page is **swapped, not scrolled**: the words fade out, the feed
    /// jumps, the words fade in. An animated scroll of a lazy stack drops the
    /// page it is leaving before the next one is drawn, and the reader saw a
    /// blank screen in the middle of a verse. Inside a verse the picture is the
    /// same on both pages, so only the words change, which is what a verse
    /// running on should look like anyway.
    private func advance(from page: QuranPage, token: Int) {
        guard let quran, token == arrival, position == page.id,
              page.id + 1 < quran.pages.count else { return }
        let following = quran.pages[page.id + 1]
        let sameVerse = following.surah == page.surah && following.verse == page.verse
        Task { @MainActor in
            if !sameVerse { try? await Task.sleep(for: .seconds(0.3)) }
            guard token == arrival, position == page.id else { return }
            withAnimation(.easeIn(duration: 0.16)) { turning = sameVerse ? .words : .scene }
            try? await Task.sleep(for: .seconds(0.18))
            if token == arrival, position == page.id {
                turnedTo = following.id
                position = following.id
                // One frame for the new page to be laid out before it shows.
                try? await Task.sleep(for: .seconds(0.06))
            }
            withAnimation(.easeOut(duration: 0.3)) { turning = .still }
        }
    }
}

// MARK: - Furniture

/// The controls dip a little under the finger.
private struct QuranControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, down in if down { Haptic.tap.play() } }
    }
}

/// A round pane of glass: over a photograph, a white button would be a hole in
/// the picture.
private struct GlassCircle<Content: View>: View {
    let size: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1))
    }
}

/// One button of the side column: a glass disc, and under it a count when
/// there is something to count.
private struct ActionLabel: View {
    let symbol: String
    let tint: Color
    let caption: String?

    var body: some View {
        VStack(spacing: 3) {
            GlassCircle(size: 46) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(caption ?? " ")
                .font(Theme.rounded(11.5, .black).monospacedDigit())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .opacity(caption == nil ? 0 : 1)
                .frame(height: 12)
        }
    }
}

// MARK: - Backgrounds

/// The pictures behind the verses: mosques at night, a prayer hall, lanterns,
/// tiles. Real photographs, picked by hand (see `QURAN_BACKGROUNDS.md` for
/// where they come from and what is not settled about them), with no living
/// being in any of them, and darkened so white text reads on all of them.
///
/// They are found by name (`quranbg_*.jpg`) rather than listed: dropping a
/// picture in `Salat/Resources/backgrounds/` adds it to the rotation.
enum QuranBackground {
    static let urls: [URL] = (Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? [])
        .filter { $0.lastPathComponent.hasPrefix("quranbg_") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    private static let cache = NSCache<NSNumber, UIImage>()

    /// Every excerpt of a verse shares its picture (the eye should not be
    /// asked to change scenery mid-sentence); two verses in a row never do.
    static func index(for page: QuranPage, among count: Int) -> Int {
        guard count > 0 else { return 0 }
        let step = count > 3 ? 3 : 1
        return (page.surah * 7 + page.verse * step) % count
    }

    static func image(for page: QuranPage) -> UIImage? {
        guard !urls.isEmpty else { return nil }
        let index = index(for: page, among: urls.count)
        if let cached = cache.object(forKey: NSNumber(value: index)) { return cached }
        guard let image = UIImage(contentsOfFile: urls[index].path) else { return nil }
        cache.setObject(image, forKey: NSNumber(value: index))
        return image
    }

    /// What stands in when no picture shipped: the floor, as everywhere in
    /// this app, is something that still works.
    static let gradients: [[Color]] = [
        [Color(hex: 0x248657), Color(hex: 0x0F412B)],
        [Color(hex: 0x1D4E6B), Color(hex: 0x0B1F33)],
        [Color(hex: 0x5A3E7A), Color(hex: 0x1B1233)],
        [Color(hex: 0x8A5A2B), Color(hex: 0x2B1708)],
        [Color(hex: 0x1F6F6B), Color(hex: 0x0A2A2E)]
    ]
}

private struct QuranBackdrop: View {
    let page: QuranPage

    var body: some View {
        ZStack {
            if let image = QuranBackground.image(for: page) {
                Color.black
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            // Pictures from many hands, pulled a little
                            // towards one palette.
                            .saturation(0.82)
                    }
                    .clipped()
            } else {
                let colors = QuranBackground.gradients[
                    QuranBackground.index(for: page, among: QuranBackground.gradients.count)]
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                StarLattice(spacing: 70, opacity: 0.07, color: .white)
            }

            // The dark filter Sharik asked for: it keeps the eye on the verse
            // rather than on the picture, and gives every picture, bright or
            // not, the same weight. Heavier still where the controls sit.
            Color.black.opacity(0.46)
            LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0),
                                   .init(color: .clear, location: 0.22),
                                   .init(color: .clear, location: 0.6),
                                   .init(color: .black.opacity(0.72), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - One page

private struct QuranPageView: View {
    let page: QuranPage
    let surah: Surah
    let arabic: String
    let basmala: String
    let translation: String?
    /// True while the feed is turning the page by itself.
    var faded = false

    @Environment(\.loc) private var loc

    /// The sizes an excerpt is tried at, largest first: (arabic, translation).
    /// Excerpts are short, so the ladder is too; the last rung shrinks as a
    /// block rather than clip.
    private static let sizes: [(CGFloat, CGFloat)] = [
        (33, 18), (29, 17), (25.5, 15.5), (22, 14.5), (19.5, 13.5)
    ]

    var body: some View {
        Group {
            if page.isOpening {
                opening
            } else {
                ViewThatFits(in: .vertical) {
                    verse(Self.sizes[0])
                    verse(Self.sizes[1])
                    verse(Self.sizes[2])
                    verse(Self.sizes[3])
                    verse(Self.sizes[4], fixed: false)
                }
            }
        }
        .opacity(faded ? 0 : 1)
        // The side column and its mirror: the text stays centred on screen.
        .padding(.horizontal, page.isOpening ? 28 : 68)
        // Room for the status bar and the top bar above, the caption below.
        .padding(.top, 116)
        .padding(.bottom, 128)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { QuranBackdrop(page: page) }
        .clipped()
    }

    private func verse(_ size: (CGFloat, CGFloat), fixed: Bool = true) -> some View {
        VStack(spacing: size.0 * 0.5) {
            VerseBadge(number: page.verse, size: 40)

            Text(arabic)
                .font(Theme.arabic(size.0))
                .lineSpacing(size.0 * 0.42)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
                .minimumScaleFactor(fixed ? 1 : 0.5)
                .fixedSize(horizontal: false, vertical: fixed)

            if let translation, !translation.isEmpty {
                Text(translation)
                    .font(Theme.rounded(size.1, .heavy))
                    .lineSpacing(size.1 * 0.14)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(fixed ? 1 : 0.5)
                    .fixedSize(horizontal: false, vertical: fixed)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 20)
        // What is to be read stands on its own dark pane: on a photograph,
        // text laid straight on the picture competes with it, and the picture
        // wins. The pane is the one thing on the screen that is not scenery.
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                )
        }
        .accessibilityElement(children: .combine)
    }

    /// A surah's first page: its name, how long it is, and the basmala the
    /// reciter opens it with.
    private var opening: some View {
        VStack(spacing: 14) {
            LofiIcon(.quran, size: 112, interval: 3)

            Text(surah.name)
                .font(Theme.arabic(34))
                .foregroundStyle(.white)
                .environment(\.layoutDirection, .rightToLeft)

            Text(verbatim: "\(surah.number). \(surah.latin)")
                .font(Theme.title(26))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(loc.t("quran.verses", surah.verses))
                .font(Theme.rounded(14, .black))
                .foregroundStyle(Theme.primaryDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.white, in: Capsule())

            if surah.hasBasmala {
                Text(basmala)
                    .font(Theme.arabic(27))
                    .foregroundStyle(Theme.sparkFace)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.top, 16)
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 7, y: 2)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The verse's number in an eight-pointed star, the mark a mushaf closes a
/// verse with. Eight points, always: the khatam of the rest of the app.
private struct VerseBadge: View {
    let number: Int
    let size: CGFloat

    var body: some View {
        Text(String(number))
            .font(Theme.rounded(size * (number > 99 ? 0.3 : 0.36), .black).monospacedDigit())
            .foregroundStyle(Theme.ink)
            .frame(width: size, height: size)
            .background(EightPointStar().fill(Theme.sparkFace))
            .accessibilityHidden(true)
    }
}

// MARK: - Surah list

/// The 114 surahs. A sheet, like every list chosen from once in a while.
struct SurahPickerView: View {
    let quran: Quran
    let current: Int
    let pick: (Int) -> Void

    @Environment(\.loc) private var loc

    var body: some View {
        ScrollViewReader { scroller in
            SheetScaffold(title: loc.t("quran.surahs"), icon: .quran) {
                LazyVStack(spacing: 10) {
                    ForEach(quran.surahs) { surah in
                        row(surah).id(surah.number)
                    }
                }
            }
            // Opens on the surah being read: finding al-Mulk again should not
            // mean scrolling past sixty-six others.
            .onAppear { scroller.scrollTo(current, anchor: .center) }
        }
    }

    private func row(_ surah: Surah) -> some View {
        let selected = surah.number == current
        return Button { pick(surah.number) } label: {
            HStack(spacing: 12) {
                Text(String(surah.number))
                    .font(Theme.rounded(14, .black).monospacedDigit())
                    .foregroundStyle(selected ? .white : Theme.primaryDeep)
                    .frame(width: 40, height: 40)
                    .background(selected ? Theme.primary : Theme.primarySoft, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(surah.latin)
                        .font(Theme.rounded(16.5, .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(loc.t("quran.verses", surah.verses))
                        .font(Theme.rounded(12.5, .heavy))
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer(minLength: 6)

                Text(surah.shortName)
                    .font(Theme.arabic(20))
                    .foregroundStyle(Theme.primaryDeep)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .chunky(selected ? Theme.primarySoft : Theme.surface, radius: 20, depth: 4, haptic: .select)
        .accessibilityIdentifier("quran.surah.\(surah.number)")
    }
}
