import XCTest

/// A whole round, played to the summary. The unit tests prove the exercises
/// are honest; this proves the lesson can actually be *finished* — every
/// exercise reachable, the check button coming alive, the continue button
/// always there to move on. The drill was once a page whose next button was
/// easy to miss; this is the regression for the lesson frame that replaced it.
final class DrillLessonUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testARoundCanBePlayedToItsSummary() {
        let app = XCUIApplication()
        app.launchArguments += ["-learnAll", "1", "-startTab", "practice",
                                "-openTool", "drill"]
        app.launch()

        let check = app.buttons["drill.check"]
        let next = app.buttons["drill.next"]
        // The summary card is a plain container, which SwiftUI does not
        // expose as an element — its restart button is the reliable witness.
        let summary = app.buttons["drill.again"]

        XCTAssertTrue(check.waitForExistence(timeout: 10),
                      "the round did not open on an exercise")

        let option = app.buttons["drill.option.0"]
        let pairsChip = app.buttons["drill.pairs.reading.0"]
        let orderChip = app.buttons["drill.order.word.0"]

        // Eight exercises at most; a couple of spare turns for safety.
        for _ in 0..<12 {
            // Let the page transition settle: queried mid-spring, neither the
            // next exercise nor the summary exists yet.
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline, !summary.exists, !option.exists,
                  !pairsChip.exists, !orderChip.exists {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
            if summary.exists { break }

            if pairsChip.exists {
                solvePairs(app)
            } else if orderChip.exists {
                solveOrder(app)
                XCTAssertTrue(waitEnabled(check), "a full answer strip left check dead")
                check.tap()
            } else {
                option.tap()
                XCTAssertTrue(waitEnabled(check), "picking an option left check dead")
                check.tap()
            }

            XCTAssertTrue(next.waitForExistence(timeout: 5),
                          "no continue button after checking")
            next.tap()
        }

        XCTAssertTrue(summary.waitForExistence(timeout: 5),
                      "the round never reached its summary")
    }

    /// The check button wakes a beat after the tap that filled the answer —
    /// SwiftUI publishes the state change on the next runloop turn, and the
    /// accessibility snapshot lags it.
    private func waitEnabled(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !element.isEnabled {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.isEnabled
    }

    /// Brute force: pair each left chip with every right chip until it locks.
    /// Wrong matches only flash, so the board forgives the sweep.
    private func solvePairs(_ app: XCUIApplication) {
        for reading in 0..<4 {
            let left = app.buttons["drill.pairs.reading.\(reading)"]
            for meaning in 0..<4 {
                guard left.exists, left.isEnabled else { break }
                let right = app.buttons["drill.pairs.meaning.\(meaning)"]
                guard right.exists, right.isEnabled else { continue }
                left.tap()
                right.tap()
            }
        }
    }

    /// Tap every bank word once, in whatever order they come — the strip just
    /// has to be full for the check to wake.
    private func solveOrder(_ app: XCUIApplication) {
        var word = 0
        while true {
            let chip = app.buttons["drill.order.word.\(word)"]
            guard chip.exists else { break }
            if chip.isEnabled { chip.tap() }
            word += 1
        }
    }
}
