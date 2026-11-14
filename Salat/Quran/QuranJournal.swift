import Foundation
import Observation

/// A verse, as the reader's own marks refer to it. Never a feed rank: the feed
/// cuts long verses into excerpts, and a heart belongs to the verse.
struct VerseRef: Hashable, Codable, Sendable {
    let surah: Int
    let verse: Int

    var key: String { "\(surah):\(verse)" }

    init(surah: Int, verse: Int) {
        self.surah = surah
        self.verse = verse
    }

    init?(key: String) {
        let parts = key.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        self.init(surah: parts[0], verse: parts[1])
    }
}

/// Something the reader wrote under a verse.
struct VerseNote: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var text: String
    var date = Date()
}

/// The hearts, readable from anywhere without the feed being open: the widget's
/// excerpt picker can offer "the verses I liked" from this.
enum QuranLikes {
    static let key = "quran.likes"

    /// Most recently liked first.
    static func all() -> [VerseRef] {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(VerseRef.init(key:))
    }
}

/// What the reader leaves on the Qur'an: hearts and notes.
///
/// It all stays on the phone, in `UserDefaults`. The "comments" of this feed
/// are a private notebook, not a social thread: nobody else reads them, and
/// nothing here is sent anywhere.
///
/// Stored properties, written in `didSet`: `@Observable` only tracks what is
/// stored, and the heart has to turn red the instant it is tapped.
@Observable
final class QuranJournal {
    private static let notesKey = "quran.notes"

    /// Most recently liked first.
    private(set) var likes: [VerseRef] {
        didSet { UserDefaults.standard.set(likes.map(\.key), forKey: QuranLikes.key) }
    }

    /// Verse key → its notes, oldest first, the way a thread reads.
    private(set) var notes: [String: [VerseNote]] {
        didSet {
            if let data = try? JSONEncoder().encode(notes) {
                UserDefaults.standard.set(data, forKey: Self.notesKey)
            }
        }
    }

    init() {
        likes = QuranLikes.all()
        if let data = UserDefaults.standard.data(forKey: Self.notesKey),
           let stored = try? JSONDecoder().decode([String: [VerseNote]].self, from: data) {
            notes = stored
        } else {
            notes = [:]
        }
    }

    // MARK: Hearts

    func isLiked(_ ref: VerseRef) -> Bool { likes.contains(ref) }

    func like(_ ref: VerseRef) {
        guard !isLiked(ref) else { return }
        likes.insert(ref, at: 0)
    }

    func toggleLike(_ ref: VerseRef) {
        if isLiked(ref) { likes.removeAll { $0 == ref } } else { likes.insert(ref, at: 0) }
    }

    // MARK: Notes

    func notes(for ref: VerseRef) -> [VerseNote] { notes[ref.key] ?? [] }

    func addNote(_ text: String, to ref: VerseRef) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes[ref.key, default: []].append(VerseNote(text: trimmed))
    }

    func deleteNote(_ note: VerseNote, from ref: VerseRef) {
        notes[ref.key]?.removeAll { $0.id == note.id }
        if notes[ref.key]?.isEmpty == true { notes[ref.key] = nil }
    }

    // MARK: Everything the reader marked

    /// Every verse carrying a heart or a note: the liked ones first (most
    /// recent first), then the ones that only have notes, in the order of the
    /// book.
    var marked: [VerseRef] {
        let noted = notes.keys.compactMap(VerseRef.init(key:))
            .filter { !likes.contains($0) }
            .sorted { ($0.surah, $0.verse) < ($1.surah, $1.verse) }
        return likes + noted
    }
}
