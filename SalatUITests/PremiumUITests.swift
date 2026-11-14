import XCTest

/// Salat Premium, from the outside: the ways in lead to the paywall, the
/// paywall carries what a subscription screen must carry, and a subscriber is
/// no longer offered what they already have.
///
/// No purchase is made here: the App Store is not reachable from a UI test.
/// `-premium 0|1` stands in for its answer and `-paywallPrice` for the price.
final class PremiumUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(premium: Bool, _ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-premium", premium ? "1" : "0",
                                "-paywallPrice", "1,99 €",
                                // Nothing over the app: no welcome, no ad
                                // consent form.
                                "-hasSeenOnboarding", "YES",
                                "-alwaysShowOnboarding", "NO",
                                "-debugAdsNoConsent", "1"] + extra
        app.launch()
        return app
    }

    func testTheSettingsShortcutOpensAPaywallThatSaysEverythingItMust() {
        let app = launch(premium: false, ["-startTab", "settings"])

        let shortcut = app.buttons["settings.premium"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10), "no way in from the settings")
        shortcut.tap()

        XCTAssertTrue(app.buttons["paywall.subscribe"].waitForExistence(timeout: 5),
                      "the paywall did not open")
        // What Apple asks of a subscription screen: the price with its period,
        // a way to restore, the terms and the privacy policy.
        XCTAssertTrue(app.staticTexts["paywall.price"].exists, "no price next to the button")
        XCTAssertTrue(app.staticTexts["paywall.price"].label.contains("1,99"))
        XCTAssertTrue(app.buttons["paywall.restore"].exists, "no restore button")
        XCTAssertTrue(app.buttons["paywall.terms"].exists, "no terms of use link")
        XCTAssertTrue(app.buttons["paywall.privacy"].exists, "no privacy link")

        // And it can be left: a paywall with no way out is the onboarding bug
        // again, with a price on it.
        app.buttons["sheet.close"].tap()
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5), "closing did not return to the settings")
        XCTAssertFalse(app.buttons["paywall.subscribe"].exists)
    }

    func testTheWidgetPageSellsTheWidgetInsteadOfAddingIt() {
        let app = launch(premium: false, ["-startTab", "practice", "-openTool", "widget"])

        let unlock = app.buttons["widget.unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10), "the widget page has no unlock button")
        XCTAssertFalse(app.buttons["widget.add"].exists,
                       "the add button is offered without a subscription")
        unlock.tap()
        XCTAssertTrue(app.buttons["paywall.subscribe"].waitForExistence(timeout: 5),
                      "unlocking did not open the paywall")
    }

    func testASubscriberIsNotOfferedWhatTheyHave() {
        let app = launch(premium: true, ["-startTab", "practice", "-openTool", "widget"])
        XCTAssertTrue(app.buttons["widget.add"].waitForExistence(timeout: 10),
                      "a subscriber cannot add the widget")
        XCTAssertFalse(app.buttons["widget.unlock"].exists)
        app.terminate()

        let settings = launch(premium: true, ["-startTab", "settings"])
        XCTAssertTrue(settings.buttons["settings.premium.active"].waitForExistence(timeout: 10),
                      "the settings do not say Premium is active")
        XCTAssertFalse(settings.buttons["settings.premium"].exists,
                       "the offer is still shown to a subscriber")
    }
}
