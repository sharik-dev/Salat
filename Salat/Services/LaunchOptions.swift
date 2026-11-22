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
        case "quran":    return .quran
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

    /// `-celebrate 1` (with `-openStep`) plays the "step acquired" moment on
    /// arrival: it only exists for two seconds after a tap, and nobody is here
    /// to tap.
    static var celebrates: Bool { value("-celebrate") == "1" }

    /// `-welcomePage 0…5` opens the onboarding on that pitch page (0 the
    /// feed, 1 the hours question, 2 the reckoning, 3–5 the app; past the
    /// question, 4 h is assumed when nothing was answered), `-welcomeBeat N`
    /// freezes its animated scene on beat N (99 = the last), `-welcomeQuestion
    /// 0` opens the last screen (the daily moment) directly. All three need
    /// `-resetOnboarding 1`: the scenes loop on their own and the last screen
    /// sits behind six taps.
    static var welcomePage: Int? { value("-welcomePage").flatMap(Int.init) }
    static var welcomeBeat: Int? { value("-welcomeBeat").flatMap(Int.init) }
    static var welcomeQuestion: Int? { value("-welcomeQuestion").flatMap(Int.init) }

    /// `-openReciters 1` / `-openAbout 1` open those two sheets of the
    /// settings, which sit behind a row each.
    static var opensReciters: Bool { value("-openReciters") == "1" }

    /// `-openWidgetGuide 1` (with `-openTool widget`) opens the "add the
    /// widget" guide, `-guidePage 0…2` on that page: a sheet behind a button,
    /// then two swipes.
    static var opensWidgetGuide: Bool { value("-openWidgetGuide") == "1" }
    static var guidePage: Int? { value("-guidePage").flatMap(Int.init) }
    static var opensAbout: Bool { value("-openAbout") == "1" }

    /// `-startTab quran -quranSurah 2 -quranVerse 255` opens the feed on a
    /// given verse (verse 0, or none, is the surah's opening page);
    /// `-quranMuted 1` opens it silent, `-openSurahs 1` opens the surah list.
    /// The feed resumes where it was left, so without these a screenshot
    /// shows whatever verse the last run stopped on.
    static var quranStart: (surah: Int, verse: Int)? {
        guard let surah = value("-quranSurah").flatMap(Int.init) else { return nil }
        return (surah, value("-quranVerse").flatMap(Int.init) ?? 0)
    }
    static var forcesQuranMuted: Bool { value("-quranMuted") == "1" }
    static var opensSurahs: Bool { value("-openSurahs") == "1" }
    /// `-openQuranNotes 1` opens the notes of the verse the feed starts on,
    /// `-openQuranSaved 1` the list of liked and annotated verses.
    static var opensQuranNotes: Bool { value("-openQuranNotes") == "1" }
    static var opensQuranSaved: Bool { value("-openQuranSaved") == "1" }

    /// `-premium 1|0` (DEBUG) forces Salat Premium on or off, whatever the
    /// App Store says: a simulator launched from the command line has bought
    /// nothing and never will, so the unlocked widget page could not be seen.
    /// Nil everywhere else, where the App Store is the only one who answers.
    static var forcedPremium: Bool? {
        switch value("-premium") {
        case "1": return true
        case "0": return false
        default:  return nil
        }
    }

    /// `-openPaywall 1` opens the subscriber's Premium sheet on arrival (a
    /// non-subscriber sees the paywall anyway), and `-paywallPrice "4,99 €"`
    /// (DEBUG) prints that price on it: without a StoreKit session no product
    /// loads, and the screen would only ever show its "cannot be reached"
    /// state. `-paywallTrial 3` promises that many free days (0 = no trial).
    static var opensPaywall: Bool { value("-openPaywall") == "1" }
    static var paywallPrice: String? { value("-paywallPrice") }
    static var paywallTrial: Int? { value("-paywallTrial").flatMap(Int.init) }

    /// `-forceNudge review` (DEBUG) makes the next pause (a step page closed,
    /// a round finished) ask for a rating, whatever the history says: the real
    /// thing waits for days of use.
    static var forcedNudge: String? { value("-forceNudge") }

    /// `-widgetScope quran|learning|all|one` (DEBUG) sets what the widget
    /// shows for this launch, and `-openExcerpts 1` (with `-openTool widget`)
    /// opens the list of Qur'an excerpts: a menu, then a sheet behind a row.
    static var widgetScope: String? { value("-widgetScope") }
    static var opensExcerpts: Bool { value("-openExcerpts") == "1" }

    /// `-widgetLocked 1` (with `-startTab widgetPreview`) draws the widget as
    /// the home screen shows it without a subscription.
    static var showsLockedWidget: Bool { value("-widgetLocked") == "1" }
}
