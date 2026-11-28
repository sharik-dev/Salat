import XCTest

/// Salat Premium, from the outside, since the hard paywall (22/11/2026): a
/// non-subscriber sees the paywall over the whole app with no way to close
/// it, the paywall carries what a subscription screen must carry (3.1.2), and
/// a subscriber gets the app, and a sheet to manage the subscription.
///
/// No purchase is made here: the App Store is not reachable from a UI test.
/// `-premium 0|1` stands in for its answer, `-paywallPrice` for the price and
/// `-paywallTrial` for the free trial.
final class PremiumUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(premium: Bool, trial: Int = 3, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // The control arm of every paywall A/B test (`PaywallLab`).
        app.launchArguments += ["-lab.cta", "a", "-lab.pre", "a", "-lab.exit", "a", "-lab.weekly", "a"]
        app.launchArguments += ["-premium", premium ? "1" : "0",
                                "-paywallPrice", "4,99 €",
                                "-paywallTrial", String(trial),
                                // An install that finished the welcome long
                                // ago: the paywall comes straight away.
                                "-hasSeenOnboarding", "YES",
                                "-alwaysShowOnboarding", "NO"] + extra
        app.launch()
        return app
    }

    func testWithoutPremiumThePaywallCoversTheAppAndSaysEverythingItMust() {
        let app = launch(premium: false)

        let subscribe = app.buttons["paywall.subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10), "the hard paywall did not show")
        // What Apple asks of a subscription screen: the price with its period,
        // the trial and what follows it, a way to restore, the terms and the
        // privacy policy.
        XCTAssertTrue(app.staticTexts["paywall.price"].exists, "no price on the paywall")
        XCTAssertTrue(app.staticTexts["paywall.price"].label.contains("4,99"))
        XCTAssertTrue(subscribe.label.contains("3"), "the button does not name the free trial")
        XCTAssertTrue(subscribe.label.contains("4,99"), "the button does not say what follows the trial")
        XCTAssertTrue(app.buttons["paywall.restore"].exists, "no restore button")
        XCTAssertTrue(app.buttons["paywall.terms"].exists, "no terms of use link")
        XCTAssertTrue(app.buttons["paywall.privacy"].exists, "no privacy link")

        // Hard: no way around it.
        XCTAssertFalse(app.buttons["sheet.close"].exists, "the hard paywall can be closed")
        XCTAssertFalse(app.buttons["tab.learn"].exists, "the app is usable without Premium")
    }

    func testWithoutATrialTheButtonSimplySubscribes() {
        let app = launch(premium: false, trial: 0)
        let subscribe = app.buttons["paywall.subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10))
        XCTAssertTrue(subscribe.label.contains("4,99"))
        XCTAssertFalse(app.staticTexts["paywall.trial"].exists,
                       "a trial is promised to an account that cannot take it")
    }

    func testASubscriberGetsTheAppAndCanManageTheSubscription() {
        let app = launch(premium: true, ["-startTab", "practice", "-openTool", "widget"])
        XCTAssertTrue(app.buttons["widget.add"].waitForExistence(timeout: 10),
                      "a subscriber cannot add the widget")
        XCTAssertFalse(app.buttons["paywall.subscribe"].exists, "a subscriber is shown the paywall")
        app.terminate()

        let settings = launch(premium: true, ["-startTab", "settings"])
        let active = settings.buttons["settings.premium.active"]
        XCTAssertTrue(active.waitForExistence(timeout: 10),
                      "the settings do not say Premium is active")
        active.tap()
        XCTAssertTrue(settings.buttons["paywall.manage"].waitForExistence(timeout: 5),
                      "the subscriber's sheet has no way to manage the subscription")
        // The subscriber's sheet, unlike the paywall, closes.
        settings.buttons["sheet.close"].tap()
        XCTAssertTrue(active.waitForExistence(timeout: 5), "closing did not return to the settings")
    }
}
