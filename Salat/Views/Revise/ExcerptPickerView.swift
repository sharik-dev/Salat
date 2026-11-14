import SwiftUI

/// The Qur'an excerpts of the widget: the reader's list, and two ways to add
/// to it (a suggestion in one tap, or a surah and the verses to keep).
///
/// A sheet, like everything chosen once in a while. The list is in the order
/// the passages were added, which is the order the widget reads them in.
///
/// Nothing here writes a word of the Qur'an: a passage is three numbers, and
/// the names shown are the ones `quran.base.json` carries.
struct ExcerptPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @State private var showsSurahs = false
    /// A surah was picked and its verses are being chosen.
    @State private var draft: WidgetPassage?

    private let quran = Quran.shared

    var body: some View {
        SheetScaffold(title: loc.t("widget.quran.title"), icon: .quran) {
            VStack(alignment: .leading, spacing: 14) {
                mine

                if let draft, let surah = surah(draft.surah) {
                    draftCard(draft, in: surah)
                } else {
                    Button { showsSurahs = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .black))
                            Text(loc.t("widget.quran.add"))
                        }
                    }
                    .buttonStyle(.cta(.primary, height: 54))
                    .accessibilityIdentifier("excerpts.add")
                }

                liked
                suggestions
            }
            .animation(Theme.spring, value: settings.widgetPassages)
            .animation(Theme.spring, value: draft)
        }
        .sheet(isPresented: $showsSurahs) {
            if let quran {
                SurahPickerView(quran: quran, current: draft?.surah ?? 0) { number in
                    showsSurahs = false
                    // The whole surah to begin with: the two menus then only
                    // ever narrow it.
                    draft = WidgetPassage(surah: number, from: 1, to: quran.surah(number).verses)
                }
                .localized(settings.localizer)
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func surah(_ number: Int) -> Surah? {
        guard let quran, (1...quran.surahs.count).contains(number) else { return nil }
        return quran.surah(number)
    }

    // MARK: The reader's list

    @ViewBuilder
    private var mine: some View {
        let passages = settings.widgetPassages
        if passages.isEmpty {
            Text(loc.t("widget.quran.empty"))
                .font(Theme.rounded(14.5, .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .accessibilityIdentifier("excerpts.empty")
        } else {
            VStack(spacing: 0) {
                ForEach(passages) { passage in
                    HStack(spacing: 12) {
                        reference(passage)
                        name(passage)
                        Spacer(minLength: 6)
                        Button {
                            Haptic.tap.play()
                            settings.removeWidgetPassage(passage)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(Theme.inkSoft)
                                .frame(width: 34, height: 34)
                                .background(Theme.sand, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("excerpts.remove.\(passage.id)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if passage != passages.last { RowDivider().padding(.leading, 14) }
                }
            }
            .card(padding: 0)
            .accessibilityIdentifier("excerpts.list")
        }
    }

    /// "2:255" on its mint pill: the landmark of a row, in digits every
    /// language reads the same way, so it stays left-to-right.
    private func reference(_ passage: WidgetPassage) -> some View {
        Text(verbatim: passage.reference)
            .font(Theme.rounded(13.5, .black).monospacedDigit())
            .foregroundStyle(Theme.primaryDeep)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minWidth: 64, minHeight: 34)
            .background(Theme.primarySoft, in: Capsule())
            .environment(\.layoutDirection, .leftToRight)
    }

    private func name(_ passage: WidgetPassage) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(surah(passage.surah)?.latin ?? "")
                .font(Theme.rounded(16, .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // One verse says so by its reference alone; a count under it
            // would have to be a singular in fourteen languages.
            if passage.count > 1 {
                Text(loc.t("quran.verses", passage.count))
                    .font(Theme.rounded(12.5, .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: A surah, and which of its verses

    private func draftCard(_ draft: WidgetPassage, in surah: Surah) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                Button { showsSurahs = true } label: {
                    HStack(spacing: 12) {
                        IconTile(icon: .quran)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(surah.latin)
                                .font(Theme.rounded(16.5, .heavy))
                                .foregroundStyle(Theme.ink)
                            Text(loc.t("quran.verses", surah.verses))
                                .font(Theme.rounded(13, .heavy))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())

                RowDivider().padding(.leading, 78)
                verseMenu("widget.quran.from", value: draft.from, range: 1...draft.to) { from in
                    self.draft = WidgetPassage(surah: draft.surah, from: from, to: draft.to)
                }
                .accessibilityIdentifier("excerpts.from")

                RowDivider().padding(.leading, 78)
                verseMenu("widget.quran.to", value: draft.to, range: draft.from...surah.verses) { to in
                    self.draft = WidgetPassage(surah: draft.surah, from: draft.from, to: to)
                }
                .accessibilityIdentifier("excerpts.to")
            }
            .card(padding: 0)

            Button {
                settings.addWidgetPassage(draft)
                self.draft = nil
            } label: {
                Text(loc.t("widget.quran.confirm"))
            }
            .buttonStyle(.cta(.primary, height: 54))
            .accessibilityIdentifier("excerpts.confirm")
        }
    }

    /// One bound of the passage, as a row that says its value and opens a
    /// menu. Each menu only offers what keeps the two bounds in order.
    private func verseMenu(_ titleKey: String, value: Int, range: ClosedRange<Int>,
                           pick: @escaping (Int) -> Void) -> some View {
        Menu {
            Picker("", selection: Binding(get: { value }, set: { new in
                Haptic.select.play()
                pick(new)
            })) {
                ForEach(Array(range), id: \.self) { number in
                    Text(String(number)).tag(number)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Color.clear.frame(width: 52, height: 1)
                Text(loc.t(titleKey))
                    .font(Theme.rounded(15.5, .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text(String(value))
                    .font(Theme.rounded(17, .black).monospacedDigit())
                    .foregroundStyle(Theme.primaryDeep)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
    }

    // MARK: One-tap picks

    /// The verses the reader gave a heart to in the Qur'an tab, most recent
    /// first: the likeliest thing they want on their home screen. Read from
    /// `QuranLikes`, which does not need the feed to be open.
    @ViewBuilder
    private var liked: some View {
        let open = QuranLikes.all()
            .map { WidgetPassage(surah: $0.surah, from: $0.verse, to: $0.verse) }
            .filter { !settings.widgetPassages.contains($0) }
            .prefix(12)
        if !open.isEmpty {
            SectionLabel(loc.t("widget.quran.liked"))
                .padding(.top, 6)
            VStack(spacing: 10) {
                ForEach(Array(open)) { passage in pick(passage, id: "excerpts.liked") }
            }
        }
    }

    /// The picks not taken yet. One already on the list has nothing left to
    /// offer, so it leaves this section instead of sitting there greyed out.
    @ViewBuilder
    private var suggestions: some View {
        let open = QuranExcerpts.suggestions.filter { !settings.widgetPassages.contains($0) }
        if !open.isEmpty {
            SectionLabel(loc.t("widget.quran.suggested"))
                .padding(.top, 6)
            VStack(spacing: 10) {
                ForEach(open) { passage in pick(passage, id: "excerpts.suggest") }
            }
        }
    }

    private func pick(_ passage: WidgetPassage, id: String) -> some View {
        Button { settings.addWidgetPassage(passage) } label: {
            HStack(spacing: 12) {
                reference(passage)
                name(passage)
                Spacer(minLength: 6)
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .chunky(Theme.surface, radius: 20, depth: 4, haptic: .select)
        .accessibilityIdentifier("\(id).\(passage.id)")
    }
}
