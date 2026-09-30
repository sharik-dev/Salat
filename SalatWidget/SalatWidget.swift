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
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CarouselEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarouselEntry>) -> Void) {
        let now = Date()
        let entries = (0..<CarouselClock.horizon).map { offset in
            entry(at: now.addingTimeInterval(Double(offset) * CarouselClock.interval))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> CarouselEntry {
        let language = SharedStore.language
        let localizer = Localizer(language: language)
        let steps = PrayerContent.steps(for: language)
        let prefs = WidgetPrefs.load()

        guard let slot = CarouselPlan.slot(at: date, steps: steps,
                                           log: StudyLog.load(), prefs: prefs) else {
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

// MARK: - Declaration

struct SalatCarouselWidget: Widget {
    let kind = "SalatCarouselWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarouselProvider()) { entry in
            CarouselWidgetView(entry: entry)
        }
        .configurationDisplayName("Salat")
        .description("The positions of the prayer, one after another.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

@main
struct SalatWidgetBundle: WidgetBundle {
    var body: some Widget {
        SalatCarouselWidget()
    }
}
