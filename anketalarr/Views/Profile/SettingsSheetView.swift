import SwiftUI

// Profil ekranidagi sozlamalar (til, mavzu, akauntdan chiqish) — gear
// tugmasi orqali sheet sifatida ochiladi.
struct SettingsSheetView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    // Bu sheet DashboardView/ProfileView'dan ALOHIDA `.sheet` sifatida
    // ochiladi — shu sababli MainTabView darajasidagi umumiy Obuna darvozasi
    // bu yerga avtomatik tarqalmaydi (xuddi ChatConversationView'dagi kabi).
    // Shu sababli chaqiruvchi tomon `.environmentObject(paywallGate)`ni
    // ALOHIDA qayta in'ektsiya qilishi, VA shu yerda ALOHIDA ikkinchi
    // `.fullScreenCover` bo'lishi shart (pastga, body oxiriga qarang).
    @EnvironmentObject var paywallGate: PaywallGate
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirm = false
    @AppStorage("access_token") private var accessToken = ""

    @State private var showAbout   = false
    @State private var showTerms   = false
    @State private var showPrivacy = false

    @StateObject private var deletionVM = AccountDeletionViewModel()
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            subscriptionCard
                            languageCard
                            themeCard
                            infoCard
                            logoutCard
                            deleteAccountCard
                        }
                        .padding(20)
                    }
                }
            }
            .navigationDestination(isPresented: $showAbout)   { StaticPageView(slug: "about") }
            .navigationDestination(isPresented: $showTerms)   { StaticPageView(slug: "terms") }
            .navigationDestination(isPresented: $showPrivacy) { StaticPageView(slug: "privacy") }
        }
        .task { await deletionVM.fetchStatus() }
        .alert(lang[.profLogoutConfirmTitle], isPresented: $showLogoutConfirm) {
            Button(lang[.cancel], role: .cancel) {}
            Button(lang[.logout], role: .destructive) {
                TokenManager.shared.clear()
                accessToken = ""
            }
        } message: {
            Text(lang[.profLogoutConfirmMsg])
        }
        .alert(lang[.settingsDeleteAccountConfirmTitle], isPresented: $showDeleteConfirm) {
            Button(lang[.cancel], role: .cancel) {}
            Button(lang[.settingsDeleteAccountConfirmBtn], role: .destructive) {
                Task { await deletionVM.sendRequest() }
            }
        } message: {
            Text(lang[.settingsDeleteAccountConfirmMsg])
        }
        // Bu sheet o'zi ChatListView'ning hamkasbi kabi alohida modal qatlami
        // ICHIDA turibdi — shu sababli MainTabView darajasidagi Obuna cover'i
        // bu yerga "ko'rinmaydi". Xuddi shu umumiy `paywallGate`ni kuzatuvchi
        // ALOHIDA, ikkinchi `.fullScreenCover` shart (joriy sheet ustiga
        // ochilishi uchun).
        .fullScreenCover(isPresented: $paywallGate.isPresented) {
            SubscriptionView()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
            Spacer()
            Text(lang[.profSettings])
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Shared card chrome

    private func sectionIcon(_ systemName: String, tint: Color, tintLight: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 36, height: 36)
            .background(Circle().fill(tintLight))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardBackground)
                .shadow(color: theme.primary.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Subscription (Obuna)
    // Sozlamalar ichidagi alohida kirish nuqtasi — bosilganda to'g'ridan-to'g'ri
    // umumiy Obuna sahifasini ochadi (boshqa barcha "Premium kerak" joylari
    // bilan bir xil `paywallGate` orqali).

    private var subscriptionCard: some View {
        Button { paywallGate.present() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.22)).frame(width: 36, height: 36)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(lang[.subNavTitle])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(colors: [Color.red, theme.primary, Color.orange],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: theme.primary.opacity(0.25), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Language

    private var languageCard: some View {
        card {
            HStack(spacing: 12) {
                sectionIcon("globe", tint: theme.primary, tintLight: theme.primaryLight)
                Text(lang[.profLanguage])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(AppLanguage.allCases, id: \.self) { l in
                    let sel = lang.language == l
                    Button {
                        withAnimation(.spring(response: 0.25)) { lang.language = l }
                    } label: {
                        VStack(spacing: 4) {
                            Text(l.flag).font(.system(size: 20))
                            Text(l.displayName)
                                .font(.system(size: 12, weight: sel ? .bold : .medium))
                        }
                        .foregroundColor(sel ? .white : theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(sel ? AnyShapeStyle(theme.buttonGradient) : AnyShapeStyle(theme.primaryLight))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Theme

    private var themeCard: some View {
        card {
            HStack(spacing: 12) {
                sectionIcon("paintpalette.fill", tint: theme.primary, tintLight: theme.primaryLight)
                Text(lang[.profTheme])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(AppThemeType.allCases, id: \.self) { t in
                    let sel = theme.current == t
                    Button {
                        withAnimation(.spring(response: 0.25)) { theme.current = t }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(lang[t.locKey])
                                .font(.system(size: 12, weight: sel ? .bold : .medium))
                        }
                        .foregroundColor(sel ? .white : theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(sel ? AnyShapeStyle(theme.buttonGradient) : AnyShapeStyle(theme.primaryLight))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Info pages (Biz haqimizda / Foydalanish shartlari / Maxfiylik siyosati)
    // Kontent backenddan keladi (apps/home StaticPage), admin paneldan tahrirlanadi.

    private func infoRow(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                sectionIcon(icon, tint: theme.primary, tintLight: theme.primaryLight)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }

    private var infoCard: some View {
        VStack(spacing: 14) {
            infoRow("info.circle.fill", lang[.settingsAbout])   { showAbout = true }
            Divider()
            infoRow("doc.text.fill", lang[.settingsTerms])      { showTerms = true }
            Divider()
            infoRow("lock.shield.fill", lang[.settingsPrivacy]) { showPrivacy = true }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardBackground)
                .shadow(color: theme.primary.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Logout

    private var logoutCard: some View {
        Button { showLogoutConfirm = true } label: {
            HStack(spacing: 12) {
                sectionIcon("rectangle.portrait.and.arrow.right", tint: .red, tintLight: Color.red.opacity(0.12))
                Text(lang[.logout])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red.opacity(0.5))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardBackground)
                    .shadow(color: Color.red.opacity(0.06), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete account
    // MUHIM: bu faqat backendga so'rov yuboradi (AccountDeletionRequest) —
    // hisob shu yerda hech qachon o'chirilmaydi. Admin tasdiqlasa,
    // backend user.is_active=False qiladi va u boshqa login qila olmaydi.

    private var deleteAccountCard: some View {
        Group {
            if deletionVM.isPending {
                HStack(spacing: 12) {
                    sectionIcon("clock.fill", tint: .orange, tintLight: Color.orange.opacity(0.12))
                    Text(lang[.settingsDeleteAccountPending])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.cardBackground)
                        .shadow(color: Color.orange.opacity(0.06), radius: 10, x: 0, y: 4)
                )
            } else {
                Button { showDeleteConfirm = true } label: {
                    HStack(spacing: 12) {
                        sectionIcon("trash.fill", tint: .red, tintLight: Color.red.opacity(0.12))
                        Text(lang[.settingsDeleteAccount])
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red.opacity(0.5))
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(theme.cardBackground)
                            .shadow(color: Color.red.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    SettingsSheetView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
