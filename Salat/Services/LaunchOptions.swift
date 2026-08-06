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

    /// `-startTab widgetPreview` shows the widget layouts instead of a tab.
    static var showsWidgetPreview: Bool { value("-startTab") == "widgetPreview" }
}
