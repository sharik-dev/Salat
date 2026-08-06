import WidgetKit
import SwiftUI

/// The widget's presentation lives in the kit, not in the extension: the app
/// renders the very same views in a debug screen, so what gets reviewed is
/// literally what iOS will draw.

// MARK: - Entry

public struct CarouselEntry: TimelineEntry {
    public let date: Date
    public let step: PrayerStep
    public let position: Int
    public let total: Int
    public let localizer: Localizer

    public init(date: Date, step: PrayerStep, position: Int, total: Int, localizer: Localizer) {
        self.date = date
        self.step = step
        self.position = position
        self.total = total
        self.localizer = localizer
    }
}

public struct CarouselWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    public let entry: CarouselEntry

    /// WidgetKit supplies the family through the environment, and that
    /// environment value is read-only — so the debug preview inside the app
    /// passes the family in directly instead.
    private let forcedFamily: WidgetFamily?

    public init(entry: CarouselEntry, family: WidgetFamily? = nil) {
        self.entry = entry
        self.forcedFamily = family
    }

    private var family: WidgetFamily { forcedFamily ?? environmentFamily }

    public var body: some View {
        Group {
            switch family {
            case .systemSmall:         small
            case .systemLarge:         large
            case .accessoryRectangular: accessory
            default:                   medium
            }
        }
        .localized(entry.localizer)
        .containerBackground(for: .widget) {
            ZStack {
                Theme.paper
                StarLattice(spacing: 46, opacity: 0.09)
            }
        }
    }

    // MARK: Small — the position and its name, nothing else

    private var small: some View {
        VStack(spacing: 6) {
            PositionMedallion(step: entry.step, size: 74)
            Text(entry.step.name)
                .font(Theme.title(13))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            counter
        }
    }

    // MARK: Medium — position, how to say it, what it means

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(spacing: 5) {
                PositionMedallion(step: entry.step, size: 76)
                counter
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.step.name)
                    .font(Theme.title(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                if entry.step.spoken {
                    Text(entry.step.arabicLines[0])
                        .font(Theme.arabic(17))
                        .foregroundStyle(Theme.ink)
                        .environment(\.layoutDirection, .rightToLeft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(entry.step.phoneticLines[0])
                        .font(Theme.body(12).italic())
                        .foregroundStyle(Theme.gold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Text(entry.step.translationLines[0])
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Large — the full step, the way it reads in the app

    private var large: some View {
        VStack(spacing: 9) {
            PositionMedallion(step: entry.step, size: 104)

            Text(entry.step.name)
                .font(Theme.title(19))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            if entry.step.spoken {
                Text(entry.step.arabicLines[0])
                    .font(Theme.arabic(21))
                    .foregroundStyle(Theme.ink)
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(entry.step.phoneticLines[0])
                    .font(Theme.body(14).italic())
                    .foregroundStyle(Theme.gold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Divider().background(Theme.border).padding(.horizontal, 26)
            }

            Text(entry.step.translationLines[0])
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)

            counter
        }
    }

    // MARK: Lock screen

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.step.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(entry.step.spoken ? entry.step.phoneticLines[0] : entry.step.translationLines[0])
                .font(.system(size: 12))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var counter: some View {
        Text("\(entry.position) / \(entry.total)")
            .font(Theme.pixel(10))
            .foregroundStyle(Theme.gold)
    }
}

