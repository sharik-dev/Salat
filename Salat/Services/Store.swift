import StoreKit
import SwiftUI
import WidgetKit

/// Salat Premium: one auto-renewable subscription, monthly, that unlocks the
/// home screen widget. StoreKit 2, no server: the App Store is the only one
/// who knows who has paid, and the app asks it every time it comes forward.
///
/// What is paid for is **the widget on the home screen**. Its page in the app
/// stays open to everyone, preview and settings included: seeing the widget
/// with one's own verses on it is the pitch, and a paywall in front of the
/// preview would be selling a closed box.
///
/// The price is never written in the app. `1.99` lives in App Store Connect
/// (and in `StoreKit/Premium.storekit` for the simulator); the screen prints
/// `Product.displayPrice`, which is the reader's own currency and tax.
@MainActor
@Observable
final class Store {

    /// The subscription's product ID, as declared in App Store Connect by
    /// `scripts/asc_subscription.rb`. The two must match to the letter.
    static let productID = "com.salat.premium.monthly"

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
    private(set) var loadFailed = false
    /// A purchase or a restore is under way: the buttons wait.
    private(set) var isWorking = false
    /// What the last attempt has to say, shown under the button.
    private(set) var notice: Notice?

    /// Raised from anywhere (the widget's page, the settings, a tap on the
    /// locked widget); `ContentView` presents the paywall.
    var showsPaywall = false {
        didSet {
            guard showsPaywall, !oldValue else { return }
            paywallReason = nextReason ?? .manual
            nextReason = nil
        }
    }

    /// Why the paywall is up, which decides the argument it opens on. Anything
    /// that just sets `showsPaywall` is the reader's own tap: `.manual`.
    private(set) var paywallReason: PaywallReason = .manual
    @ObservationIgnored private var nextReason: PaywallReason?

    /// Raises the paywall for a reason other than a tap (`Nudges`).
    func present(_ reason: PaywallReason) {
        guard !showsPaywall else { return }
        nextReason = reason
        showsPaywall = true
    }

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
        guard forced == nil else { return }
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            active = true
        }
        isPremium = active
    }

    func loadProduct() async {
        guard product == nil else { return }
        loadFailed = false
        do {
            product = try await Product.products(for: [Self.productID]).first
            // An empty answer is a failure too: the product is not on sale
            // where this phone is, or not approved yet.
            loadFailed = product == nil
        } catch {
            loadFailed = true
        }
    }

    /// The price as the paywall prints it. `-paywallPrice` (DEBUG) stands in
    /// for the App Store on a simulator launched from the command line, where
    /// no product ever loads and the screen could not be photographed.
    var displayPrice: String? {
        product?.displayPrice ?? LaunchOptions.paywallPrice
    }

    func purchase() async {
        guard let product, !isWorking else { return }
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
                    Haptic.press.play()
                    showsPaywall = false
                }
            case .pending:
                notice = .pending
            case .userCancelled:
                break
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
