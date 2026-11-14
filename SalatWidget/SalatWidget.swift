import WidgetKit
import SwiftUI

// MARK: - Timeline

/// A widget cannot animate a carousel on its own — WidgetKit renders static
/// snapshots and iOS decides when to swap them. So the "carousel" is a
/// timeline: one entry per minute, each showing the next position, refilled
/// when it runs out. That is the fastest rotation the system actually honours;
/// asking for seconds would simply be ignored.
///
/// *Which* step each entry carries is `CarouselPlan`'s business, not this
/// file's: the cycle skips what the reader already knows, and holds on the step
/// they just read. That decision is a pure value so it can be tested.
struct CarouselProvider: TimelineProvider {

    func placeholder(in context: Context) -> CarouselEntry {
        Source().entry(at: Date(), unlocked: true)
    }

    /// The widget gallery is the one place the widget shows its content
    /// without a subscription: that is where it gets chosen, and a padlock
    /// there would be choosing blind.
    func getSnapshot(in context: Context, completion: @escaping (CarouselEntry) -> Void) {
        completion(Source().entry(at: Date(), unlocked: context.isPreview || Premium.isActive))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarouselEntry>) -> Void) {
        let now = Date()
        let source = Source()
        // Locked, there is nothing to rotate: one entry, and no refresh until
        // the app says the subscription changed (`Store` reloads the timelines).
        guard Premium.isActive else {
            completion(Timeline(entries: [source.entry(at: now, unlocked: false)], policy: .never))
            return
        }
        let entries = (0..<CarouselClock.horizon).map { offset in
            source.entry(at: now.addingTimeInterval(Double(offset) * CarouselClock.interval),
                         unlocked: true)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// Everything a timeline reads from the shared suite, read **once**: sixty
    /// entries that each decoded the reader's verses again would be sixty
    /// decodes of the same list.
    private struct Source {
        let localizer: Localizer
        let steps: [PrayerStep]
        let prefs = WidgetPrefs.load()
        let log = StudyLog.load()
        let verses: [WidgetVerse]

        init() {
            let language = SharedStore.language
            localizer = Localizer(language: language)
            steps = PrayerContent.steps(for: language)
            verses = prefs.scope == .quran ? QuranExcerpts.verses() : []
        }

        func entry(at date: Date, unlocked: Bool) -> CarouselEntry {
            // The widget is Salat Premium.
            guard unlocked else { return .locked(date: date, localizer: localizer) }

            // The reader's verses of the Qur'an, when that is what was asked
            // for and there is at least one. With none, the prayer below is
            // the fallback: a widget is never an empty card.
            if let slot = CarouselPlan.verseSlot(at: date, verses: verses) {
                return CarouselEntry(date: date, verse: slot.verse,
                                     position: slot.position, total: slot.total,
                                     localizer: localizer, focus: prefs.focus)
            }

            guard let slot = CarouselPlan.slot(at: date, steps: steps,
                                               log: log, prefs: prefs) else {
                let empty = PrayerStep(id: "", order: 0, image: "", posture: .standing,
                                       repetitions: 1, spoken: false, arabic: "",
                                       name: "", postureText: "", phonetic: "",
                                       translation: "", note: "")
                return CarouselEntry(date: date, step: empty, position: 0, total: 0,
                                     localizer: localizer)
            }
            return CarouselEntry(date: date,
                                 step: slot.step,
                                 position: slot.position,
                                 total: slot.total,
                                 localizer: localizer,
                                 focus: prefs.focus)
        }
    }
}

// MARK: - Declaration

struct SalatCarouselWidget: Widget {
    let kind = "SalatCarouselWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarouselProvider()) { entry in
            CarouselWidgetView(entry: entry)
        }
        .configurationDisplayName("Salat")
        .description("The steps of the prayer, or your verses of the Qur'an, one after another.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        // The green banner runs to the widget's edge; the view brings its own
        // margins. It also makes the in-app preview exact: that one never had
        // the system's margins around it.
        .contentMarginsDisabled()
    }
}

@main
struct SalatWidgetBundle: WidgetBundle {
    var body: some Widget {
        SalatCarouselWidget()
    }
}
