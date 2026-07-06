import SwiftUI

@main
struct AnketalarApp: App {
    @StateObject private var theme = AppTheme()
    @StateObject private var lang  = LocalizationManager()

    init() {
        #if canImport(YandexMapsMobile)
        YandexMapConfig.setupIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .environmentObject(lang)
        }
    }
}

// MARK: - Root Router
struct RootView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @AppStorage("onboarding_done")   private var onboardingDone   = false
    @AppStorage("access_token")      private var accessToken      = ""
    @AppStorage("profile_setup_done") private var profileSetupDone = false

    var body: some View {
        ZStack {
            if !onboardingDone {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) { onboardingDone = true }
                }
                .transition(.asymmetric(insertion: .opacity,
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            } else if accessToken.isEmpty {
                LoginView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            } else if !profileSetupDone {
                ProfileSetupView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboardingDone)
        .animation(.easeInOut(duration: 0.35), value: accessToken.isEmpty)
        .animation(.easeInOut(duration: 0.35), value: profileSetupDone)
    }
}

// MARK: - Vaqtinchalik bosh ekran
private struct LoggedInPlaceholder: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @AppStorage("access_token") private var accessToken = ""

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(theme.primary)
                Text(lang[.loginOK])
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Text(lang[.soonMsg])
                    .font(.system(size: 15))
                    .foregroundColor(theme.textSecondary)
                Button {
                    TokenManager.shared.clear()
                    accessToken = ""
                } label: {
                    Text(lang[.logout])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 160, height: 48)
                        .background(theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}
