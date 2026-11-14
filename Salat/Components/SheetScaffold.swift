import SwiftUI

/// The frame every sheet shares: beige page, a big title with its 3D object, a
/// round close button, and a scrolling body. Three sheets (language, reciter,
/// about) used to each rebuild this by hand.
struct SheetScaffold<Content: View>: View {
    let title: String
    var icon: Icon3D?
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    if let icon { LofiIcon(icon, size: 54, interval: 4) }
                    Text(title)
                        .font(Theme.title(26))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 50) // room for the close button
                }
                .padding(.bottom, 6)

                content()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.primaryDeep)
                    .frame(width: 38, height: 38)
            }
            .chunky(Theme.surface, radius: 19, depth: 3)
            .padding(16)
            .accessibilityIdentifier("sheet.close")
        }
    }
}

/// One answer among several: a white slab that turns mint and gains a green
/// rim and a tick once chosen. The same row serves the language list, the
/// reciter list and the onboarding questions.
struct ChoiceRow<Leading: View>: View {
    let title: String
    var subtitle: String?
    var subtitleTint: Color = Theme.inkSoft
    let selected: Bool
    @ViewBuilder var leading: () -> Leading
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) { action() }
        } label: {
            HStack(spacing: 12) {
                leading()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.rounded(17, .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.rounded(12.5, .heavy))
                            .foregroundStyle(subtitleTint)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(selected ? Theme.primary : Theme.border)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(Rectangle())
        }
        .chunky(selected ? Theme.primarySoft : Theme.surface, radius: 20, depth: 4, haptic: .select)
    }
}

extension ChoiceRow where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, subtitleTint: Color = Theme.inkSoft,
         selected: Bool, action: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, subtitleTint: subtitleTint,
                  selected: selected, leading: { EmptyView() }, action: action)
    }
}

/// The short code of a language on its little tile — a column of landmarks,
/// which is why it stays on the left even in Arabic.
struct LanguageCode: View {
    let language: AppLanguage

    var body: some View {
        Group {
            // `flagless` returns a symbol name for `.system`: it is an icon,
            // not a language code.
            if language == .system {
                Image(systemName: language.flagless).font(.system(size: 15, weight: .heavy))
            } else {
                Text(language.flagless).font(Theme.rounded(13, .black))
            }
        }
        .foregroundStyle(Theme.primaryDeep)
        .frame(width: 40, height: 34)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(Theme.primaryBorder, lineWidth: 2))
    }
}
