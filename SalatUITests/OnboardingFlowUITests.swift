import XCTest

/// One test, for the one thing that must never break again: you can always get
/// out of the onboarding and into the app. The unit tests cover the state; this
/// covers the sheet actually going away when you tap the button.
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

        // Five pages: four "Next" then "Let's go".
        for page in 1...5 {
            XCTAssertTrue(primary.waitForExistence(timeout: 5),
                          "the onboarding button vanished on page \(page)")
            primary.tap()
        }

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
