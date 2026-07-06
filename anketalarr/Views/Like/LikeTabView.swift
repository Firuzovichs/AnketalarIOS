import SwiftUI

/// "Like" tab — Tinder-uslubidagi swipe ekrani.
/// Bitta nomzodni karta sifatida ko'rsatadi, chapga/o'ngga surish (yoki tugmalar)
/// bilan skip/like qilinadi, mutual like bo'lsa "Match!" popup chiqadi.
struct LikeTabView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @StateObject private var vm = SwipeViewModel()

    @State private var triggerDirection: SwipeCardView.SwipeDirection? = nil
    /// "Habar bilan like" tugmasi bosilganda avval matn yozish oynasi
    /// (`likeMessageComposer`) ochiladi; "Like va yuborish" bosilgandagina
    /// shu matn shu yerga qo'yiladi va karta animatsiyasi ishga tushadi.
    @State private var pendingMessage: String? = nil
    @State private var showMessageComposer = false
    @State private var composedMessage = ""
    @State private var showFilter = false
    /// Karta rasmiga (yoki ⓘ belgisiga) bosilganda shu odamning to'liq
    /// profili (UserProfileView) shu orqali ochiladi.
    @State private var selectedProfile: DashUser? = nil

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                cardArea
                if vm.currentUser != nil && !vm.limitReached {
                    actionButtons
                        .padding(.top, 18)
                        // 84pt — pastki tab bar overlay balandligi (MainTabView: 56+28pt)
                        // + 14pt qo'shimcha bo'shliq. Shusiz tugmalar tab bar ostida ko'rinmaydi.
                        .padding(.bottom, 98)
                }
            }

            if let matched = vm.matchedUser {
                MatchPopupView(user: matched, onContinue: { vm.dismissMatch() })
                    .transition(.opacity)
            }

            // "Qidirish" (xarita) tabidagi bilan BIR XIL filtr sheet — kod
            // takrorlanmasligi uchun bitta `SearchFilterSheet` ikkala joyda
            // ham import qilinadi. Radius bu yerda yashirin (showRadius: false).
            if showFilter {
                DetailOverlay(isPresented: $showFilter) {
                    SearchFilterSheet(filters: vm.filters, showRadius: false, onApply: {
                        vm.applyFilters()
                        withAnimation(.spring()) { showFilter = false }
                    })
                }
                .zIndex(3)
            }

            if showMessageComposer {
                DetailOverlay(isPresented: $showMessageComposer) {
                    likeMessageComposer
                }
                .zIndex(4)
            }
        }
        .task {
            vm.filters.loadLookups()
            await vm.loadInitial()
        }
        .fullScreenCover(item: $selectedProfile) { user in
            UserProfileView(user: user, onDismiss: { selectedProfile = nil })
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.matchedUser != nil)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(lang[.likeTitle])
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            filterButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var filterButton: some View {
        Button {
            withAnimation(.spring()) { showFilter = true }
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(theme.primaryLight)
                    .frame(width: 38, height: 38)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .frame(width: 38, height: 38)

                if vm.filters.hasActiveFilters {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 1, y: -1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card stack

    @ViewBuilder
    private var cardArea: some View {
        ZStack {
            if vm.currentUser == nil && vm.isLoading {
                ProgressView().scaleEffect(1.3)
            } else if vm.limitReached {
                limitReachedView
            } else if vm.currentUser == nil {
                emptyStateView
            } else {
                if let peek = vm.nextUser {
                    SwipeCardView(
                        user: peek,
                        isInteractive: false,
                        triggerDirection: .constant(nil)
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
                }
                if let current = vm.currentUser {
                    SwipeCardView(
                        user: current,
                        isInteractive: true,
                        triggerDirection: $triggerDirection,
                        onSwipe: { dir in
                            triggerDirection = nil
                            let msg = pendingMessage
                            pendingMessage = nil
                            Task {
                                switch dir {
                                case .like: await vm.like(current, message: msg)
                                case .skip: await vm.skip(current)
                                }
                            }
                        },
                        onShowInfo: { selectedProfile = current }
                    )
                    .id(current.id)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action buttons

    // Tartib: chap — o'tkazib yuborish (X), o'rta — kattaroq Like, o'ng —
    // "habar bilan like" (avval matn yozish oynasi ochiladi, so'ng like ketadi).
    private var actionButtons: some View {
        HStack(spacing: 26) {
            circleButton(icon: "xmark", color: .red, size: 56) {
                triggerDirection = .skip
            }
            circleButton(icon: "heart.fill", color: theme.primary, size: 72) {
                triggerDirection = .like
            }
            // "message.fill" — text.bubble.fill ba'zi versiyalarda yo'q
            circleButton(icon: "message.fill", color: .blue, size: 56) {
                composedMessage = ""
                withAnimation(.spring()) { showMessageComposer = true }
            }
        }
    }

    // MARK: - "Habar bilan like" matn yozish oynasi

    private var likeMessageComposer: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Text(lang[.likeMsgSheetTitle])
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .padding(.top, 4)
                .padding(.bottom, 14)

            TextEditor(text: $composedMessage)
                .frame(height: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(theme.primaryLight.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if composedMessage.isEmpty {
                        Text(lang[.likeMsgPlaceholder])
                            .font(.system(size: 15))
                            .foregroundColor(theme.textSecondary.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 20)

            Divider().opacity(0.5).padding(.top, 16)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring()) { showMessageComposer = false }
                } label: {
                    Text(lang[.likeMsgCancel])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.primaryLight.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button {
                    let text = composedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    pendingMessage = text
                    withAnimation(.spring()) { showMessageComposer = false }
                    triggerDirection = .like
                } label: {
                    Text(lang[.likeMsgSend])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.buttonGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(composedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(composedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: -4)
    }

    private func circleButton(icon: String, color: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .disabled(vm.isActing || vm.currentUser == nil)
    }

    // MARK: - Empty / limit states

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 56))
                .foregroundColor(theme.primary.opacity(0.35))
            Text(lang[.likeEmptyTitle])
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(lang[.likeEmptySub])
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            refreshButton
        }
    }

    private var limitReachedView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [theme.primary.opacity(0.18), theme.primary.opacity(0.05)],
                                          startPoint: .top, endPoint: .bottom))
                    .frame(width: 72, height: 72)
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 28))
                    .foregroundColor(theme.primary)
            }
            Text(lang[.likeLimitTitle])
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(vm.limitMessage ?? "")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            refreshButton
        }
        .padding(24)
    }

    private var refreshButton: some View {
        Button { Task { await vm.retry() } } label: {
            Text(lang[.likeRefresh])
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color.red, theme.primary, Color.orange],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
        }
        .padding(.top, 8)
    }
}

#Preview {
    LikeTabView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
