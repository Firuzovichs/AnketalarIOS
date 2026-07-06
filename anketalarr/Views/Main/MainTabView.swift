import SwiftUI

private struct TabItem {
    let icon: String
    let activeIcon: String
    let label: String
}

private let tabItems: [TabItem] = [
    .init(icon: "house",           activeIcon: "house.fill",             label: "Bosh"),
    .init(icon: "magnifyingglass", activeIcon: "sparkle.magnifyingglass", label: "Qidirish"),
    .init(icon: "heart",           activeIcon: "heart.fill",              label: "Like"),
    .init(icon: "message",         activeIcon: "message.fill",            label: "Chat"),
    .init(icon: "person.circle",   activeIcon: "person.circle.fill",      label: "Profil"),
]

struct MainTabView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @State private var selectedTab = 0
    // Chat tab-bar badge butun ilova davomida bitta manbadan kelishi uchun
    // ViewModel shu yerda (egasi) yaratiladi va ChatListView ga beriladi.
    @StateObject private var chatVM = ChatListViewModel()
    // Ilova bo'ylab BARCHA "Premium kerak" joylari shu umumiy darvoza orqali
    // bitta Obuna sahifasiga (SubscriptionView) yo'naltiriladi — qarang
    // Managers/PaywallGate.swift. Autentifikatsiyadan o'tgan butun daraxtga
    // .environmentObject orqali uzatiladi.
    @StateObject private var paywallGate = PaywallGate()

    private let tabBarH: CGFloat = 56
    private let bottomPad: CGFloat = 28   // home indicator clearance

    var body: some View {
        // GeometryReader gives us the exact available width/height
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barH = tabBarH + bottomPad

            ZStack(alignment: .bottom) {
                // ── Tab content ────────────────────────────────────────
                Group {
                    switch selectedTab {
                    case 1:  MapTabView()
                    case 2:  LikeTabView()
                    case 3:  ChatListView(vm: chatVM)
                    case 4:  ProfileView()
                    default: DashboardView()
                    }
                }
                .frame(width: w, height: h)  // exact size, no ambiguity

                // ── Tab bar ────────────────────────────────────────────
                VStack(spacing: 0) {
                    // Top shadow line
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 0.5)

                    HStack(spacing: 0) {
                        ForEach(tabItems.indices, id: \.self) { i in
                            tabButton(tabItems[i], index: i, width: w / CGFloat(tabItems.count))
                        }
                    }
                    .frame(width: w, height: tabBarH)

                    // Home indicator spacer
                    Color(.systemBackground)
                        .frame(width: w, height: bottomPad)
                }
                .frame(width: w)
                .background(Color(.systemBackground))
            }
            .frame(width: w, height: h)
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .environmentObject(paywallGate)
        .fullScreenCover(isPresented: $paywallGate.isPresented) {
            SubscriptionView()
        }
        .task {
            // Tab-bar badge'i qaysi tab ochiq bo'lishidan qat'i nazar to'g'ri
            // ko'rsatilishi uchun suhbatlar ro'yxati ilova ochilganda darrov yuklanadi.
            await chatVM.loadInitial()
            chatVM.startPolling()
        }
    }

    // MARK: - Tab button

    private func tabButton(_ item: TabItem, index: Int, width: CGFloat) -> some View {
        let active = selectedTab == index
        let badge = index == 3 ? chatVM.totalUnread : 0
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = index
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                if active {
                    Image(systemName: item.activeIcon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 36)
                        .background(Capsule().fill(theme.buttonGradient))
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 21, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 48, height: 36)
                }

                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -2)
                }
            }
            .frame(width: width, height: tabBarH)  // exact width per tab
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    MainTabView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
