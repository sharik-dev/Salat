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

    var learned: Set<String> {
        didSet {
            Progress.learned = learned
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var stepSeconds: Double {
        didSet { SharedStore.defaults.set(stepSeconds, forKey: SharedStore.Key.stepSeconds) }
    }

    /// Which voice the recitation panel plays. Stored, never computed from
    /// UserDefaults on read: `@Observable` only tracks stored properties, so a
    /// computed accessor would change the voice without redrawing anything.
    var reciterID: String? {
        didSet { SharedStore.defaults.set(reciterID, forKey: SharedStore.Key.reciter) }
    }

    init() {
        let preference = SharedStore.storedLanguagePreference
        let resolved = preference == .system ? AppLanguage.resolvedFromSystem() : preference
        languagePreference = preference
        localizer = Localizer(language: resolved)
        steps = PrayerContent.steps(for: resolved)
        learned = Progress.learned
        let stored = SharedStore.defaults.double(forKey: SharedStore.Key.stepSeconds)
        stepSeconds = stored > 0 ? stored : 7
        reciterID = SharedStore.defaults.string(forKey: SharedStore.Key.reciter)
    }

    var resolvedLanguage: AppLanguage {
        languagePreference == .system ? .resolvedFromSystem() : languagePreference
    }

    func isLearned(_ step: PrayerStep) -> Bool { learned.contains(step.id) }

    func toggleLearned(_ step: PrayerStep) {
        if learned.contains(step.id) { learned.remove(step.id) } else { learned.insert(step.id) }
    }

    func resetProgress() { learned = [] }

    private func refreshContent() {
        localizer = Localizer(language: resolvedLanguage)
        steps = PrayerContent.steps(for: resolvedLanguage)
    }
}
