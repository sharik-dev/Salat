import SwiftUI

/// The two sheets behind the feed's side column: the notes of a verse, and
/// everything the reader has marked.

// MARK: - Notes

/// The "comments" of a verse, built like a comment thread (a list, and a field
/// pinned at the bottom) because that is the gesture a feed has taught. But the
/// thread has one author: these are the reader's own notes, kept on the phone.
/// The sheet says so, where a thread would show other people.
struct QuranNotesView: View {
    let journal: QuranJournal
    let ref: VerseRef
    let title: String
    let arabic: String

    @Environment(\.loc) private var loc
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var writing: Bool

    private var notes: [VerseNote] { journal.notes(for: ref) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { scroller in
                ScrollView {
                    VStack(spacing: 10) {
                        if notes.isEmpty {
                            empty
                        } else {
                            ForEach(notes) { note in
                                row(note).id(note.id)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                // A thread shows its newest line: the one just written.
                .onChange(of: notes.count) { _, _ in
                    if let last = notes.last {
                        withAnimation(Theme.spring) { scroller.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            inputBar
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.t("quran.notes.title"))
                    .font(Theme.title(22))
                    .foregroundStyle(Theme.ink)
                Text(verbatim: title)
                    .font(Theme.rounded(13.5, .heavy))
                    .foregroundStyle(Theme.primaryDeep)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.primaryDeep)
                    .frame(width: 38, height: 38)
            }
            .chunky(Theme.surface, radius: 19, depth: 3)
            .accessibilityIdentifier("sheet.close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 2) }
    }

    /// Before the first note: the verse itself, and what this place is for.
    private var empty: some View {
        VStack(spacing: 12) {
            Text(arabic)
                .font(Theme.arabic(21))
                .lineSpacing(8)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .environment(\.layoutDirection, .rightToLeft)
            Text(loc.t("quran.notes.hint"))
                .font(Theme.rounded(14.5, .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func row(_ note: VerseNote) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(Theme.rounded(15.5, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note.date.formatted(.dateTime.day().month(.abbreviated).year()
                    .locale(loc.locale)))
                    .font(Theme.rounded(11.5, .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(Theme.spring) { journal.deleteNote(note, from: ref) }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc.t("quran.notes.delete"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20, padding: 14)
    }

    private var inputBar: some View {
        let empty = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: 10) {
            TextField(loc.t("quran.notes.placeholder"), text: $draft, axis: .vertical)
                .font(Theme.rounded(16, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...5)
                .focused($writing)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .plate(Theme.surface, radius: 20)
                .accessibilityIdentifier("quran.notes.field")

            Button {
                journal.addNote(draft, to: ref)
                draft = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(empty ? Theme.inkSoft.opacity(0.7) : .white)
                    .frame(width: 44, height: 40)
            }
            .chunky(empty ? Theme.sand : Theme.primary, radius: 20, depth: 4, haptic: .press)
            .disabled(empty)
            .accessibilityIdentifier("quran.notes.send")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(alignment: .top) {
            Theme.surface.ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Theme.line.frame(height: 2) }
        }
    }
}

// MARK: - Marked verses

/// Every verse the reader loved or wrote on. Without this list a heart is a
/// dead end: it turns red, and the verse is lost in six thousand others.
struct QuranSavedView: View {
    let journal: QuranJournal
    let quran: Quran
    let pick: (VerseRef) -> Void

    @Environment(\.loc) private var loc

    var body: some View {
        SheetScaffold(title: loc.t("quran.saved.title"), icon: .star) {
            let marked = journal.marked.filter { isValid($0) }
            if marked.isEmpty {
                Text(loc.t("quran.saved.empty"))
                    .font(Theme.rounded(15, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .card()
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(marked, id: \.key) { ref in row(ref) }
                }
            }
        }
    }

    /// A mark written by another build must not index past the book.
    private func isValid(_ ref: VerseRef) -> Bool {
        quran.arabic.indices.contains(ref.surah - 1)
            && quran.arabic[ref.surah - 1].indices.contains(ref.verse - 1)
    }

    private func row(_ ref: VerseRef) -> some View {
        let notes = journal.notes(for: ref)
        return Button { pick(ref) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(verbatim: "\(quran.surah(ref.surah).latin) \(ref.surah):\(ref.verse)")
                        .font(Theme.rounded(14, .black))
                        .foregroundStyle(Theme.primaryDeep)
                        .environment(\.layoutDirection, .leftToRight)
                    Spacer(minLength: 0)
                    if journal.isLiked(ref) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Theme.danger)
                    }
                    if !notes.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 12, weight: .black))
                            Text(String(notes.count))
                                .font(Theme.rounded(12, .black).monospacedDigit())
                        }
                        .foregroundStyle(Theme.inkSoft)
                    }
                }

                Text(quran.arabic[ref.surah - 1][ref.verse - 1])
                    .font(Theme.arabic(19))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)

                // The latest note, in the reader's own words: it is what makes
                // this line theirs and not a table of contents.
                if let last = notes.last {
                    Text(last.text)
                        .font(Theme.rounded(13.5, .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .chunky(Theme.surface, radius: 20, depth: 4, haptic: .select)
        .accessibilityIdentifier("quran.saved.\(ref.key)")
    }
}
