import XCTest

/// Poses the widget on the simulator's home screen and photographs it.
///
/// The widget is the one screen that cannot be checked from the app: it is
/// drawn by another process, from an archived view, and everything that does
/// not survive that archiving (runtime-registered fonts, missing resources)
/// only shows up here. `WidgetPreviewView` renders the same views inside the
/// app and therefore proves nothing about this path.
final class WidgetOnHomeScreenUITests: XCTestCase {

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testAddingTheWidgetToTheHomeScreen() {
        // The app has to have run once for its widget to be offered.
        let app = XCUIApplication()
        app.launchArguments += ["-resetOnboarding", "0"]
        app.launch()
        sleep(3)
        XCUIDevice.shared.press(.home)
        sleep(2)

        // Long press an icon → context menu → "Edit Home Screen" → jiggle mode.
        let icon = springboard.icons["Salat"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10), "the app icon is not on the home screen")
        icon.press(forDuration: 1.5)
        sleep(2)
        attach(named: "01-after-long-press")
        print("MENU TREE:\n\(springboard.debugDescription)")

        let edit = springboard.buttons["Edit Home Screen"].firstMatch
        if edit.waitForExistence(timeout: 5) { edit.tap() }
        sleep(2)

        // The "+" that opens the widget gallery sits at the top left.
        let plus = springboard.buttons["Add Widget"].firstMatch
        if plus.waitForExistence(timeout: 5) {
            plus.tap()
        } else {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.075)).tap()
        }
        sleep(3)
        attach(named: "02-gallery")
        print("GALLERY TREE:\n\(springboard.debugDescription)")

        // Search for the app by name inside the gallery.
        let field = springboard.searchFields.firstMatch
        if field.waitForExistence(timeout: 5) {
            field.tap()
            field.typeText("Salat")
            sleep(2)
        }
        attach(named: "03-search")

        let result = springboard.staticTexts["Salat"].firstMatch
        if result.waitForExistence(timeout: 5) {
            result.tap()
            sleep(3)
        }
        attach(named: "04-widget-preview-in-gallery")

        let add = springboard.buttons["Add Widget"].firstMatch
        if add.waitForExistence(timeout: 5) {
            add.tap()
            sleep(3)
        }
        attach(named: "05-placed")

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        sleep(3)
        attach(named: "06-home-screen-with-widget")
    }

    private func attach(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
