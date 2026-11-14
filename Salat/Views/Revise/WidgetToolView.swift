import SwiftUI
import WidgetKit

/// The widget's page in the *Memorise* hall: what it looks like on the home
/// screen, one button to put it there, and its settings as three rows.
///
/// It used to be a preview, a card of explanation and two cards of radio rows,
/// seven choices spread over two screens for a thing set once. Each setting is
/// now one row that says its current value and opens a menu; the explanation
/// became the guide behind the button, with pictures instead of a paragraph.
///
/// The preview is the real `CarouselWidgetView`, fed by the same `CarouselPlan`
/// the extension uses: what changes under a tap here is what the home screen
/// will draw, not a mockup of it.
struct WidgetToolView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Store.self) private var store
    @Environment(\.loc) private var loc
    @State private var showsGuide = false
    @State private var showsExcerpts = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview

                // The widget on the home screen is Salat Premium. This page is
                // not: the preview and the settings stay open to everyone,
                // because seeing the widget with one's own content on it is
                // what makes it worth a subscription. Only the button changes.
                if store.isPremium {
                    Button { showsGuide = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .black))
                            Text(loc.t("widget.add"))
                        }
                    }
                    .buttonStyle(.cta(.primary, height: 58))
                    .accessibilityIdentifier("widget.add")
                } else {
                    Button { store.showsPaywall = true } label: {
                        HStack(spacing: 8) {
                            LofiIcon(.lock, size: 30, animated: false)
                            Text(loc.t("widget.unlock"))
                        }
                    }
                    .buttonStyle(.cta(.primary, height: 58))
                    .accessibilityIdentifier("widget.unlock")
                }

                settingsCard

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(loc.t("revise.tool.widget.title"))
        .navigationBarTitleDisplayMode(.inline)
        .paperToolbar()
        .task {
            if LaunchOptions.opensWidgetGuide { showsGuide = true }
            if LaunchOptions.opensExcerpts { showsExcerpts = true }
        }
        .sheet(isPresented: $showsExcerpts) {
            ExcerptPickerView()
                .localized(settings.localizer)
                .environment(settings)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsGuide) {
            WidgetGuideView(entry: previewEntry)
                .localized(settings.localizer)
                .environment(settings)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Preview

    /// The widget where it will live: on a home screen, between the status bar
    /// and a row of icons. On the page's own beige it read as one more card of
    /// the app; on a wallpaper it reads as what it is.
    @ViewBuilder
    private var preview: some View {
        if let entry = previewEntry {
            let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
            VStack(spacing: 10) {
                HomeScreenMock(entry: entry, rows: 1)
                    .aspectRatio(1.2, contentMode: .fit)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(Theme.primaryDeep, lineWidth: 3))
                    .background(shape.fill(Theme.primaryDeep).offset(y: 6))
                    .padding(.bottom, 6)
                    .animation(Theme.spring, value: entry.step.id)

                Text(loc.t(showsQuran ? "widget.quran.how" : "widget.how.body"))
                    .font(Theme.rounded(13.5, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .accessibilityIdentifier("widget.preview")
        }
    }

    private var previewEntry: CarouselEntry? { settings.widgetPreviewEntry() }

    /// The widget is on the Qur'an, not on the prayer.
    private var showsQuran: Bool { settings.widgetScope == .quran }

    /// A verse has no phonetic, so that choice leaves the menu while the
    /// widget is on the Qur'an, and a reader who had it reads the Arabic.
    private var focusOptions: [WidgetFocus] {
        showsQuran ? [.arabic, .translation] : WidgetFocus.allCases
    }

    private var shownFocus: WidgetFocus {
        showsQuran && settings.widgetFocus == .phonetic ? .arabic : settings.widgetFocus
    }

    // MARK: Settings

    private var settingsCard: some View {
        VStack(spacing: 0) {
            MenuRow(title: loc.t("widget.show.title"),
                    value: loc.t("widget.show.\(settings.widgetScope.rawValue)"),
                    options: WidgetScope.allCases.map { ($0, loc.t("widget.show.\($0.rawValue)")) },
                    selected: settings.widgetScope) { scope in
                withAnimation(Theme.spring) {
                    settings.widgetScope = scope
                    // Landing on "one step" with no pick yet would show a card
                    // the row below contradicts; the first step is the seed,
                    // never the decision.
                    if scope == .one && settings.widgetPinnedStep == nil {
                        settings.widgetPinnedStep = settings.steps.first?.id
                    }
                    // Same for the Qur'an: a few well-known verses to start
                    // from, so the first thing seen is a verse and not a void.
                    if scope == .quran && settings.widgetPassages.isEmpty {
                        settings.widgetPassages = QuranExcerpts.seed
                    }
                }
            } leading: {
                IconTile(icon: showsQuran ? .quran : .mat)
            }
            .accessibilityIdentifier("widget.show")

            // The Qur'an's own question: which verses. A sheet behind a row,
            // the list can be long and is composed once.
            if showsQuran {
                RowDivider().padding(.leading, 78)
                Button {
                    Haptic.tap.play()
                    showsExcerpts = true
                } label: {
                    HStack(spacing: 12) {
                        IconTile(icon: .star)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.t("widget.quran.title"))
                                .font(Theme.rounded(13, .heavy))
                                .foregroundStyle(Theme.inkSoft)
                            Text(loc.t("quran.verses", settings.widgetPassages.reduce(0) { $0 + $1.count }))
                                .font(Theme.rounded(16.5, .heavy))
                                .foregroundStyle(Theme.ink)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())
                .accessibilityIdentifier("widget.excerpts")
            }

            // Only when it means something: the step is a question you are
            // asked after answering "one step, always", not before.
            if settings.widgetScope == .one, let pinned = pinnedStep {
                RowDivider().padding(.leading, 78)
                MenuRow(title: nil,
                        value: pinned.name,
                        options: settings.steps.map { ($0.id, "\($0.order). \($0.name)") },
                        selected: pinned.id) { id in
                    settings.widgetPinnedStep = id
                } leading: {
                    PositionMedallion(step: pinned, size: 52)
                }
                .accessibilityIdentifier("widget.step")
            }

            RowDivider().padding(.leading, 78)

            // The labels are the detail page's own headings: the widget leads
            // with one of the three texts every step page already names.
            MenuRow(title: loc.t("widget.focus.title"),
                    value: loc.t("detail.\(shownFocus.rawValue)"),
                    options: focusOptions.map { ($0, loc.t("detail.\($0.rawValue)")) },
                    selected: shownFocus) { focus in
                settings.widgetFocus = focus
            } leading: {
                IconTile(icon: .book)
            }
            .accessibilityIdentifier("widget.focus")
        }
        .card(padding: 0)
    }

    private var pinnedStep: PrayerStep? {
        settings.steps.first { $0.id == settings.widgetPinnedStep } ?? settings.steps.first
    }
}

// MARK: - A setting, as one row

/// A row that says its current value and opens the system menu to change it.
/// The menu rather than a list of radio rows: three settings then take three
/// rows, whatever the number of choices behind each.
private struct MenuRow<Option: Hashable, Leading: View>: View {
    let title: String?
    let value: String
    let options: [(Option, String)]
    let selected: Option
    let pick: (Option) -> Void
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { option, label in
                Button {
                    Haptic.select.play()
                    pick(option)
                } label: {
                    if option == selected {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                leading()

                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(Theme.rounded(13, .heavy))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Text(value)
                        .font(Theme.rounded(16.5, .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }
}
