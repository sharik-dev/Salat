import Foundation

/// Lets a debug build be launched straight into a given screen:
///
///     xcrun simctl launch <udid> com.salat -startTab practice -openStep ruku
///
/// Sharik drives the Mac from his phone and only ever sees the simulator
/// through screenshots, so being able to land on the screen under review
/// without a human tapping is worth the two lines. Release builds ignore it.
enum LaunchOptions {
    private static func value(_ flag: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
        #else
        return nil
        #endif
    }

    static var startTab: AppTab {
        switch value("-startTab") {
        case "practice": return .practice
        case "settings": return .settings
        default:         return .learn
        }
    }

    /// Id of the step whose detail sheet should open on launch.
    static var openStep: String? { value("-openStep") }

    /// `-openTool vocal|carousel` pushes that tool of the *Revise* tab. With
    /// `-openStep` on top, the vocal tool lands directly on the step.
    static var openTool: String? { value("-openTool") }

    /// `-startTab widgetPreview` shows the widget layouts instead of a tab.
    static var showsWidgetPreview: Bool { value("-startTab") == "widgetPreview" }

    /// `-remindersOn 1` starts with the daily reminder switched on, so the
    /// time picker it reveals can be seen without tapping a switch and then a
    /// system permission alert.
    static var forcesRemindersOn: Bool { value("-remindersOn") == "1" }

    /// `-openLanguages 1` ouvre la liste des langues des réglages : elle est
    /// derrière un bouton depuis qu'elle prenait la moitié de l'écran, et
    /// personne n'est là pour taper dessus.
    static var opensLanguages: Bool { value("-openLanguages") == "1" }

    /// `-learnAll 1` (DEBUG) marks the fourteen steps known. The drill only
    /// asks about steps that have been read, so on a fresh simulator its screen
    /// is the empty state and nothing can be photographed.
    static var marksEverythingKnown: Bool { value("-learnAll") == "1" }

    /// `-openAnalytics 1` opens the progress page straight away — it lives
    /// behind a button in the *Learn* header, and nobody is here to tap it.
    static var opensAnalytics: Bool { value("-openAnalytics") == "1" }

    /// `-demoProgress 1` (DEBUG) fills the log with a few weeks of reading —
    /// steps acquired, steps still in progress, days ticked off. The analytics
    /// page is a picture of a history, and a history takes weeks to exist:
    /// there is no other way to look at that screen the day it is written.
    static var seedsDemoProgress: Bool { value("-demoProgress") == "1" }

    /// `-resetOnboarding 1` forces the onboarding to appear, so a UI test can
    /// walk it from the start on a device that has already seen it.
    static var resetsOnboarding: Bool { value("-resetOnboarding") == "1" }

    /// `-drillBoard pairs|order` (with `-openTool drill`) jumps the round to
    /// its first exercise of that kind. The boards sit in the middle of a
    /// round, behind two or four answered questions — unreachable at launch
    /// without this, so unphotographable.
    static var drillBoard: String? { value("-drillBoard") }

    /// `-drillVerdict right|wrong` (with `-openTool drill`) answers the first
    /// question on arrival, so the verdict bar — a state that only exists
    /// between a check and a continue — can be photographed.
    static var drillVerdict: String? { value("-drillVerdict") }

    /// `-recite 1` (with `-openStep`) starts "play every verse" on arrival.
    /// The karaoke cursor only exists while a voice sounds, and nobody is
    /// here to press play before the screenshot.
    static var autoRecites: Bool { value("-recite") == "1" }

    /// `-fadeLevel 0..3` (with `-openTool fade -openStep`) opens the fading
    /// ladder already climbed to that rung. The hidden words are the whole
    /// picture, and nobody is here to press the button before the screenshot.
    static var fadeLevel: Int? { value("-fadeLevel").flatMap(Int.init) }

    /// `-drillPicker 1` (with `-openTool drill`) stops on the exercise
    /// gallery instead of falling through into a dealt round — the round is
    /// what every older script expects, so the gallery needs its own switch.
    static var opensDrillPicker: Bool { value("-drillPicker") == "1" }
}
