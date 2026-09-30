import SwiftUI
import WidgetKit

/// Single source of truth for everything the user can change. Every write goes
/// to the shared suite so the widget sees the same state, and nudges WidgetKit
/// to redraw.
@Observable
final class AppSettings {

    private(set) var localizer: Localizer
    private(set) var steps: [PrayerStep]

    var languagePreference: AppLanguage {
        didSet {
            SharedStore.defaults.set(languagePreference.rawValue, forKey: SharedStore.Key.language)
            refreshContent()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Statuses, dates and journal in one stored value. Stored and not computed
    /// on read: `@Observable` only tracks stored properties, and progress that
    /// changes without redrawing the list is the bug this app already shipped
    /// once.
    var log: StudyLogState {
        didSet {
            StudyLog.save(log)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Kept for the header and the progress bar. Derived, never a second source
    /// of truth.
    var learned: Set<String> { log.known }
    var learningNow: Set<String> { log.learning }

    var stepSeconds: Double {
        didSet { SharedStore.defaults.set(stepSeconds, forKey: SharedStore.Key.stepSeconds) }
    }

    /// Which voice the recitation panel plays. Stored, never computed from
    /// UserDefaults on read: `@Observable` only tracks stored properties, so a
    /// computed accessor would change the voice without redrawing anything.
    var reciterID: String? {
        didSet { SharedStore.defaults.set(reciterID, forKey: SharedStore.Key.reciter) }
    }

    /// The daily reminder. No `reloadAllTimelines` here, unlike every other
    /// setting: nothing on the home screen reads these three.
    var remindersOn: Bool {
        didSet { SharedStore.defaults.set(remindersOn, forKey: SharedStore.Key.remindersOn) }
    }

    var reminderHour: Int {
        didSet { SharedStore.defaults.set(reminderHour, forKey: SharedStore.Key.reminderHour) }
    }

    var reminderMinute: Int {
        didSet { SharedStore.defaults.set(reminderMinute, forKey: SharedStore.Key.reminderMinute) }
    }

    /// The widget's two knobs. Stored, mirrored to the shared suite, and every
    /// write nudges WidgetKit — the whole point of changing them is what the
    /// home screen shows next.
    var widgetScope: WidgetScope {
        didSet {
            SharedStore.defaults.set(widgetScope.rawValue, forKey: SharedStore.Key.widgetScope)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var widgetPinnedStep: String? {
        didSet {
            SharedStore.defaults.set(widgetPinnedStep, forKey: SharedStore.Key.widgetPinnedStep)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var widgetFocus: WidgetFocus {
        didSet {
            SharedStore.defaults.set(widgetFocus.rawValue, forKey: SharedStore.Key.widgetFocus)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var widgetPrefs: WidgetPrefs {
        WidgetPrefs(scope: widgetScope, pinnedStepID: widgetPinnedStep, focus: widgetFocus)
    }

    /// The reminder time as a `Date`, for the picker. Only the two components
    /// are ever stored: a full date would silently pin the reminder to the day
    /// the user set it.
    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute,
                                  second: 0, of: Date()) ?? Date()
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = parts.hour ?? reminderHour
            reminderMinute = parts.minute ?? reminderMinute
        }
    }

    init() {
        let preference = SharedStore.storedLanguagePreference
        let resolved = preference == .system ? AppLanguage.resolvedFromSystem() : preference
        languagePreference = preference
        localizer = Localizer(language: resolved)
        steps = PrayerContent.steps(for: resolved)
        log = StudyLog.load()
        let stored = SharedStore.defaults.double(forKey: SharedStore.Key.stepSeconds)
        stepSeconds = stored > 0 ? stored : 7
        reciterID = SharedStore.defaults.string(forKey: SharedStore.Key.reciter)
        remindersOn = SharedStore.defaults.bool(forKey: SharedStore.Key.remindersOn)
            || LaunchOptions.forcesRemindersOn
        // 19:30 by default: after work, before the evening goes. Zero would be
        // midnight, so an unset value has to fall back explicitly.
        let hour = SharedStore.defaults.object(forKey: SharedStore.Key.reminderHour) as? Int
        let minute = SharedStore.defaults.object(forKey: SharedStore.Key.reminderMinute) as? Int
        reminderHour = hour ?? 19
        reminderMinute = minute ?? 30
        let prefs = WidgetPrefs.load()
        widgetScope = prefs.scope
        widgetPinnedStep = prefs.pinnedStepID
        widgetFocus = prefs.focus
        // Screenshot fixture: the drill has nothing to ask on a phone where
        // nothing has been read. Debug builds only — `LaunchOptions` returns
        // nil everywhere else.
        if LaunchOptions.marksEverythingKnown {
            for step in steps where log.status(of: step.id) != .known {
                log.set(.known, for: step.id)
            }
        }
        if LaunchOptions.seedsDemoProgress { seedDemoProgress() }
    }

    var resolvedLanguage: AppLanguage {
        languagePreference == .system ? .resolvedFromSystem() : languagePreference
    }

    // MARK: - Progress

    func status(of step: PrayerStep) -> StepStatus { log.status(of: step.id) }

    func isLearned(_ step: PrayerStep) -> Bool { status(of: step) == .known }

    /// Each button toggles its own state off, back to "not started". Tapping
    /// "I know it" on a step already known is how a mistake is undone, and it
    /// should not drop the reader back into "learning" they never asked for.
    func setStatus(_ status: StepStatus, for step: PrayerStep, at date: Date = Date()) {
        let target: StepStatus = log.status(of: step.id) == status ? .untouched : status
        log.set(target, for: step.id, at: date)
    }

    /// Called when a step's page opens. This is the only thing that feeds the
    /// calendar and the staleness the reminders read: what counts as studying
    /// is having the step in front of you, not ticking a box afterwards.
    func noteStudied(_ step: PrayerStep, at date: Date = Date()) {
        log.study(step.id, at: date)
    }

    /// What to come back to, in the order the reminders will name it.
    func dueQueue(now: Date = Date()) -> [StudyPlanner.Due] {
        StudyPlanner.queue(steps: steps, log: log, now: now)
    }

    func step(_ id: String) -> PrayerStep? { steps.first { $0.id == id } }

    func resetProgress() { log = StudyLogState() }

    #if DEBUG
    /// A month of plausible reading, so the analytics page can be looked at
    /// before a month has been spent. Deterministic — the same phone always
    /// gets the same picture, otherwise two screenshots can never be compared.
    private func seedDemoProgress() {
        let calendar = Calendar.current
        let now = Date()
        func day(_ back: Int) -> Date {
            calendar.date(byAdding: .day, value: -back, to: now) ?? now
        }

        var seeded = StudyLogState()
        // The opening of the prayer, held for weeks.
        for (index, id) in ["niyyah", "takbir", "istiftah", "fatiha", "ruku"].enumerated() {
            let started = 30 - index * 3
            seeded.study(id, at: day(started), calendar: calendar)
            seeded.set(.learning, for: id, at: day(started))
            seeded.study(id, at: day(started - 2), calendar: calendar)
            seeded.set(.known, for: id, at: day(started - 2))
        }
        // Started, then left alone — what the reminders are for.
        for (index, id) in ["sujud", "jalsa", "tashahhud"].enumerated() {
            let seen = 12 - index * 4
            seeded.study(id, at: day(seen + 2), calendar: calendar)
            seeded.set(.learning, for: id, at: day(seen + 2))
            seeded.study(id, at: day(seen), calendar: calendar)
        }
        // A couple of days of simply reading, with nothing claimed.
        for back in [1, 3, 4, 9] {
            seeded.study("itidal", at: day(back), calendar: calendar)
        }
        log = seeded
    }
    #else
    private func seedDemoProgress() {}
    #endif

    private func refreshContent() {
        localizer = Localizer(language: resolvedLanguage)
        steps = PrayerContent.steps(for: resolvedLanguage)
    }
}
