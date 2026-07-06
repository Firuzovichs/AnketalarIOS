import SwiftUI

/// Suhbat oynasining yuqori qismi — oddiy holatda foydalanuvchi ma'lumoti,
/// qidiruv rejimida esa Telegram uslubidagi qidiruv maydoni + natijalar
/// bo'yicha yuqori/past sakrash paneli bilan almashtiriladi.
///
/// Barcha qidiruv/bloklash holati (`showSearch`, `searchQuery` va h.k.)
/// `ChatConversationView`da saqlanadi — bu komponent faqat shu holatni
/// ko'rsatish va kerakli yopiq funksiyalarni (closure) chaqirish bilan
/// shug'ullanadi, hech narsani o'zida saqlamaydi.
struct ChatHeaderBar: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @ObservedObject var vm: ChatRoomViewModel
    var onDismiss: () -> Void

    @Binding var showSearch: Bool
    @Binding var searchQuery: String
    var searchFieldFocused: FocusState<Bool>.Binding
    var isSearchingMessages: Bool
    var searchResults: [ChatMessage]
    var searchResultIndex: Int
    @Binding var showBlockReasonPicker: Bool
    @Binding var showClearChatConfirm: Bool
    /// Qidiruv matni o'zgarganda chaqiriladi (parentdagi `scheduleSearch`).
    var onSearchQueryChanged: (String) -> Void
    /// Qidiruvni butunlay yopish (parentdagi `closeSearch`).
    var onCloseSearch: () -> Void
    /// Natijalar orasida sakrash (parentdagi `goToSearchResult`).
    var onGoToResult: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider().opacity(0.5)
            searchNavBar
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerRow: some View {
        if showSearch {
            searchHeaderRow
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        } else {
            HStack(spacing: 12) {
                Button { onDismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }

                if vm.room.isAdmin {
                    Circle()
                        .fill(theme.buttonGradient)
                        .frame(width: 38, height: 38)
                        .overlay(Image(systemName: "headphones.circle.fill").font(.system(size: 18)).foregroundColor(.white))
                } else if let url = vm.room.photoURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                        else { Circle().fill(theme.primaryLight) }
                    }
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                } else {
                    Circle().fill(theme.primaryLight).frame(width: 38, height: 38)
                        .overlay(Image(systemName: "person.fill").foregroundColor(theme.primary))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.room.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text(statusLabel)
                        .font(.system(size: 12))
                        .foregroundColor(vm.otherTyping ? theme.primary : theme.textSecondary)
                }
                Spacer()
                Button {
                    showSearch = true
                    searchFieldFocused.wrappedValue = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 30, height: 30)
                }
                headerMenu
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }

    /// "Yordam" xonasida ko'rsatilmaydi — qolgan barcha suhbatlarda
    /// bildirishnomani o'chirish/yoqish, bloklash/blokdan chiqarish va
    /// "Chatni tozalash" amallari shu yerdan boshlanadi.
    @ViewBuilder
    private var headerMenu: some View {
        if !vm.room.isAdmin {
            Menu {
                // MUHIM: mute/unmute tugmasi Bloklashdan OLDIN turishi kerak
                // ("Bloklash oldida" talabi). Bu FAQAT push/in-app
                // bildirishnomaga ta'sir qiladi — xabarning o'zi har doim
                // odatdagidek yetib boradi.
                Button { Task { _ = await vm.toggleMute() } } label: {
                    Label(vm.isMuted ? lang[.chatMenuUnmute] : lang[.chatMenuMute],
                          systemImage: vm.isMuted ? "bell.fill" : "bell.slash.fill")
                }

                if vm.isBlocked {
                    Button { Task { _ = await vm.unblockUser() } } label: {
                        Label(lang[.chatUnblockButton], systemImage: "lock.open.fill")
                    }
                } else {
                    Button(role: .destructive) { showBlockReasonPicker = true } label: {
                        Label(lang[.chatMenuBlock], systemImage: "hand.raised.fill")
                    }
                }

                Button { showClearChatConfirm = true } label: {
                    Label(lang[.chatMenuClearChat], systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 30, height: 30)
            }
        }
    }

    private var statusLabel: String {
        if vm.room.isAdmin { return lang[.chatSupportSub] }
        if vm.otherTyping { return lang[.chatTyping] }
        return vm.otherOnline ? lang[.upOnline] : ""
    }

    // MARK: - Suhbat ichida qidiruv — sarlavha qatori va navigatsiya paneli

    /// Telegram uslubida: sarlavha o'rnida chiqadigan qidiruv maydoni +
    /// "Bekor qilish" tugmasi.
    private var searchHeaderRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(theme.textSecondary)
                TextField(lang[.chatSearchPlaceholder], text: $searchQuery)
                    .focused(searchFieldFocused)
                    .font(.system(size: 16))
                    .foregroundColor(theme.textPrimary)
                    .submitLabel(.search)
                    .onChange(of: searchQuery) { _, newValue in
                        onSearchQueryChanged(newValue)
                    }
                if !searchQuery.isEmpty {
                    Button { searchQuery = ""; onSearchQueryChanged("") } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textSecondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.primaryLight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button { onCloseSearch() } label: {
                Text(lang[.cancel])
                    .font(.system(size: 15))
                    .foregroundColor(theme.primary)
            }
        }
        .onAppear { searchFieldFocused.wrappedValue = true }
    }

    /// Qidiruv natijalari bo'yicha yuqori/past sakrash paneli — alohida
    /// ro'yxat/ekran YO'Q, faqat hisoblagich va strelkalar.
    @ViewBuilder
    private var searchNavBar: some View {
        if showSearch {
            HStack(spacing: 14) {
                if isSearchingMessages {
                    ProgressView()
                        .scaleEffect(0.75)
                    Spacer()
                } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Spacer()
                } else if searchResults.isEmpty {
                    Text(lang[.chatSearchNoResults])
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                } else {
                    Text("\(searchResultIndex + 1)/\(searchResults.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Button { onGoToResult(searchResultIndex - 1) } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(searchResultIndex > 0 ? theme.primary : theme.textSecondary.opacity(0.35))
                    }
                    .disabled(searchResultIndex <= 0)

                    Button { onGoToResult(searchResultIndex + 1) } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(searchResultIndex < searchResults.count - 1 ? theme.primary : theme.textSecondary.opacity(0.35))
                    }
                    .disabled(searchResultIndex >= searchResults.count - 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.background)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
