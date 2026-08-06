import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        .padding(.vertical, 7)
        .padding(.horizontal, 7)
        // The bar is a plate like everything else, not frosted glass: on cream
        // paper a material reads as nothing at all, and the app is meant to
        // feel like objects on a table.
        .plate(Theme.surface, radius: Theme.Radius.bar)
        .padding(.horizontal, 26)
        .padding(.bottom, 8)
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
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        // Only the active tab is an object: a raised gold plate. The others
        // carry no outline at all — three outlined boxes inside an outlined
        // bar reads as a box in a box, and nothing stands out.
        .buttonStyle(TabButtonStyle(isSelected: isSelected))
        .accessibilityIdentifier("tab.\(tab)")
        .animation(Theme.spring, value: isSelected)
    }
}

/// A chunky plate when selected, a bare label otherwise — and the bare label
/// keeps the same footprint, so the row does not shift as you switch tabs.
private struct TabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        TabButtonBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct TabButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @State private var bursts: [UUID] = []

    var body: some View {
        let pressed = configuration.isPressed
        let depth: CGFloat = 4

        return configuration.label
            .foregroundStyle(isSelected ? Theme.ink : Theme.inkSoft)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.goldSoft : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? Theme.ink : .clear,
                                          lineWidth: Theme.stroke)
                    )
            )
            .offset(y: pressed && isSelected ? depth - Theme.chunkPressed : 0)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.shade(Theme.goldSoft) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? Theme.ink : .clear,
                                          lineWidth: Theme.stroke)
                    )
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
            .animation(.spring(response: 0.16, dampingFraction: 0.7), value: pressed)
            // Switching tab is a `select`, not a `press`: it is the detent of
            // a choice in a series, and it gets the blip rather than the click.
            .onChange(of: pressed) { _, isPressed in
                if isPressed { Haptic.select.play() } else { fireBurst() }
            }
            .overlay(
                ZStack {
                    ForEach(bursts, id: \.self) { _ in
                        StarBurst(color: Theme.ember, count: 7, spread: 22...50)
                    }
                }
                .allowsHitTesting(false)
            )
    }

    private func fireBurst() {
        let id = UUID()
        bursts.append(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            bursts.removeAll { $0 == id }
        }
    }
}
