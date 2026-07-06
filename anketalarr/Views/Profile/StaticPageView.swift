import SwiftUI

/// Backend'dan keladigan statik sahifa — Biz haqimizda / Foydalanish shartlari /
/// Maxfiylik siyosati. Sozlamalar ekranidan alohida sahifa sifatida ochiladi
/// (NavigationStack push), kontent admin paneldan tahrirlanadi.
struct StaticPageView: View {
    let slug: String

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @StateObject private var vm = StaticPageViewModel()

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if vm.isLoading {
                ProgressView()
                    .tint(theme.primary)
            } else if let err = vm.errorMsg {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(theme.textSecondary.opacity(0.6))
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(vm.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(theme.textPrimary)

                        Text(vm.content)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textSecondary)
                            .lineSpacing(5)
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(vm.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(slug: slug) }
    }
}

#Preview {
    NavigationStack {
        StaticPageView(slug: "about")
            .environmentObject(AppTheme())
            .environmentObject(LocalizationManager())
    }
}
