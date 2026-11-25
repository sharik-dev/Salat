import UserNotifications

/// The reminder the paywall's timeline promises: the day before a free trial
/// turns paid, one notification says so. Scheduled once, right after a
/// purchase that started a trial; permission is asked then if it never was
/// (the reader has just been told a reminder is coming). Refused, nothing is
/// posted and nothing else changes.
///
/// It lives beside the study reminders, which only ever clear their own
/// identifiers (`study.reminder.*`), never this one.
enum TrialReminder {
    static let identifier = "trial.end"

    static func schedule(days: Int, localizer: Localizer, now: Date = Date()) async {
        guard days >= 2 else { return }
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = localizer.t("notif.trial.title")
        content.body = localizer.t("notif.trial.body")
        content.sound = .default
        let fire = now.addingTimeInterval(TimeInterval(days - 1) * 86_400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(fire.timeIntervalSince(now), 60), repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
