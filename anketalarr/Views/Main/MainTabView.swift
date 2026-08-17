import SwiftUI

private struct TabItem {
    let icon: String
    let activeIcon: String
    let label: String
}

private let tabItems: [TabItem] = [
    .init(icon: "house",           activeIcon: "house.fill",              label: "Bosh"),
    .init(icon: "magnifyingglass", activeIcon: "sparkle.magnifyingglass", label: "Qidirish"),
    .init(icon: "heart",           activeIcon: "heart.fill",              label: "Like"),
    .init(icon: "message",         activeIcon: "message.fill",            label: "Chat"),
    .init(icon: "person.circle",   activeIcon: "person.circle.fill",      label: "Profil"),
]

struct MainTabView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @State private var selectedTab = 0
    @State private var prevTab     = 0
    @StateObject private var chatVM    = ChatListViewModel()
    @StateObject private var paywallGate = PaywallGate()

    private let tabBarH: CGFloat = 64

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bottomSpacing: CGFloat = geo.safeAreaInsets.bottom > 0 ? 6 : 10

            ZStack(alignment: .bottom) {

                // ── Tab content (fade animatsiya) ──────────────────────
                ZStack {
                    tabContent(0).opacity(selectedTab == 0 ? 1 : 0)
                    tabContent(1).opacity(selectedTab == 1 ? 1 : 0)
                    tabContent(2).opacity(selectedTab == 2 ? 1 : 0)
                    tabContent(3).opacity(selectedTab == 3 ? 1 : 0)
                    tabContent(4).opacity(selectedTab == 4 ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.22), value: selectedTab)
                .frame(width: w, height: h)

                // SwiftUI safe area'ni avtomatik hisoblaydi. Kichik qo'shimcha
                // masofa menyuni Home Indicator ustida, ammo pastga yaqin tutadi.
                HStack(spacing: 0) {
                    ForEach(tabItems.indices, id: \.self) { i in
                        tabButton(tabItems[i], index: i, width: (w - 32) / CGFloat(tabItems.count))
                    }
                }
                .frame(height: tabBarH)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 6)
                .padding(.horizontal, 16)
                .padding(.bottom, bottomSpacing)
            }
            .frame(width: w, height: h)
        }
        .environmentObject(paywallGate)
        .fullScreenCover(isPresented: $paywallGate.isPresented) {
            SubscriptionView()
        }
        .task {
            await chatVM.loadInitial()
            chatVM.startPolling()
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private func tabContent(_ index: Int) -> some View {
        switch index {
        case 1:  MapTabView()
        case 2:  LikeTabView()
        case 3:  ChatListView(vm: chatVM)
        case 4:  ProfileView()
        default: DashboardView()
        }
    }

    // MARK: - Tab button

    private func tabButton(_ item: TabItem, index: Int, width: CGFloat) -> some View {
        let active = selectedTab == index
        let badge  = index == 3 ? chatVM.totalUnread : 0
        let color  = active ? theme.primary : Color(.secondaryLabel)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = index
            }
        } label: {
            ZStack {
                // ── Doira fon — faol tab uchun ──
                if active {
                    Capsule()
                        .fill(Color(.label).opacity(0.1))
                        .frame(width: 74, height: 52)
                }

                // ── Icon + label ─────────────────────
                VStack(spacing: 3) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: active ? item.activeIcon : item.icon)
                            .font(.system(size: 24, weight: active ? .semibold : .regular))
                            .foregroundColor(color)
                            .scaleEffect(active ? 1.08 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: active)
                            .frame(width: 30, height: 26)

                        if badge > 0 {
                            Text(badge > 99 ? "99+" : "\(badge)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .offset(x: 12, y: -4)
                        }
                    }

                    Text(item.label)
                        .font(.system(size: 11, weight: active ? .semibold : .regular))
                        .foregroundColor(color)
                }
            }
            .frame(width: width, height: tabBarH)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
