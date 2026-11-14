import SwiftUI

enum AppTab: CaseIterable {
    case learn, quran, practice, settings

    var icon: Icon3D {
        switch self {
        case .learn:    return .book
        // A closed mushaf, so it cannot be mistaken for the open book next to
        // it: one is the lesson, the other is the Book.
        case .quran:    return .quran
        // A lit bulb, not a stack of cards: this tab is where it clicks,
        // because you are asked instead of shown.
        case .practice: return .bulb
        case .settings: return .gear
        }
    }

    var titleKey: String {
        switch self {
        case .learn:    return "tab.learn"
        case .quran:    return "tab.quran"
        // The case keeps its old name — `-startTab practice` is in every launch
        // script and in the deep links — but what the reader sees is what the
        // tab now does: memorise.
        case .practice: return "tab.memorize"
        case .settings: return "tab.settings"
        }
    }
}

/// The tab bar, docked like SelfTransfer's: four 3D objects on a white band.
/// The active one is in colour and hops every few seconds; the others are
/// greyed and still, so the eye never has to search for where it is.
struct NavBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let active = tab == selectedTab
                Button {
                    Haptic.select.play()
                    guard !active else { return }
                    withAnimation(.spring(duration: 0.35, bounce: 0.35)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 2) {
                        LofiIcon(tab.icon, size: 40, interval: 3, animated: active)
                            .saturation(active ? 1 : 0)
                            // Greyed, and a touch darker: a pale object (the
                            // bulb, the book's pages) would otherwise melt into
                            // the white band.
                            .brightness(active ? 0 : -0.14)
                            .opacity(active ? 1 : 0.62)
                            .scaleEffect(active ? 1.06 : 0.94)
                        Text(loc.t(tab.titleKey))
                            .font(Theme.rounded(12.5, active ? .black : .heavy))
                            .foregroundStyle(active ? Theme.primaryDeep : Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(active ? Theme.primarySoft : .clear,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab)")
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(alignment: .top) { Theme.line.frame(height: 2.5) }
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
    }
}
