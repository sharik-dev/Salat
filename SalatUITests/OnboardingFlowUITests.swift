import XCTest

/// The one thing that must never break again: you can always get out of the
/// onboarding. Since 22/11/2026 what comes after it depends on Premium: a
/// subscriber lands in the app, everyone else on the hard paywall — never back
/// on the welcome, never on a blank screen.
final class OnboardingFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchFreshInstall(premium: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetOnboarding", "1",
                                "-premium", premium ? "1" : "0",
                                "-paywallPrice", "0,99 €", "-paywallTrial", "3"]
        app.launch()
        return app
    }

    /// Taps through the whole story: the hook, the goal and the hours (both
    /// want an answer), the reckoning, the feed to swipe, the words, the
    /// widget, the plan (which waits for its build), and the daily moment,
    /// left by "Not now".
    private func tapThrough(_ app: XCUIApplication) -> XCUIElement {
        let primary = app.buttons["onboarding.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10),
                      "a fresh install should open on the onboarding")

        primary.tap() // the hook → the goal

        let goal = app.buttons["onboarding.goal.quran"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5), "the goal question never showed")
        XCTAssertFalse(primary.isEnabled, "the goal can be passed without an answer")
        goal.tap()
        primary.tap()

        // The question holds the button until it is answered.
        let fourHours = app.buttons["onboarding.hours.4"]
        XCTAssertTrue(fourHours.waitForExistence(timeout: 5), "the hours question never showed")
        XCTAssertFalse(primary.isEnabled, "the question can be passed without an answer")
        fourHours.tap()

        // The hours, the reckoning, the feed, the words, the widget.
        for page in 2...6 {
            XCTAssertTrue(primary.waitForExistence(timeout: 5),
                          "the onboarding button vanished on page \(page)")
            primary.tap()
        }

        // The plan builds, then lets you through.
        XCTAssertTrue(app.otherElements["onboarding.plan.ready"].waitForExistence(timeout: 10)
                      || primary.isEnabled, "the plan never finished building")
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: primary)
        waitForExpectations(timeout: 10)
        primary.tap()

        // The last screen offers the daily reminder. "Not now" is the way
        // through that never raises the system alert, which a UI test cannot
        // count on being able to answer.
        let later = app.buttons["onboarding.later"]
        XCTAssertTrue(later.waitForExistence(timeout: 5),
                      "the daily moment never showed its way out")
        later.tap()
        return primary
    }

    func testWithoutPremiumTheWelcomeEndsOnThePaywall() {
        let app = launchFreshInstall(premium: false)
        let primary = tapThrough(app)

        XCTAssertTrue(app.buttons["paywall.subscribe"].waitForExistence(timeout: 10),
                      "finishing the onboarding did not lead to the paywall")
        XCTAssertFalse(primary.exists, "the onboarding came back after finishing")
        XCTAssertFalse(app.buttons["tab.learn"].exists, "the app is usable without Premium")
    }

    func testASubscriberFinishingTheWelcomeReachesTheApp() {
        let app = launchFreshInstall(premium: true)
        let primary = tapThrough(app)

        // Anchored on the identifier, never on a label: the app runs in
        // whatever language the device asks for.
        XCTAssertTrue(app.buttons["tab.learn"].waitForExistence(timeout: 10),
                      "finishing the onboarding did not open the app")
        XCTAssertFalse(primary.exists, "the onboarding came back after finishing")
    }

    func testSkipLeadsToThePaywall() {
        let app = launchFreshInstall(premium: false)

        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()

        XCTAssertTrue(app.buttons["paywall.subscribe"].waitForExistence(timeout: 10),
                      "skipping left the user stuck in the onboarding")
    }
}
