import SwiftUI

/// Quatorze langues + « celle de mon téléphone », c'était la moitié des
/// réglages pour un choix qu'on fait une fois. La liste est sortie dans sa
/// propre feuille ; les réglages n'en gardent qu'une ligne.
struct LanguagePickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.loc) private var loc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            StarLattice().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    Text(loc.t("settings.language"))
                        .font(Theme.title(26))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 44) // laisse passer la croix
                        .padding(.bottom, 6)

                    row(.system, label: loc.t("settings.language.system"))
                    ForEach(AppLanguage.shipped) { language in
                        row(language, label: language.nativeName)
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
            }
            .chunky(Theme.sand, radius: 12, depth: 3)
            .padding(16)
        }
    }

    private func row(_ language: AppLanguage, label: String) -> some View {
        let isOn = settings.languagePreference == language
        return Button {
            withAnimation(Theme.spring) { settings.languagePreference = language }
        } label: {
            HStack(spacing: 12) {
                // `flagless` rend un nom de symbole pour `.system` : c'est une
                // icône, pas un code de langue, et l'écrire en toutes lettres
                // affichait « globe » coupé en deux.
                Group {
                    if language == .system {
                        Image(systemName: language.flagless)
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Text(language.flagless)
                            .font(Theme.label(12))
                    }
                }
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 30, alignment: .leading)

                Text(label)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)

                Spacer()

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
            }
            // Le code de langue reste à gauche même en arabe : c'est une
            // colonne de repères, pas une phrase.
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .chunky(isOn ? Theme.goldSoft : Theme.sand, depth: isOn ? 4 : 0, haptic: .select)
        .accessibilityIdentifier("settings.language.\(language.rawValue)")
    }
}
