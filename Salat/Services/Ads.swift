import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// AdMob: one interstitial every **second break** — a step page closed or a
/// drill round finished — with a floor of `minGap` seconds between two ads.
/// Never while reading or reciting: a pause that cuts a verse in half would
/// teach the reader to dread opening a step.
///
/// Same mechanics as crowd-rush (`godotGame/crowd-rush/docs/admob.md`), which
/// is live: consent first (UMP), then ATT, then the SDK — and the SDK starts on
/// **every** path, failures included. Offline at first launch, or in a country
/// without a GDPR message, it must still start and serve non-personalised ads;
/// a path that forgets to start it means no ad at all until the next launch.
///
/// Debug builds always use Google's demo units: tapping a real ad in your own
/// app is the fastest way to get the AdMob account suspended. The real unit is
/// used in Release only.
@Observable @MainActor
final class Ads: NSObject {
    static let shared = Ads()

    /// From the AdMob console (account pub-3988815743198389). The app ID (with
    /// a `~`) lives in `Salat/Info.plist`, `GADApplicationIdentifier`.
    private static let liveInterstitial = "ca-app-pub-3988815743198389/3222246390"
    private static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"

    private static var interstitialUnit: String {
        #if DEBUG
        testInterstitial
        #else
        liveInterstitial
        #endif
    }

    /// One ad every `every` breaks, and never two within `minGap` seconds.
    private static let every = 2
    private static let minGap: TimeInterval = 60

    private var interstitial: InterstitialAd?
    private var loading = false
    /// The GDPR "privacy options" row Settings must show when the form applies.
    private(set) var privacyOptionsNeeded = false
    /// True while an ad covers the screen.
    private(set) var showing = false

    private var booted = false
    private var initialized = false
    private var breaks = 0
    private var lastAd = Date.distantPast

    /// Called once onboarding is out of the way: two system dialogs over the
    /// first page would be the app's first impression.
    func start() {
        guard !booted else { return }
        booted = true
        #if DEBUG
        // `-debugAdsNoConsent 1`: skips GDPR + ATT, to see ads in the simulator.
        if UserDefaults.standard.bool(forKey: "debugAdsNoConsent") { initialize(); return }
        #endif
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if error == nil {
                    // Shows the form only where consent is required (EU/UK).
                    try? await ConsentForm.loadAndPresentIfRequired(from: Self.topController())
                    self.privacyOptionsNeeded =
                        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                }
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    _ = await ATTrackingManager.requestTrackingAuthorization()
                }
                self.initialize()
            }
        }
    }

    /// Idempotent: the consent paths can cross.
    private func initialize() {
        guard !initialized else { return }
        initialized = true
        MobileAds.shared.start { _ in Task { @MainActor in self.load() } }
    }

    func showPrivacyOptions() {
        Task { try? await ConsentForm.presentPrivacyOptionsForm(from: Self.topController()) }
    }

    /// A natural pause just happened. Every second one shows the interstitial
    /// if it is ready — otherwise nothing, and the count waits for the next.
    func breakPoint() {
        guard initialized else { return }
        breaks += 1
        guard let ad = interstitial else {
            // A failed load does not retry in a loop (offline, that drains the
            // battery for nothing): it retries here, at the next pause.
            load()
            return
        }
        guard breaks >= Self.every, Date().timeIntervalSince(lastAd) >= Self.minGap else { return }
        interstitial = nil
        breaks = 0
        // Let the sheet finish sliding away first: presenting over a view
        // controller that is being dismissed silently does nothing.
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            guard UIApplication.shared.applicationState == .active,
                  let vc = Self.topController() else { interstitial = ad; return }
            showing = true
            lastAd = Date()
            ad.present(from: vc)
        }
    }

    private func load() {
        guard interstitial == nil, !loading, !Self.interstitialUnit.isEmpty else { return }
        loading = true
        InterstitialAd.load(with: Self.interstitialUnit, request: Request()) { [weak self] ad, _ in
            Task { @MainActor in
                guard let self else { return }
                self.loading = false
                ad?.fullScreenContentDelegate = self
                self.interstitial = ad
                #if DEBUG
                // `-debugAdsShow 1`: shows the first ad as soon as it loads —
                // nobody can tap through two pauses in the simulator.
                if let ad, UserDefaults.standard.bool(forKey: "debugAdsShow"),
                   let vc = Self.topController() {
                    UserDefaults.standard.removeObject(forKey: "debugAdsShow")
                    self.interstitial = nil
                    self.showing = true
                    ad.present(from: vc)
                }
                #endif
            }
        }
    }

    static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var vc = scene?.keyWindow?.rootViewController
        while let next = vc?.presentedViewController, !next.isBeingDismissed { vc = next }
        return vc
    }
}

extension Ads: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.showing = false
            self.load()
        }
    }

    /// An ad that fails to show hands control back exactly like a dismissal.
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        adDidDismissFullScreenContent(ad)
    }
}

#else

/// Ads off: the AdMob SDK is not linked. Same interface, nothing shows.
@Observable @MainActor
final class Ads {
    static let shared = Ads()
    let privacyOptionsNeeded = false
    let showing = false
    func start() {}
    func breakPoint() {}
    func showPrivacyOptions() {}
}

#endif
