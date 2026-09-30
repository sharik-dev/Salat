import SwiftUI
import WidgetKit

/// The widget's page in the *Memorise* hall. The widget is a memorising tool —
/// it is what keeps the steps coming back between two sessions — so this is
/// where it is explained and where it is tuned. Two knobs, nothing more: which
/// steps rotate, and which text leads the card.
///
/// The preview at the top is the real `CarouselWidgetView`, fed by the same
/// `CarouselPlan` the extension uses: what changes under a tap here is what
/// the home screen will draw, not a mockup of it.
struct WidgetToolView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview
                howCard
                showCard
                focusCard
                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(loc.t("revise.tool.widget.title"))
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
    }

    // MARK: Preview

    /// The medium widget, drawn by the very view iOS will use, on the state the
    /// knobs below describe. Without it, "one step, always" is a sentence; with
    /// it, it is the card you will actually get.
    @ViewBuilder
    private var preview: some View {
        if let entry = previewEntry {
            CarouselWidgetView(entry: entry, family: .systemMedium, mode: .fullColor)
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: Theme.stroke)
                )
        }
    }

    private var previewEntry: CarouselEntry? {
        let now = Date()
        guard let slot = CarouselPlan.slot(at: now, steps: settings.steps,
                                           log: settings.log,
                                           prefs: settings.widgetPrefs) else { return nil }
        return CarouselEntry(date: now, step: slot.step,
                             position: slot.position, total: slot.total,
                             localizer: settings.localizer,
                             focus: settings.widgetFocus)
    }

    // MARK: How it works

    private var howCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("widget.how.title")
            Text(loc.t("widget.how.body"))
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text(loc.t("settings.widget.hint"))
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: What it shows

    private var showCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("widget.show.title")

            ForEach(WidgetScope.allCases, id: \.rawValue) { scope in
                optionRow(label: loc.t("widget.show.\(scope.rawValue)"),
                          selected: settings.widgetScope == scope) {
                    settings.widgetScope = scope
                    // Landing on "one step" with no pick yet would show a card
                    // the list below contradicts; the first step is the seed,
                    // never the decision.
                    if scope == .one && settings.widgetPinnedStep == nil {
                        settings.widgetPinnedStep = settings.steps.first?.id
                    }
                }
            }

            if settings.widgetScope == .one {
                stepChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityIdentifier("widget.show")
    }

    /// The fourteen steps as a ribbon of chips — a full list would push the
    /// focus card off screen for a pick made once.
    private var stepChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(settings.steps) { step in
                    let selected = settings.widgetPinnedStep == step.id
                    Button {
                        Haptic.select.play()
                        settings.widgetPinnedStep = step.id
                    } label: {
                        Text(step.name)
                            .font(Theme.label(12))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selected ? Theme.goldSoft : Theme.sand)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(selected ? Theme.ink : Theme.ink.opacity(0.25),
                                                          lineWidth: selected ? Theme.stroke : 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Which text leads

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("widget.focus.title")

            // The labels are the detail page's own headings: the widget leads
            // with one of the three texts every step page already names.
            ForEach(WidgetFocus.allCases, id: \.rawValue) { focus in
                optionRow(label: loc.t("detail.\(focus.rawValue)"),
                          selected: settings.widgetFocus == focus) {
                    settings.widgetFocus = focus
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityIdentifier("widget.focus")
    }

    // MARK: Furniture

    private func sectionTitle(_ key: String) -> some View {
        Text(loc.t(key))
            .font(Theme.label(11))
            .foregroundStyle(Theme.gold)
            .textCase(.uppercase)
    }

    private func optionRow(label: String, selected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button {
            Haptic.select.play()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Theme.gold : Theme.inkSoft)
                Text(label)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Theme.goldSoft : Theme.sand.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Theme.ink : Theme.ink.opacity(0.2),
                                          lineWidth: selected ? Theme.stroke : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
