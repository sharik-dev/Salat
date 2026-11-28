import SwiftUI
import UserNotifications

/// The Salat Premium screen: what the subscription gives, what it costs, one
/// green button.
///
/// Since 22/11/2026 (Sharik's decision) it is a **hard paywall**: without
/// Premium the app is not usable, so `ContentView` lays this screen over the
/// whole app, with no close button (`hard`). The same view, closable, is the
/// subscriber's sheet in the settings (active, manage).
///
/// Since 25/11/2026 (conversion pass) the page opens on the welcome's own
/// promise: a headline, the reader's answers echoed back, and the Qur'an feed
/// in small (the gesture they just tried). Then, when the account may take
/// the free trial, a **timeline** of it (today, the reminder the day before
/// it ends, the day it turns paid) — the reminder is real, scheduled on
/// purchase (`TrialReminder`). Then what the subscription opens, and the
/// price.
///
/// Since 27/11/2026 (Marvin's paywall research), laurels with the App
/// Store's **real** rating sit under the feed preview — hidden until it rests on
/// enough ratings (`StoreRating`). Nothing else on the page is social proof.
///
/// Since 28/11/2026, four A/B tests ride on it (`PaywallLab`): the button
/// says "Continue" (cta), two screens come first (pre), backing out of the
/// App Store sheet offers the year (exit), the weekly plan replaces the
/// monthly one (weekly). The exit sheet carries the full legal text too.
///
/// Everything Apple asks of a subscription screen is on it and stays on it
/// (3.1.2): the price and its period, the most visible price on the screen;
/// the free trial and what follows it, in the button and in the sentence about
/// renewal; "Restore purchases"; and the two links (terms of use, privacy).
/// Removing one of them to tidy the page is a rejection.
struct PaywallView: View {
    /// The hard paywall: whole screen, no way out but subscribing or
    /// restoring.
    var hard = false

    @Environment(AppSettings.self) private var settings
    @Environment(Store.self) private var store
    @Environment(\.loc) private var loc
    @Environment(\.openURL) private var openURL
    @State private var rating = StoreRating.shared
    /// The pre-screen shown over the paywall (test "pre"), nil once through.
    @State private var preStep: Int?
    /// The plan offered on the way out (test "exit").
    @State private var exitPlan: Store.Plan?

    /// The plan this paywall sells: the weekly one in arm B of "weekly".
    private var plan: Store.Plan { PaywallLab.sellsWeekly ? .week : .month }
    private var price: String? { store.displayPrice(plan) }
    private var trialDays: Int? { store.offeredTrialDays(plan) }

    var body: some View {
        SheetScaffold(title: loc.t("premium.title"), icon: .sparkle, closable: !hard) {
            VStack(spacing: 14) {
                Text(loc.t("paywall.headline"))
                    .font(Theme.title(26))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(pitch)
                    .font(Theme.rounded(15.5, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("paywall.pitch")

                preview
                if !store.isPremium, rating.showable { laurels }
                if !store.isPremium, let days = trialDays { timeline(days) }
                benefits
                // Room for the bar pinned below: the last line of the card
                // must be able to scroll clear of it.
                Color.clear.frame(height: 4)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .task {
            await store.loadProduct()
            if hard {
                PaywallLab.track("paywall_view")
                if PaywallLab.isB(.pre), PaywallLab.trialOffered, !store.isPremium,
                   !UserDefaults.standard.bool(forKey: "lab.preSeen") {
                    preStep = 0
                    PaywallLab.track("pre_step", ["step": "0"])
                }
            }
            await rating.refresh()
            #if DEBUG
            // `-debugExit YES`: act out a refused purchase, for the capture.
            if UserDefaults.standard.bool(forKey: "debugExit") {
                try? await Task.sleep(for: .seconds(1))
                store.noteCancel(plan)
            }
            #endif
        }
        .overlay { if let step = preStep { preScreen(step) } }
        .animation(Theme.spring, value: preStep)
        .onChange(of: store.cancelled) { offerExit() }
        .sheet(item: $exitPlan) { exitSheet($0) }
        .onDisappear { store.clearNotice() }
    }

    /// The reader's own answer from the welcome, when there is one: the hours
    /// they said they spend on their phone. Nothing is invented for whoever
    /// skipped the question.
    private var pitch: String {
        var parts: [String] = []
        if let goal = OnboardingManager.goal {
            parts.append(loc.t("welcome.plan.goal", loc.t(goal.key)) + ".")
        }
        if let hours = OnboardingManager.phoneHours, hours > 0 {
            parts.append(loc.t("premium.pitch.hours", hours))
        } else {
            parts.append(loc.t("premium.pitch"))
        }
        return parts.joined(separator: " ")
    }

    // MARK: What is sold

    /// The Qur'an feed in small: the swipe the welcome promised to redirect.
    private var preview: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let lines = settings.feedSampleLines
        let line = lines.count > 1 ? lines[1] : lines[0]
        return QuranFeedCard(arabic: line.0, translation: line.1, picture: 4, liked: true, scale: 0.72)
            .aspectRatio(2.2, contentMode: .fit)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.primaryDeep, lineWidth: 3))
            .background(shape.fill(Theme.primaryDeep).offset(y: 6))
            .padding(.bottom, 6)
            .environment(\.layoutDirection, .leftToRight)
    }

    /// How the trial goes, step by step: what happens today, the reminder
    /// before it ends, the day it turns paid. Saying when the money starts
    /// is what makes "free" believable.
    private func timeline(_ days: Int) -> some View {
        var rows: [(Icon3D, String, String)] = [
            (.sparkle, loc.t("paywall.timeline.today"), loc.t("paywall.timeline.today.body")),
        ]
        if days >= 2 {
            rows.append((.bell, loc.t("paywall.timeline.in", days - 1), loc.t("paywall.timeline.reminder.body")))
        }
        rows.append((.star, loc.t("paywall.timeline.in", days), loc.t("paywall.timeline.charge.body")))
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        IconTile(icon: row.0, size: 40, animated: i == 0)
                        if i < rows.count - 1 {
                            Capsule().fill(Theme.primary.opacity(0.35)).frame(width: 4).frame(minHeight: 14)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.1)
                            .font(Theme.rounded(15.5, .black))
                            .foregroundStyle(i == 0 ? Theme.primaryDeep : Theme.ink)
                        Text(row.2)
                            .font(Theme.rounded(14, .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .card(padding: 0)
        .accessibilityIdentifier("paywall.timeline")
    }

    /// The App Store's real rating, between two laurels — only once it rests
    /// on enough ratings (`StoreRating`).
    private var laurels: some View {
        let avg = rating.average ?? 0
        // Kept to one short band: the bar pinned below must never cut it.
        return HStack(spacing: 8) {
            Image(systemName: "laurel.leading")
                .font(.system(size: 26, weight: .semibold))
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(avg.formatted(.number.precision(.fractionLength(1))))
                        .font(Theme.rounded(18, .black))
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: Double(i) + 0.75 <= avg ? "star.fill"
                                  : Double(i) + 0.25 <= avg ? "star.leadinghalf.filled" : "star")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.goldDeep)
                        }
                    }
                }
                Text(loc.t("paywall.rating.count", rating.count))
                    .font(Theme.rounded(12, .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Image(systemName: "laurel.trailing")
                .font(.system(size: 26, weight: .semibold))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.rating")
    }

    /// What the subscription opens: the whole app.
    private let arguments: [(Icon3D, String)] = [
        (.mat, "premium.benefit.prayer"),
        (.quran, "premium.benefit.quran"),
        (.cards, "premium.benefit.revise"),
        (.phone, "premium.benefit.widget"),
        (.bell, "premium.benefit.reminders"),
    ]

    private var benefits: some View {
        VStack(spacing: 0) {
            ForEach(Array(arguments.enumerated()), id: \.offset) { index, argument in
                if index > 0 { RowDivider().padding(.leading, 66) }
                benefit(argument.0, argument.1)
            }
        }
        .card(padding: 0)
    }

    private func benefit(_ icon: Icon3D, _ key: String) -> some View {
        HStack(spacing: 12) {
            IconTile(icon: icon, size: 40)
            Text(loc.t(key))
                .font(Theme.rounded(15, .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    // MARK: The bottom of the screen

    private var actionBar: some View {
        VStack(spacing: 8) {
            if store.isPremium {
                active
            } else {
                offer
            }
            links
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Theme.paper.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 2) }
        .animation(Theme.spring, value: store.isPremium)
        .animation(Theme.spring, value: store.notice)
    }

    /// Already subscribed: the screen says so and points at the one place
    /// where a subscription is changed, the App Store's own page.
    private var active: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                LofiIcon(.check, size: 40, interval: 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("premium.active"))
                        .font(Theme.rounded(17, .black))
                        .foregroundStyle(Theme.primaryDeep)
                    Text(loc.t("premium.active.body"))
                        .font(Theme.rounded(13, .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier("paywall.active")

            Button { openURL(Store.manageURL) } label: {
                Text(loc.t("premium.manage"))
            }
            .buttonStyle(.cta(.secondary, height: 50, haptic: .tap))
            .accessibilityIdentifier("paywall.manage")
        }
    }

    @ViewBuilder
    private var offer: some View {
        if let price {
            Text(loc.t(key("premium.price", plan), price))
                .font(Theme.rounded(22, .black))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("paywall.price")

            if let days = trialDays {
                Text(loc.t("premium.trial.badge", days))
                    .font(Theme.rounded(13, .black))
                    .foregroundStyle(Theme.goldDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.goldSoft, in: Capsule())
                    .accessibilityIdentifier("paywall.trial")
            }

            ctaButton(plan, from: "paywall")

            if trialDays != nil {
                Label(loc.t("paywall.nopay"), systemImage: "checkmark.shield.fill")
                    .font(Theme.rounded(13.5, .heavy))
                    .foregroundStyle(Theme.primaryDeep)
                    .accessibilityIdentifier("paywall.nopay")
            }
        } else if store.loadFailed {
            // No product, no price: nothing can be sold, and a button that
            // pretends otherwise would be the first thing to fail.
            Text(loc.t("premium.unavailable"))
                .font(Theme.rounded(14, .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await store.loadProduct() }
            } label: {
                Text(loc.t("premium.retry"))
            }
            .buttonStyle(.cta(.secondary, height: 50, haptic: .tap))
            .accessibilityIdentifier("paywall.retry")
        } else {
            ProgressView()
                .tint(Theme.primary)
                .frame(height: 58)
        }

        if let notice = store.notice {
            Text(loc.t(noticeKey(notice)))
                .font(Theme.rounded(13.5, .heavy))
                .foregroundStyle(Theme.goldDeep)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.notice")
        }

        legalText(plan)
    }

    private func legalText(_ plan: Store.Plan) -> some View {
        Text(legal(plan))
            .font(Theme.rounded(11.5, .semibold))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// « 3 days free, then 0,99 € / month » for an account that may take the
    /// trial, « Subscribe — 0,99 € / month » otherwise. The price is always the
    /// App Store's `displayPrice`.
    /// Arm B of the "cta" test: just "Continue" — the price and the trial
    /// stay right above it and in the legal sentence.
    private func buttonTitle(_ plan: Store.Plan) -> String {
        if PaywallLab.isB(.cta) { return loc.t("common.continue") }
        let price = store.displayPrice(plan) ?? ""
        if let days = store.offeredTrialDays(plan) {
            return fill(key("premium.subscribe.trial", plan), days: days, price: price)
        }
        return fill(key("premium.subscribe", plan), days: 0, price: price)
    }

    private func legal(_ plan: Store.Plan) -> String {
        let price = store.displayPrice(plan) ?? ""
        if let days = store.offeredTrialDays(plan) {
            return fill(key("premium.legal.trial", plan), days: days, price: price)
        }
        return fill(key("premium.legal", plan), days: 0, price: price)
    }

    /// `premium.price` for the month, `premium.price.week` / `.year` otherwise.
    private func key(_ base: String, _ plan: Store.Plan) -> String {
        plan == .month ? base : base + "." + plan.rawValue
    }

    private func ctaButton(_ plan: Store.Plan, from: String) -> some View {
        Button { buy(plan, from: from) } label: {
            if store.isWorking {
                ProgressView().tint(.white)
            } else {
                Text(buttonTitle(plan))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.cta(.primary))
        .disabled(store.isWorking)
        .accessibilityIdentifier(from == "exit" ? "paywall.exit.subscribe" : "paywall.subscribe")
    }

    private func buy(_ plan: Store.Plan, from: String) {
        let trial = store.offeredTrialDays(plan)
        PaywallLab.track("purchase_tap", ["plan": plan.rawValue, "from": from,
                                          "trial": trial == nil ? "no" : "yes"])
        let localizer = settings.localizer
        Task {
            await store.purchase(plan)
            if store.isPremium {
                exitPlan = nil
                if let trial { await TrialReminder.schedule(days: trial, localizer: localizer) }
            }
        }
    }

    // MARK: Test "pre": two screens before the paywall

    private func preScreen(_ step: Int) -> some View {
        let days = trialDays ?? 3
        return VStack(spacing: 18) {
            Spacer()
            IconTile(icon: step == 0 ? .sparkle : .bell, size: 96, animated: true)
            Text(loc.t(step == 0 ? "paywall.pre.free.title" : "paywall.pre.remind.title"))
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(step == 0 ? loc.t("paywall.pre.free.body", days) : loc.t("paywall.pre.remind.body"))
                .font(Theme.rounded(16, .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == step ? Theme.primary : Theme.border)
                        .frame(width: i == step ? 22 : 8, height: 8)
                }
            }
            Button {
                if step == 0 {
                    preStep = 1
                    PaywallLab.track("pre_step", ["step": "1"])
                } else {
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound])
                        UserDefaults.standard.set(true, forKey: "lab.preSeen")
                        preStep = nil
                        PaywallLab.track("pre_step", ["step": "2"])
                    }
                }
            } label: {
                Text(loc.t(step == 0 ? "common.continue" : "paywall.pre.remind.button"))
            }
            .buttonStyle(.cta(.primary))
            .accessibilityIdentifier("paywall.pre.next")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .transition(.opacity)
        .id(step)
    }

    // MARK: Test "exit": the year, once, when the App Store sheet is dismissed

    private func offerExit() {
        guard PaywallLab.isB(.exit), PaywallLab.yearlyAvailable, !store.isPremium,
              store.cancelledPlan != .year,
              !UserDefaults.standard.bool(forKey: "lab.exitSeen") else { return }
        UserDefaults.standard.set(true, forKey: "lab.exitSeen")
        exitPlan = .year
        PaywallLab.track("exit_view", ["from": store.cancelledPlan?.rawValue ?? ""])
    }

    private func exitSheet(_ plan: Store.Plan) -> some View {
        let price = store.displayPrice(plan) ?? ""
        return VStack(spacing: 12) {
            IconTile(icon: .star, size: 64, animated: true)
                .padding(.top, 22)
            Text(loc.t("paywall.exit.title"))
                .font(Theme.title(26))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            if let saving = store.yearlySaving {
                Text(fill("paywall.exit.body", days: saving, price: price))
                    .font(Theme.rounded(15.5, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(loc.t(key("premium.price", plan), price))
                .font(Theme.rounded(22, .black))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("paywall.exit.price")
            if let days = store.offeredTrialDays(plan) {
                Text(loc.t("premium.trial.badge", days))
                    .font(Theme.rounded(13, .black))
                    .foregroundStyle(Theme.goldDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.goldSoft, in: Capsule())
            }
            ctaButton(plan, from: "exit")
            Button {
                PaywallLab.track("exit_dismiss")
                exitPlan = nil
            } label: {
                Text(loc.t("paywall.exit.nothanks"))
                    .font(Theme.rounded(15, .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall.exit.dismiss")
            legalText(plan)
            links
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .environment(\.layoutDirection, loc.layoutDirection)
    }

    /// `%d` and `%@` in one string, filled by hand: `String(format:)` with a
    /// translated format and two kinds of argument is where a crash hides.
    private func fill(_ key: String, days: Int, price: String) -> String {
        loc.t(key)
            .replacingOccurrences(of: "%d", with: String(days))
            .replacingOccurrences(of: "%@", with: price)
    }

    private func noticeKey(_ notice: Store.Notice) -> String {
        switch notice {
        case .nothingToRestore: return "premium.notice.none"
        case .pending:          return "premium.notice.pending"
        case .failed:           return "premium.notice.failed"
        }
    }

    /// Restore, terms, privacy: three quiet links. On one line where the
    /// language lets them, otherwise restore on its own and the two legal
    /// links together under it.
    private var links: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { restoreLink; legalLinks }
            VStack(spacing: 0) {
                restoreLink
                HStack(spacing: 16) { legalLinks }
            }
        }
    }

    @ViewBuilder
    private var restoreLink: some View {
        if !store.isPremium {
            link("premium.restore", id: "paywall.restore") {
                Task { await store.restore() }
            }
            .disabled(store.isWorking)
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        link("premium.terms", id: "paywall.terms") { openURL(Store.termsURL) }
        link("premium.privacy", id: "paywall.privacy") { openURL(Store.privacyURL) }
    }

    private func link(_ key: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(loc.t(key))
                .font(Theme.rounded(12.5, .heavy))
                .foregroundStyle(Theme.primaryDeep)
                .underline()
                .lineLimit(1)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
