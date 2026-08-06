#if DEBUG
import SwiftUI
import WidgetKit

/// Renders the real widget views at real widget sizes, inside the app.
///
///     xcrun simctl launch <udid> com.salat -startTab widgetPreview
///
/// The home screen cannot be screenshotted from the command line with a widget
/// installed, and Sharik reviews this project through screenshots. This shows
/// the same `CarouselWidgetView` iOS will draw, so a layout that overflows here
/// overflows there.
struct WidgetPreviewView: View {
    @Environment(AppSettings.self) private var settings
    @State private var tick = CarouselClock.tick(at: Date())

    // The canonical widget canvases on a 6.1" phone.
    private let sizes: [(String, CGSize, WidgetFamily)] = [
        ("small",  CGSize(width: 170, height: 170), .systemSmall),
        ("medium", CGSize(width: 364, height: 170), .systemMedium),
        ("large",  CGSize(width: 364, height: 382), .systemLarge)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Widget preview")
                    .font(Theme.title(26))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Stepper("Step \(entry.position) / \(entry.total)", value: $tick)
                    .font(Theme.label(12))

                ForEach(sizes, id: \.0) { name, size, family in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(name.uppercased())
                            .font(Theme.label(9))
                            .foregroundStyle(Theme.gold)
                        CarouselWidgetView(entry: entry, family: family)
                            .frame(width: size.width, height: size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                    }
                }

                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var entry: CarouselEntry {
        let steps = settings.steps
        let index = CarouselClock.index(tick: tick, count: steps.count)
        return CarouselEntry(date: Date(),
                             step: steps[index],
                             position: index + 1,
                             total: steps.count,
                             localizer: settings.localizer)
    }
}
#endif
