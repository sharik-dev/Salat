import SwiftUI

/// The Salat Premium screen: what the subscription gives, what it costs, one
/// green button.
///
/// Since 22/11/2026 (Sharik's decision) it is a **hard paywall**: without
/// Premium the app is not usable, so `ContentView` lays this screen over the
/// whole app, with no close button (`hard`). The same view, closable, is the
/// subscriber's sheet in the settings (active, manage).
///
/// The top of the page is the reader's **own widget** on a home screen, the
/// real `CarouselWidgetView` with what they picked on it. Under it, what the
/// subscription opens and the price.
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

    var body: some View {
        SheetScaffold(title: loc.t("premium.title"), icon: .sparkle, closable: !hard) {
            VStack(spacing: 14) {
                Text(pitch)
                    .font(Theme.rounded(15.5, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("paywall.pitch")

                preview
                benefits
                // Room for the bar pinned below: the last line of the card
                // must be able to scroll clear of it.
                Color.clear.frame(height: 4)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .task { await store.loadProduct() }
        .onDisappear { store.clearNotice() }
    }

    /// The reader's own answer from the welcome, when there is one: the hours
    /// they said they spend on their phone. Nothing is invented for whoever
    /// skipped the question.
    private var pitch: String {
        if let hours = OnboardingManager.phoneHours, hours > 0 {
            return loc.t("premium.pitch.hours", hours)
        }
        return loc.t("premium.pitch")
    }

    // MARK: What is sold

    @ViewBuilder
    private var preview: some View {
        if let entry = settings.widgetPreviewEntry() {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            HomeScreenMock(entry: entry, rows: 0)
                .aspectRatio(1.72, contentMode: .fit)
                .clipShape(shape)
                .overlay(shape.strokeBorder(Theme.primaryDeep, lineWidth: 3))
                .background(shape.fill(Theme.primaryDeep).offset(y: 6))
                .padding(.bottom, 6)
        }
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
        if let price = store.displayPrice {
            Text(loc.t("premium.price", price))
                .font(Theme.rounded(22, .black))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("paywall.price")

            if let days = store.offeredTrialDays {
                Text(loc.t("premium.trial.badge", days))
                    .font(Theme.rounded(13, .black))
                    .foregroundStyle(Theme.goldDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.goldSoft, in: Capsule())
                    .accessibilityIdentifier("paywall.trial")
            }

            Button {
                Task { await store.purchase() }
            } label: {
                if store.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonTitle(price: price))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .buttonStyle(.cta(.primary))
            .disabled(store.isWorking)
            .accessibilityIdentifier("paywall.subscribe")
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

        Text(legal)
            .font(Theme.rounded(11.5, .semibold))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// « 3 days free, then 4,99 € / month » for an account that may take the
    /// trial, « Subscribe — 4,99 € / month » otherwise. The price is always the
    /// App Store's `displayPrice`.
    private func buttonTitle(price: String) -> String {
        if let days = store.offeredTrialDays {
            return fill("premium.subscribe.trial", days: days, price: price)
        }
        return fill("premium.subscribe", days: 0, price: price)
    }

    private var legal: String {
        let price = store.displayPrice ?? ""
        if let days = store.offeredTrialDays {
            return fill("premium.legal.trial", days: days, price: price)
        }
        return fill("premium.legal", days: 0, price: price)
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
