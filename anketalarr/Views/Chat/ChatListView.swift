import SwiftUI

/// Suhbatlar ro'yxati (Chat tab). Admin/"Yordam" xonasi har doim tepada va
/// hech qachon qulflanmaydi. Muddati tugagan suhbatlar xiralashtirilgan
/// holatda ko'rsatiladi va ichiga kirib bo'lmaydi.
struct ChatListView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @EnvironmentObject var paywallGate: PaywallGate
    @ObservedObject var vm: ChatListViewModel

    @State private var openRoom: ChatRoomModel? = nil
    @State private var lockedAlertRoom: ChatRoomModel? = nil
    @State private var showLikesSheet = false
    @State private var selectedLiker: DashUser? = nil

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }

            if showLikesSheet { likesSheet }
        }
        .task {
            // Pollingni MainTabView boshqaradi (tab almashtirilganda ham
            // ishlashda davom etadi — shu orqali badge har doim yangi turadi),
            // bu yerda faqat birinchi marta bo'sh bo'lsa yuklab olamiz.
            if vm.rooms.isEmpty { await vm.loadInitial() }
        }
        .fullScreenCover(item: $openRoom) { room in
            ChatConversationView(room: room, myId: vm.myId, onDismiss: {
                openRoom = nil
                Task { await vm.refresh() }
            }, onMessageActivity: { msg in
                vm.bumpRoom(room.id, lastMessage: msg)
            })
            .environmentObject(theme)
            .environmentObject(lang)
            .environmentObject(paywallGate)
        }
        .fullScreenCover(item: $selectedLiker) { user in
            UserProfileView(user: user, onDismiss: { selectedLiker = nil })
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .alert(lang[.chatLockedAlertTitle], isPresented: Binding(
            get: { lockedAlertRoom != nil },
            set: { if !$0 { lockedAlertRoom = nil } }
        )) {
            Button(lang[.done], role: .cancel) { lockedAlertRoom = nil }
            // Suhbat vaqti tugagani uchun qulflangan xonaga bosilganda
            // chiqadigan ogohlantirishda endi to'g'ridan-to'g'ri Obuna
            // sahifasiga o'tish tugmasi ham bor.
            Button(lang[.vipReqBtn]) {
                lockedAlertRoom = nil
                paywallGate.present()
            }
        } message: {
            Text(lang[.chatLockedAlertBody])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text(lang[.chatTitle])
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            likesButton
            if vm.totalUnread > 0 {
                Text("\(vm.totalUnread)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(theme.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    /// O'ng yuqori burchakdagi "sizni yoqtirganlar" tugmasi — premium/vip
    /// bo'lmagan foydalanuvchiga (xuddi Dashboard'dagi kabi) paywall
    /// ko'rsatiladi, premium/vip bo'lsa haqiqiy ro'yxat ochiladi.
    private var likesButton: some View {
        Button {
            if vm.isPremiumViewer {
                withAnimation(.spring()) { showLikesSheet = true }
                Task { await vm.fetchReceivedLikes() }
            } else {
                paywallGate.present()
            }
        } label: {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(theme.primary)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.rooms.isEmpty {
            VStack { Spacer(); ProgressView().scaleEffect(1.3); Spacer() }
        } else if vm.rooms.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.sortedRooms) { room in
                        roomRow(room)
                            .onTapGesture { handleTap(room) }
                        Divider().padding(.leading, 84).opacity(0.5)
                    }
                }
            }
            .refreshable { await vm.refresh() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "message.badge.circle")
                .font(.system(size: 56))
                .foregroundColor(theme.primary.opacity(0.35))
            Text(lang[.chatEmptyTitle])
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(lang[.chatEmptySub])
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Likes sheet ("sizni yoqtirganlar")

    private var likesSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.spring()) { showLikesSheet = false } }

            VStack(spacing: 0) {
                Capsule()
                    .fill(theme.textSecondary.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                Text(lang[.chatLikesReceivedTitle])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.bottom, 12)

                if vm.isLoadingLikes {
                    ProgressView().padding(.bottom, 24)
                } else if vm.receivedLikes.isEmpty {
                    Text(lang[.chatLikesEmpty])
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .padding(.bottom, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(vm.receivedLikes) { user in
                                likerRow(user)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        showLikesSheet = false
                                        selectedLiker = user
                                    }
                                Divider().padding(.leading, 78).opacity(0.5)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                }
            }
            .frame(maxWidth: .infinity)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.bottom, 100)
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.35), value: showLikesSheet)
    }

    private func likerRow(_ user: DashUser) -> some View {
        HStack(spacing: 14) {
            if let url = user.photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Circle().fill(theme.primaryLight)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(theme.primaryLight)
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "person.fill").foregroundColor(theme.primary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                if let age = user.age {
                    Text("\(age)")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func handleTap(_ room: ChatRoomModel) {
        if room.locked {
            lockedAlertRoom = room
        } else {
            openRoom = room
        }
    }

    // MARK: - Row

    private func roomRow(_ room: ChatRoomModel) -> some View {
        HStack(spacing: 14) {
            avatar(room)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(room.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(room.locked ? theme.textSecondary : theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(room.locked ? "" : room.timeLabel)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                HStack {
                    Text(room.locked ? lang[.chatLockedRowLabel] : (room.blocked ? lang[.chatBlockedRowLabel] : room.preview(myId: vm.myId)))
                        .font(.system(size: 13.5))
                        .foregroundColor((room.locked || room.blocked) ? theme.textSecondary.opacity(0.7) : theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    // Xona vaqti tugab qulflangan bo'lsa ham, agar undan yangi
                    // (o'qilmagan) xabar kelgan bo'lsa, soni ko'rinib turishi
                    // kerak — qulf belgisi shu raqam bilan birga chiqadi,
                    // uni "yutib" yubormaydi. Faqat foydalanuvchi bloklagan
                    // xonalarda (room.blocked) soni ko'rsatilmaydi.
                    HStack(spacing: 5) {
                        if room.locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary.opacity(0.6))
                        } else if room.blocked {
                            Image(systemName: "hand.raised.slash.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary.opacity(0.6))
                        }
                        if !room.blocked && room.unreadCount > 0 {
                            Text("\(room.unreadCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .opacity(room.locked ? 0.5 : 1)
        .background(room.isAdmin ? theme.primaryLight.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
    }

    private func avatar(_ room: ChatRoomModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if room.isAdmin {
                Circle()
                    .fill(theme.buttonGradient)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "headphones.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    )
            } else if let url = room.photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Circle().fill(theme.primaryLight)
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(theme.primaryLight)
                    .frame(width: 54, height: 54)
                    .overlay(Image(systemName: "person.fill").foregroundColor(theme.primary))
            }

            if !room.isAdmin && room.isOnline && !room.locked {
                Circle()
                    .fill(Color.green)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
        }
        .grayscale(room.locked ? 1 : 0)
    }
}
