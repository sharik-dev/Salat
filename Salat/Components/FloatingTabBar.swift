import SwiftUI

enum AppTab: CaseIterable {
    case learn, practice, settings

    var icon: String {
        switch self {
        case .learn:    return "book.closed.fill"
        case .practice: return "sparkles.rectangle.stack.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var titleKey: String {
        switch self {
        case .learn:    return "tab.learn"
        case .practice: return "tab.practice"
        case .settings: return "tab.settings"
        }
    }
}

/// Same floating-glass structure as the house convention, recoloured for a
/// light paper background: ink on cream, a gold pill behind the active tab
/// instead of a neon glow, which would be unreadable here.
struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabBarButton(tab: tab, isSelected: selectedTab == tab, title: loc.t(tab.titleKey)) {
                    withAnimation(Theme.spring) { selectedTab = tab }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(glassBackground)
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
                    .fill(Theme.surface.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.10), radius: 18, y: 6)
    }
}

private struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(Theme.label(10))
            }
            .foregroundStyle(isSelected ? Theme.ink : Theme.inkSoft.opacity(0.75))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.goldSoft.opacity(0.55) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(tab)")
        .animation(Theme.spring, value: isSelected)
    }
}
