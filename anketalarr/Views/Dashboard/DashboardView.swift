import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @EnvironmentObject var paywallGate: PaywallGate
    @StateObject private var vm = DashboardViewModel()

    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var selectedProfileUser: DashUser? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack(alignment: .topLeading) {
                theme.background.ignoresSafeArea()

                // ── Scroll content ─────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        DashStoriesRow(me: vm.me, stories: vm.stories,
                                      myStory: vm.myStory,
                                      onStoryPosted:  { Task { await vm.fetchMyStory() } },
                                      onStoryDeleted: { Task { await vm.deleteMyStory() } },
                                      onViewerClosed: { Task { await vm.fetchStories() } })
                        DashBannersRow(banners: vm.banners, screenWidth: w) { banner in
                            withAnimation(.spring()) { vm.selectedBanner = banner }
                        }
                        filterTabs(w: w)
                        peopleGrid(w: w)
                        newsSection(w: w)
                        Spacer().frame(height: 80)
                    }
                    .frame(width: w)   // exact width
                }
                .frame(width: w)
                .padding(.top, DashTopBar.barHeight)   // push below top bar

                // ── Top bar ─────────────────────────────────────────────
                DashTopBar(
                    me: vm.me,
                    unreadCount: vm.unreadCount,
                    onSettingsTap: { showSettings = true },
                    onBellTap:  { withAnimation(.spring()) { showNotifications = true } }
                )
                .frame(width: w)

                // notifications fullScreenCover — ZStack dan tashqarida

                // ── Detail sheets ──────────────────────────────────────
            }
            .frame(width: w)
        }
        .fullScreenCover(isPresented: $showNotifications, onDismiss: {
            Task { await vm.fetchUnreadCount() }
        }) {
            NotificationsPage()
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .fullScreenCover(item: $selectedProfileUser) { user in
            UserProfileView(user: user, onDismiss: { selectedProfileUser = nil })
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .fullScreenCover(item: $vm.selectedBanner) { banner in
            BannerBottomSheetOverlay(
                banner: banner,
                onDismiss: { vm.selectedBanner = nil }
            )
            .environmentObject(theme)
            .presentationBackground(.clear)
        }
        .fullScreenCover(item: $vm.selectedNews) { news in
            NewsBottomSheetOverlay(
                news: news,
                onDismiss: { vm.selectedNews = nil }
            )
            .environmentObject(theme)
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView()
                .environmentObject(theme)
                .environmentObject(lang)
                .environmentObject(paywallGate)
        }
        .onAppear {
            Task { await vm.fetchMe() }
            vm.loadAll()
        }
    }

    // MARK: - Filter tabs

    private func filterTabs(w: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(DashFilter.allCases, id: \.self) { f in
                Button {
                    withAnimation(.spring(response: 0.28)) { vm.switchFilter(f) }
                } label: {
                    VStack(spacing: 4) {
                        Text(f.title(lang: lang))
                            .font(.system(size: 14,
                                          weight: vm.selectedFilter == f ? .semibold : .regular))
                            .foregroundColor(vm.selectedFilter == f
                                             ? theme.primary : theme.textSecondary)
                        Capsule()
                            .fill(vm.selectedFilter == f ? theme.primary : Color.clear)
                            .frame(height: 3)
                    }
                }
                .frame(width: w / 3)
            }
        }
        .frame(width: w)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: - People grid

    private func peopleGrid(w: CGFloat) -> some View {
        let cardW = (w - 54) / 2   // 20 + 14 + 20 padding/spacing

        return VStack(spacing: 14) {
            if displayUsers.isEmpty {
                HStack(spacing: 14) {
                    skeletonCard(w: cardW)
                    skeletonCard(w: cardW)
                }
                .padding(.horizontal, 20)
                HStack(spacing: 14) {
                    skeletonCard(w: cardW)
                    skeletonCard(w: cardW)
                }
                .padding(.horizontal, 20)
            } else {
                let pairs: [[DashUser]] = stride(from: 0, to: displayUsers.count, by: 2).map { i in
                    Array(displayUsers[i ..< min(i + 2, displayUsers.count)])
                }
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(pair) { user in
                            Button {
                                if vm.viewerIsVip {
                                    selectedProfileUser = user
                                } else {
                                    paywallGate.present()
                                }
                            } label: {
                                DashPersonCard(user: user, cardWidth: cardW,
                                               viewerIsVip: vm.viewerIsVip)
                            }
                            .buttonStyle(.plain)
                        }
                        if pair.count == 1 {
                            Color.clear.frame(width: cardW, height: 200)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 8)
    }

    private var displayUsers: [DashUser] { Array(vm.users.prefix(4)) }

    private func skeletonCard(w: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(theme.primaryLight)
            .frame(width: w, height: 200)
    }

    // MARK: - News section

    private func newsSection(w: CGFloat) -> some View {
        Group {
            if !vm.news.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(lang[.dbNews])
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    ForEach(vm.news) { item in
                        DashNewsRow(news: item) {
                            withAnimation(.spring()) { vm.selectedNews = item }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

// MARK: - Scale press style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
