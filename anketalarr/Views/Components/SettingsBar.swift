import SwiftUI

/// Til va tema dropdownlarini ZStack darajasida ko'rsatuvchi overlay.
/// `hasBackButton: true` bo'lsa ikkala tugma ham o'ng tomonga siljiydi —
/// orqaga tugma bilan overlap bo'lmaydi.
struct SettingsBar: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager

    /// Orqaga tugma borligi — true bo'lsa ikkala tugma o'ngda joylashadi
    var hasBackButton: Bool = false

    @State private var active: ActiveMenu = .none
    enum ActiveMenu { case none, language, theme }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Dismiss layer ──────────────────────────────────────────────
            if active != .none {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
            }

            // ── Dropdownlar ────────────────────────────────────────────────
            if active == .language { langDropdown }
            if active == .theme    { themeDropdown }

            // ── Tugmalar ───────────────────────────────────────────────────
            HStack(spacing: 0) {
                if !hasBackButton {
                    // Orqaga tugma yo'q → til tugmasi chap tomonda
                    langButton.padding(.leading, 20)
                    Spacer()
                    themeButton.padding(.trailing, 20)
                } else {
                    // Orqaga tugma bor → ikkala tugma o'ng tomonda
                    Spacer()
                    HStack(spacing: 8) {
                        langButton
                        themeButton
                    }
                    .padding(.trailing, 20)
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Tugma label-lari
    private var langButton: some View {
        Button { toggle(.language) } label: {
            Text(lang.language.flag)
                .font(.system(size: 20))
                .frame(width: 42, height: 42)
                .background(theme.primaryLight)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    private var themeButton: some View {
        Button { toggle(.theme) } label: {
            Image(systemName: theme.current.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(theme.primary)
                .frame(width: 42, height: 42)
                .background(theme.primaryLight)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Lang dropdown
    private var langDropdown: some View {
        VStack(spacing: 0) {
            ForEach(AppLanguage.allCases, id: \.self) { l in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        lang.language = l; active = .none
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(l.flag).font(.system(size: 20))
                        Text(l.displayName)
                            .font(.system(size: 15,
                                          weight: l == lang.language ? .semibold : .regular))
                            .foregroundColor(l == lang.language ? theme.primary : .primary)
                        Spacer()
                        if l == lang.language {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(theme.primary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 6)
        .frame(width: 170)
        .padding(.top, 64)
        // hasBackButton bo'lsa dropdown ham o'ngda — aks holda chapda
        .if(hasBackButton) { $0.padding(.trailing, 20).frame(maxWidth: .infinity, alignment: .trailing) }
        .if(!hasBackButton) { $0.padding(.leading, 20) }
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    }

    // MARK: - Theme dropdown (har doim o'ngda)
    private var themeDropdown: some View {
        VStack(spacing: 0) {
            ForEach(AppThemeType.allCases, id: \.self) { t in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        theme.current = t; active = .none
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: t.icon)
                            .font(.system(size: 16))
                            .foregroundColor(t == theme.current ? theme.primary : .gray)
                        Text(lang[t.locKey])
                            .font(.system(size: 15,
                                          weight: t == theme.current ? .semibold : .regular))
                            .foregroundColor(t == theme.current ? theme.primary : .primary)
                        Spacer()
                        if t == theme.current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(theme.primary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 6)
        .frame(width: 170)
        .padding(.top, 64).padding(.trailing, 20)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing)))
    }

    // MARK: - Helpers
    private func toggle(_ menu: ActiveMenu) {
        withAnimation(.spring(response: 0.25)) {
            active = active == menu ? .none : menu
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.25)) { active = .none }
    }
}

// MARK: - Conditional modifier helper
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool,
                                transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}
