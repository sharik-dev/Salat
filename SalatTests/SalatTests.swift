import XCTest
@testable import Salat

/// The content files are the app. If one of them stops parsing, or a locale
/// drifts out of sync with the base, everything downstream shows blanks — so
/// that is what these tests guard.
final class PrayerContentTests: XCTestCase {

    func testEveryShippedLanguageLoadsEveryStep() {
        let base = PrayerContent.steps(for: .en)
        XCTAssertEqual(base.count, 14, "the base file should carry the 14 steps")

        for language in AppLanguage.shipped {
            let steps = PrayerContent.steps(for: language)
            XCTAssertEqual(steps.count, base.count,
                           "\(language.rawValue) is missing steps — check steps.\(language.rawValue).json")
            for step in steps {
                XCTAssertFalse(step.name.isEmpty, "\(language.rawValue)/\(step.id) has no name")
                XCTAssertFalse(step.postureText.isEmpty, "\(language.rawValue)/\(step.id) has no posture")
                XCTAssertFalse(step.translation.isEmpty, "\(language.rawValue)/\(step.id) has no translation")
            }
        }
    }

    func testStepsAreOrderedAndUnique() {
        let steps = PrayerContent.steps(for: .en)
        XCTAssertEqual(steps.map(\.order), Array(1...steps.count))
        XCTAssertEqual(Set(steps.map(\.id)).count, steps.count)
    }

    /// The detail screen pairs each Arabic line with its phonetic and its
    /// translation. A mismatch does not crash, but it silently misaligns the
    /// teaching — which is worse.
    func testLinesPairUpBetweenArabicPhoneticAndTranslation() {
        for language in [AppLanguage.en, .fr] {
            for step in PrayerContent.steps(for: language) where step.spoken {
                XCTAssertEqual(step.arabicLines.count, step.phoneticLines.count,
                               "\(language.rawValue)/\(step.id): phonetic lines do not match the Arabic")
                XCTAssertEqual(step.arabicLines.count, step.translationLines.count,
                               "\(language.rawValue)/\(step.id): translation lines do not match the Arabic")
            }
        }
    }

    func testUIStringsExistInEveryLanguage() {
        let english = Localizer(language: .en)
        let keys = ["tab.learn", "tab.practice", "tab.settings",
                    "detail.phonetic", "detail.translation",
                    "practice.title", "settings.disclaimer", "onboarding.1.title"]
        for language in AppLanguage.shipped {
            let loc = Localizer(language: language)
            for key in keys {
                XCTAssertNotEqual(loc.t(key), key, "\(language.rawValue) has no string for \(key)")
                _ = english.t(key)
            }
        }
    }

    func testSystemLanguageAlwaysResolvesToSomethingWeShip() {
        XCTAssertTrue(AppLanguage.shipped.contains(AppLanguage.resolvedFromSystem()))
    }
}

/// The widget's rotation is pure arithmetic on the clock, so it can be tested
/// without WidgetKit — which is exactly why it lives in the kit and not in the
/// extension.
final class CarouselClockTests: XCTestCase {

    func testIndexWrapsAndStaysInRange() {
        for tick in -100...100 {
            let i = CarouselClock.index(tick: tick, count: 14)
            XCTAssertTrue((0..<14).contains(i), "tick \(tick) produced \(i)")
        }
    }

    func testIndexAdvancesOneStepPerInterval() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let count = PrayerContent.steps(for: .en).count
        let first = CarouselClock.index(at: start, count: count)
        let next = CarouselClock.index(at: start.addingTimeInterval(CarouselClock.interval),
                                       count: count)
        XCTAssertEqual(next, (first + 1) % count)
    }

    /// Two widgets refreshed at different moments of the same minute must show
    /// the same step, otherwise they visibly disagree on the home screen. The
    /// boundary is the clock minute itself, not "within 60s of each other".
    func testTwoWidgetsWithinTheSameMinuteAgree() {
        let minuteStart = Date(timeIntervalSince1970: 1_700_000_040) // 60-aligned
        let count = 14
        for offset in [0.0, 1, 30, 59.9] {
            XCTAssertEqual(
                CarouselClock.index(at: minuteStart, count: count),
                CarouselClock.index(at: minuteStart.addingTimeInterval(offset), count: count),
                "widgets refreshed \(offset)s apart in the same minute disagree"
            )
        }
    }

    func testNoStepsDoesNotCrash() {
        XCTAssertEqual(CarouselClock.index(tick: 7, count: 0), 0)
    }
}

/// The onboarding trapped the user: `shouldShowOnboarding` read UserDefaults
/// through a computed property, which `@Observable` does not track, so
/// finishing changed the defaults without ever re-rendering the sheet.
final class OnboardingManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
        UserDefaults.standard.removeObject(forKey: "alwaysShowOnboarding")
    }

    func testFinishingLetsYouIntoTheApp() {
        let onboarding = OnboardingManager()
        XCTAssertTrue(onboarding.shouldShowOnboarding, "a fresh install should onboard")
        onboarding.markSeen()
        XCTAssertFalse(onboarding.shouldShowOnboarding, "finishing must open the app")
    }

    func testFinishingSurvivesRelaunch() {
        OnboardingManager().markSeen()
        XCTAssertFalse(OnboardingManager().shouldShowOnboarding,
                       "the app must not onboard again on the next launch")
    }

    #if DEBUG
    /// With the dev toggle on, finishing must still get you in — otherwise the
    /// sheet re-presents itself immediately and there is no way out.
    func testDevToggleCannotTrapYouInTheOnboarding() {
        let onboarding = OnboardingManager()
        onboarding.alwaysShowOnboarding = true
        XCTAssertTrue(onboarding.shouldShowOnboarding)
        onboarding.markSeen()
        XCTAssertFalse(onboarding.shouldShowOnboarding)
    }
    #endif
}
