import Foundation

/// Whether Salat Premium is active, as the **widget** needs to know it.
///
/// The subscription is the App Store's to say, and only the app can ask it
/// (`Store`, StoreKit 2). The extension cannot: it is given a few milliseconds
/// to draw. So the app writes the answer here, in the shared suite, every time
/// it learns it, and nudges WidgetKit.
///
/// A plain yes/no on purpose, with no expiry date beside it. A date would lock
/// the widget at the end of every paid month until the app is next opened to
/// see the renewal, and the reader who pays would be the one punished. The
/// cost of the other choice is a lapsed subscription that keeps its widget
/// until the app's next launch, which is the right side to err on.
public enum Premium {
    public static var isActive: Bool {
        get { SharedStore.defaults.bool(forKey: SharedStore.Key.premium) }
        set { SharedStore.defaults.set(newValue, forKey: SharedStore.Key.premium) }
    }

    /// What a locked widget opens when tapped: the app, on its paywall.
    public static let unlockURL = URL(string: "salat://premium")!
}
