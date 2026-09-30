import Foundation

/// What the reader asked the widget to show. Two knobs, both set from the
/// *Memorise* tab's widget tool: **which steps** rotate, and **which text**
/// leads the card. They live in the kit because the widget extension has to
/// read them, and in the shared suite because two processes have to agree.

/// Which steps the carousel walks.
public enum WidgetScope: String, CaseIterable, Sendable {
    /// The default, and the smart one: what is being learnt, falling back to
    /// what is not yet known, falling back to the whole prayer — never empty.
    case learning
    /// All fourteen, in the order of the prayer, whatever the progress says.
    case all
    /// One step, permanently. The pick is the reader's, not the planner's.
    case one
}

/// Which of the three texts the card leads with. The other two still appear
/// when the canvas has room — this decides what is never dropped.
public enum WidgetFocus: String, CaseIterable, Sendable {
    case phonetic
    case arabic
    case translation
}

public struct WidgetPrefs: Equatable, Sendable {
    public var scope: WidgetScope
    /// Only read when `scope == .one`. Kept even when the scope moves away, so
    /// coming back to "one step" finds the old pick instead of a default.
    public var pinnedStepID: String?
    public var focus: WidgetFocus

    public init(scope: WidgetScope = .learning,
                pinnedStepID: String? = nil,
                focus: WidgetFocus = .phonetic) {
        self.scope = scope
        self.pinnedStepID = pinnedStepID
        self.focus = focus
    }

    public static func load() -> WidgetPrefs {
        let d = SharedStore.defaults
        return WidgetPrefs(
            scope: WidgetScope(rawValue: d.string(forKey: SharedStore.Key.widgetScope) ?? "") ?? .learning,
            pinnedStepID: d.string(forKey: SharedStore.Key.widgetPinnedStep),
            focus: WidgetFocus(rawValue: d.string(forKey: SharedStore.Key.widgetFocus) ?? "") ?? .phonetic)
    }
}
