import StoreKit
import SwiftUI
import WidgetKit

/// Salat Premium: one auto-renewable subscription, monthly, with a three-day
/// free trial, and **the whole app is behind it** (Sharik's decision,
/// 22/11/2026: hard paywall, no ads). StoreKit 2, no server: the App Store is
/// the only one who knows who has paid, and the app asks it every time it
/// comes forward.
///
/// The price is never written in the app. `0.99` lives in App Store Connect
/// (and in `StoreKit/Premium.storekit` for the simulator); the screen prints
/// `Product.displayPrice`, which is the reader's own currency and tax. The
/// trial is read from the product too (`introductoryOffer`), and only offered
/// to an account Apple still considers eligible.
@MainActor
@Observable
final class Store {

    /// The subscription's product ID, as declared in App Store Connect by
    /// `scripts/asc_subscription.rb`. The two must match to the letter.
    static let productID = "com.salat.premium.monthly"
    /// The paywall A/B tests (`PaywallLab`, 28/11/2026): the weekly plan of
    /// the "weekly" test, the yearly one offered on the way out ("exit").
    /// Created by `PLAN=weekly|yearly ruby scripts/asc_subscription.rb`.
    static let weeklyID = "com.salat.premium.weekly"
    static let yearlyID = "com.salat.premium.yearly"
    static let allIDs = [productID, weeklyID, yearlyID]

    enum Plan: String, Identifiable { case month, week, year
        var id: String {
            switch self { case .month: Store.productID; case .week: Store.weeklyID; case .year: Store.yearlyID }
        }
    }

    /// Stored and not read from the defaults on demand: `@Observable` only
    /// tracks stored properties. Every change goes to the shared suite, which
    /// is where the widget reads it, and redraws the home screen.
    private(set) var isPremium: Bool {
        didSet {
            guard isPremium != oldValue else { return }
            Premium.isActive = isPremium
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Nil until the App Store answered. The paywall needs it for the price,
    /// and cannot sell without it.
    private(set) var product: Product?
    private(set) var weekly: Product?
    private(set) var yearly: Product?
    /// Free days each plan offers this account (absent: no trial).
    private(set) var trials: [String: Int] = [:]
    /// The App Store sheet closed without buying: a counter the paywall
    /// watches, and which plan it was (the "exit" test).
    private(set) var cancelled = 0
    private(set) var cancelledPlan: Plan?
    private(set) var loadFailed = false
    /// A purchase or a restore is under way: the buttons wait.
    private(set) var isWorking = false
    /// What the last attempt has to say, shown under the button.
    private(set) var notice: Notice?

    /// The subscription sheet for someone who already pays (manage, restore).
    /// A non-subscriber never needs it: the paywall is the whole screen.
    var showsPaywall = false

    /// False until the App Store's records have been read once. Until then the
    /// app shows a blank cover rather than the paywall: a subscriber who just
    /// reinstalled must not see "Subscribe" flash for half a second.
    private(set) var hasChecked = false

    /// Days of free trial this account would get, or nil when there is none
    /// (no offer on the product, or the account already used it). The button
    /// promises a trial only when this is set.
    private(set) var trialDays: Int?

    enum Notice: Equatable {
        /// "Restore" found nothing to restore on this Apple account.
        case nothingToRestore
        /// The purchase is waiting for someone else's approval (Ask to Buy).
        case pending
        case failed
    }

    @ObservationIgnored private var updates: Task<Void, Never>?
    /// A debug launch that forces the answer (`-premium 0|1`) must not be
    /// overruled a second later by a simulator that has bought nothing.
    @ObservationIgnored private var forced: Bool?

    init() {
        var override = LaunchOptions.forcedPremium
        #if DEBUG
        // The developer switch of the settings, kept from one launch to the
        // next. A launch argument still wins over it.
        if override == nil, let stored = UserDefaults.standard.object(forKey: Self.debugKey) as? Bool {
            override = stored
        }
        #endif
        forced = override
        isPremium = forced ?? Premium.isActive
        // A forced answer needs no App Store, and the stored "active" is
        // trusted for the first frame: the cover only waits for a reader the
        // app has never seen pay.
        hasChecked = forced != nil || isPremium
        // `didSet` does not run from an initializer, and a forced answer has
        // to reach the widget too.
        if let forced { Premium.isActive = forced }
    }

    /// Called once at launch. Listens for what happens outside the app (a
    /// renewal, a refund, a purchase approved by a parent, a subscription
    /// bought on another device) and asks where things stand now.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task {
            await refresh()
            await loadProduct()
        }
    }

    /// Where the subscription stands, from the App Store's own records (they
    /// are kept on the device: this answers offline too).
    func refresh() async {
        guard forced == nil else { hasChecked = true; return }
        defer { hasChecked = true }
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  Self.allIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            active = true
        }
        isPremium = active
    }

    func loadProduct() async {
        guard product == nil else { return }
        loadFailed = false
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            product = loaded.first { $0.id == Self.productID }
            weekly = loaded.first { $0.id == Self.weeklyID }
            yearly = loaded.first { $0.id == Self.yearlyID }
            PaywallLab.weeklyAvailable = weekly != nil || LaunchOptions.paywallPrice != nil
            // An empty answer is a failure too: the product is not on sale
            // where this phone is, or not approved yet.
            loadFailed = product == nil
            await loadTrial()
            PaywallLab.yearlyAvailable = yearly != nil || LaunchOptions.paywallPrice != nil
            PaywallLab.trialOffered = offeredTrialDays(.month) != nil
        } catch {
            loadFailed = true
        }
    }

    /// The free trial of each plan, if it has one and this account may take it.
    private func loadTrial() async {
        #if DEBUG
        if let days = LaunchOptions.paywallTrial {
            trialDays = days > 0 ? days : nil
            trials = days > 0 ? Dictionary(uniqueKeysWithValues: Self.allIDs.map { ($0, days) }) : [:]
            return
        }
        #endif
        var out: [String: Int] = [:]
        for p in [product, weekly, yearly].compactMap({ $0 }) {
            if let days = await Self.trial(of: p) { out[p.id] = days }
        }
        trials = out
        trialDays = product.flatMap { out[$0.id] }
    }

    private static func trial(of product: Product) async -> Int? {
        guard let subscription = product.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await subscription.isEligibleForIntroOffer else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
    }

    func product(_ plan: Plan) -> Product? {
        switch plan { case .month: product; case .week: weekly; case .year: yearly }
    }

    /// The price of a plan as the paywall prints it. On the command-line
    /// simulator (`-paywallPrice`, DEBUG) the other plans get fixed stand-ins.
    func displayPrice(_ plan: Plan) -> String? {
        if let p = product(plan) { return p.displayPrice }
        guard let monthly = LaunchOptions.paywallPrice else { return nil }
        switch plan { case .month: return monthly; case .week: return "0,49 €"; case .year: return "5,99 €" }
    }

    func offeredTrialDays(_ plan: Plan) -> Int? {
        if product(plan) == nil, let days = LaunchOptions.paywallTrial { return days > 0 ? days : nil }
        return product(plan).flatMap { trials[$0.id] }
    }

    /// How much less the year costs than twelve months, in percent, from the
    /// real prices of this storefront.
    var yearlySaving: Int? {
        let (m, y): (Decimal, Decimal)
        if let pm = product, let py = yearly { (m, y) = (pm.price, py.price) }
        else if LaunchOptions.paywallPrice != nil { (m, y) = (0.99, 5.99) }
        else { return nil }
        guard m * 12 > y else { return nil }
        return Int(((1 - NSDecimalNumber(decimal: y / (m * 12)).doubleValue) * 100).rounded(.down))
    }

    /// The price as the paywall prints it. `-paywallPrice` (DEBUG) stands in
    /// for the App Store on a simulator launched from the command line, where
    /// no product ever loads and the screen could not be photographed.
    var displayPrice: String? { displayPrice(.month) }

    /// The trial as the paywall promises it: the product's, or `-paywallTrial`
    /// (DEBUG) for the same command-line simulator.
    var offeredTrialDays: Int? { offeredTrialDays(.month) }

    func purchase(_ plan: Plan = .month) async {
        guard !isWorking else { return }
        guard let product = product(plan) else {
            #if DEBUG
            noteCancel(plan)   // command-line simulator: act out a refusal
            #endif
            return
        }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    notice = .failed
                    return
                }
                await transaction.finish()
                await refresh()
                if isPremium {
                    PaywallLab.track("pro_purchase", ["plan": plan.rawValue,
                        "trial": offeredTrialDays(plan) == nil ? "no" : "yes"])
                    Haptic.press.play()
                    showsPaywall = false
                }
            case .pending:
                notice = .pending
            case .userCancelled:
                noteCancel(plan)
            @unknown default:
                break
            }
        } catch {
            notice = .failed
        }
    }

    /// Asks the App Store again, for a phone that was restored or a second
    /// device. Apple requires the button; most of the time `refresh` at launch
    /// has already done the work.
    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        try? await AppStore.sync()
        await refresh()
        if isPremium {
            showsPaywall = false
        } else {
            notice = .nothingToRestore
        }
    }

    func clearNotice() { notice = nil }

    func noteCancel(_ plan: Plan) {
        cancelledPlan = plan
        cancelled += 1
        PaywallLab.track("purchase_cancel", ["plan": plan.rawValue])
    }

    #if DEBUG
    private static let debugKey = "debug.premiumOverride"

    /// The developer switch in the settings: Premium on or off without the App
    /// Store, on a phone where the product cannot be bought yet (a build run
    /// from Xcode before the subscription exists on App Store Connect). It is
    /// remembered, so the widget stays unlocked between launches. Debug builds
    /// only: a Release build has neither the switch nor the key.
    func setDebugPremium(_ on: Bool) {
        forced = on
        UserDefaults.standard.set(on, forKey: Self.debugKey)
        isPremium = on
    }
    #endif

    /// Where a subscription is cancelled or changed: the App Store's own page.
    static let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let privacyURL = URL(string: "https://sharik-dev.github.io/salat-support/privacy.html")!
    /// Apple's standard licence, which is the app's terms of use.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
