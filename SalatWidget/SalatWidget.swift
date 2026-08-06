import WidgetKit
import SwiftUI

// MARK: - Timeline

/// A widget cannot animate a carousel on its own — WidgetKit renders static
/// snapshots and iOS decides when to swap them. So the "carousel" is a
/// timeline: one entry per minute, each showing the next position, refilled
/// when it runs out. That is the fastest rotation the system actually honours;
/// asking for seconds would simply be ignored.
struct CarouselProvider: TimelineProvider {

    func placeholder(in context: Context) -> CarouselEntry {
        entry(at: 0, date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CarouselEntry) -> Void) {
        completion(entry(at: 1, date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarouselEntry>) -> Void) {
        let now = Date()
        let base = CarouselClock.tick(at: now)
        let entries = (0..<CarouselClock.horizon).map { offset in
            entry(at: base + offset,
                  date: now.addingTimeInterval(Double(offset) * CarouselClock.interval))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at tick: Int, date: Date) -> CarouselEntry {
        let language = SharedStore.language
        let steps = PrayerContent.steps(for: language)
        guard !steps.isEmpty else {
            let empty = PrayerStep(id: "", order: 0, image: "", posture: .standing,
                                   repetitions: 1, spoken: false, arabic: "",
                                   name: "", postureText: "", phonetic: "",
                                   translation: "", note: "")
            return CarouselEntry(date: date, step: empty, position: 0, total: 0,
                                 localizer: Localizer(language: language))
        }
        let index = CarouselClock.index(tick: tick, count: steps.count)
        return CarouselEntry(date: date,
                             step: steps[index],
                             position: index + 1,
                             total: steps.count,
                             localizer: Localizer(language: language))
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
