import XCTest

/// One test, for the one thing that must never break again: you can always get
/// out of the onboarding and into the app. The unit tests cover the state; this
/// covers the welcome actually going away when you tap the buttons.
final class OnboardingFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchFreshInstall() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetOnboarding", "1"]
        app.launch()
        return app
    }

    func testTappingThroughOnboardingReachesTheApp() {
        let app = launchFreshInstall()

        let primary = app.buttons["onboarding.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10),
                      "a fresh install should open on the onboarding")

        // Three pitch pages, then the language question: four taps on the
        // same wide button.
        for page in 1...4 {
            XCTAssertTrue(primary.waitForExistence(timeout: 5),
                          "the onboarding button vanished on page \(page)")
            primary.tap()
        }

        // The last question asks about the daily reminder. "Later" is the way
        // through that never raises the system alert, which a UI test cannot
        // count on being able to answer.
        let later = app.buttons["onboarding.later"]
        XCTAssertTrue(later.waitForExistence(timeout: 5),
                      "the reminder question never showed its way out")
        later.tap()

        // Anchored on the identifier, never on a label: the app runs in
        // whatever language the device asks for, and a test that waits for the
        // English word "Learn" fails the moment it is launched in French.
        XCTAssertTrue(app.buttons["tab.learn"].waitForExistence(timeout: 10),
                      "finishing the onboarding did not open the app")
        XCTAssertFalse(primary.exists, "the onboarding came back after finishing")
    }

    func testSkipReachesTheApp() {
        let app = launchFreshInstall()

        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()

        XCTAssertTrue(app.buttons["tab.learn"].waitForExistence(timeout: 10),
                      "skipping left the user stuck in the onboarding")
    }
}
