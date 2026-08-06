import Foundation
import SwiftUI
import UserNotifications

/// The daily nudge to come back and learn one more step.
///
/// Two halves on purpose: `plan` is pure arithmetic over the steps and the
/// clock, testable without ever touching iOS, and the rest is the thin layer
/// that hands that plan to `UNUserNotificationCenter`.
@MainActor
@Observable
final class StudyReminders {

    /// One notification, before it becomes an iOS request.
    struct Draft: Equatable {
        let fireDate: Date
        /// The step the message names, `nil` once everything is learned.
        let stepID: String?
        let bodyKey: String
    }

    /// How far ahead the schedule is written. iOS keeps at most 64 pending
    /// notifications and does not wake us up to add more, so a reminder that
    /// must survive the app never being opened has to be written in advance.
    /// Two weeks, and then it stops by itself: an app that keeps tapping the
    /// shoulder of someone who has stopped answering gets deleted, not opened.
    static let horizonInDays = 14

    /// Three phrasings so the same sentence does not arrive every morning.
    private static let bodyKeys = ["notif.body.1", "notif.body.2", "notif.body.3"]
    private static let doneKey = "notif.body.done"
    /// A step already started is not "one more thing to do" — it is something
    /// left half-open, and the message says so.
    private static let learningKey = "notif.body.learning"
    private static let reviewKey = "notif.body.review"

    private static let identifierPrefix = "study.reminder."

    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    /// Set when a reminder is tapped, so the app can open on the step it named.
    var pendingStepID: String?

    private let center = UNUserNotificationCenter.current()
    private let delegate = ReminderDelegate()

    init() {
        delegate.reminders = self
        center.delegate = delegate
    }

    // MARK: - Authorization

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Asked the first time the switch is turned on, never at launch: an app
    /// that begs for notifications before showing anything gets a "no".
    /// Returns whether we may actually post.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshAuthorization()
        return granted
    }

    // MARK: - Scheduling

    /// Rewrites the whole schedule from the current settings and progress.
    /// Cheap enough to call on every foreground, which is what keeps the
    /// messages pointing at steps that are still unlearned.
    func sync(with settings: AppSettings, now: Date = Date()) async {
        await refreshAuthorization()

        center.removeAllPendingNotificationRequests()

        guard settings.remindersOn, authorization == .authorized else { return }

        let drafts = Self.plan(steps: settings.steps,
                               log: settings.log,
                               hour: settings.reminderHour,
                               minute: settings.reminderMinute,
                               from: now)

        let localizer = settings.localizer
        let names = Dictionary(uniqueKeysWithValues: settings.steps.map { ($0.id, $0.name) })

        for (index, draft) in drafts.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = localizer.t("notif.title")
            if let id = draft.stepID, let name = names[id] {
                content.body = localizer.t(draft.bodyKey, name)
                content.userInfo = ["stepID": id]
            } else {
                content.body = localizer.t(draft.bodyKey)
            }
            content.sound = .default

            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                        from: draft.fireDate)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + String(index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - The plan itself

    /// The next `days` reminders: one a day at the chosen time, each naming the
    /// step most owed a visit, cycling down the queue so the same one is not
    /// repeated two mornings in a row.
    ///
    /// The order comes from `StudyPlanner`, the same one the analytics page
    /// shows: a step started and then left alone comes before a step never
    /// opened, and a step marked known comes back after ten days. Naming the
    /// next unread step in prayer order — what this did before there were three
    /// states — kept pointing at things the reader had never claimed while the
    /// half-learned ones quietly faded.
    nonisolated static func plan(steps: [PrayerStep],
                                 log: StudyLogState,
                                 hour: Int,
                                 minute: Int,
                                 from now: Date,
                                 days: Int = horizonInDays,
                                 calendar: Calendar = .current) -> [Draft] {
        // Today's slot counts only if it has not gone by yet, otherwise the
        // first reminder would be scheduled in the past and never fire.
        guard let first = calendar.nextDate(after: now,
                                            matching: DateComponents(hour: hour, minute: minute),
                                            matchingPolicy: .nextTime)
        else { return [] }

        // The queue is computed once, from today: it cannot be recomputed for a
        // date two weeks out without guessing what the reader will have done by
        // then, and a guess written into a notification is a lie with a date on
        // it. It is rewritten on every foreground anyway.
        let queue = StudyPlanner.queue(steps: steps, log: log, now: now, calendar: calendar)

        return (0..<max(days, 0)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            guard !queue.isEmpty else {
                return Draft(fireDate: date, stepID: nil, bodyKey: doneKey)
            }
            let due = queue[offset % queue.count]
            return Draft(fireDate: date, stepID: due.stepID, bodyKey: bodyKey(for: due, offset: offset))
        }
    }

    private nonisolated static func bodyKey(for due: StudyPlanner.Due, offset: Int) -> String {
        switch due.reason {
        case .learning: return learningKey
        case .review:   return reviewKey
        case .new:      return bodyKeys[offset % bodyKeys.count]
        }
    }
}

// MARK: - Taps

/// Kept apart from `StudyReminders` because `UNUserNotificationCenterDelegate`
/// wants an `NSObject`, and the observable state should not have to be one.
private final class ReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var reminders: StudyReminders?

    /// Nothing is shown while the app is open: the reminder exists to bring
    /// the user back, and they are already here.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let stepID = response.notification.request.content.userInfo["stepID"] as? String
        Task { @MainActor in
            self.reminders?.pendingStepID = stepID
            completionHandler()
        }
    }
}
