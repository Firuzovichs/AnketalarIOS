import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import AVKit
import UniformTypeIdentifiers
import CoreLocation
import MapKit
import Combine

/// Bitta suhbat oynasi — Telegram uslubidagi xabar pufakchalari, javob
/// (reply) preview, rasm biriktirish, "yozayapti..." indikatori va
/// ko'rildi (✓✓) belgilari bilan.
struct ChatConversationView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    // Bu ekran ChatListView'dan ALOHIDA .fullScreenCover sifatida ochiladi —
    // shu sababli umumiy Obuna darvozasi (`MainTabView`dagi) avtomatik
    // tarqalmaydi va shu yerga ALOHIDA, ikkinchi `.fullScreenCover` kerak
    // (pastga, body'ning oxiriga qarang).
    @EnvironmentObject var paywallGate: PaywallGate
    // MUHIM: @StateObject (@ObservedObject EMAS) — shu orqali ViewModel
    // FAQAT BIR MARTA (bu ekran birinchi marta ko'rsatilganda) yaratiladi va
    // ekran ochiq turgan butun davomida saqlanib qoladi. Agar @ObservedObject
    // bo'lganida va chaqiruvchi tomon (ChatListView) uni har safar (masalan,
    // suhbatlar ro'yxati har 12 soniyada pollanib, @Published o'zgarganda)
    // .fullScreenCover yopilishi ichida QAYTA yaratib bersa, bu yerdagi
    // suhbat butunlay yangi (bo'sh xabarlar ro'yxati bilan) ViewModel'ga
    // "almashtirib" qo'yilardi — aynan shu sabab "admin chatdagi xabarlar
    // necha soniyadan keyin yo'qolib qolyapti" degan xatoning ildizi edi.
    @StateObject var vm: ChatRoomViewModel
    var onDismiss: () -> Void
    /// Xabar yuborilganda/qabul qilinganda chaqiriladi — ChatListView shu
    /// orqali suhbatlar ro'yxatidagi shu xonani DARHOL (Telegram uslubida)
    /// boshiga ko'chiradi. `ChatRoomViewModel.onMessageActivity`ga
    /// to'g'ridan-to'g'ri ulanadi (pastga, init'da).
    var onMessageActivity: ((ChatMessage) -> Void)? = nil

    @State private var draft: String = ""
    // Endi rasm va video bitta umumiy galereya tanlagichi orqali tanlanadi
    // (ikkisi uchun alohida tugma/menyu emas) — tanlangan elementning turi
    // (.images/.videos) tekshirilib, mosiga qarab sendImage/sendVideo chaqiriladi.
    @State private var galleryItem: PhotosPickerItem? = nil
    @State private var isLoadingVideo = false
    @StateObject private var recorder = VoiceRecorder()
    @StateObject private var videoRecorder = VideoRecorder()
    @StateObject private var locationManager = LocationManager()
    @State private var awaitingLocationSend = false
    @State private var locationDeniedAlert = false
    /// `mediaMessages` ichidagi boshlanish indeksi — nil bo'lmasa, to'liq ekran
    /// galereya ko'rinishi (`ChatMediaViewerView`) ochiq turibdi degani.
    @State private var viewerStartIndex: Int? = nil

    // Bloklash/shikoyat
    @State private var showBlockReasonPicker = false
    // "Chatni tozalash" tasdiqlash dialogi.
    @State private var showClearChatConfirm = false
    // Suhbat ichida qidiruv — Telegram uslubida: header o'rnida qidiruv
    // maydoni chiqadi, alohida natijalar RO'YXATI/OYNASI YO'Q — topilgan
    // xabarlar orasida yuqori/past strelkalar bilan to'g'ridan-to'g'ri
    // suhbat ICHIDA sakrab yuriladi, joriy xabar qisqa "yarq etib" ajratib
    // ko'rsatiladi (`highlightedMessageId`).
    @State private var showSearch = false
    @State private var searchQuery: String = ""
    /// Natijalar ESKI -> YANGI tartibda (created_at o'sish tartibi) — shu
    /// orqali yuqori (eski tomon) / past (yangi tomon) strelkalar izchil
    /// ma'noga ega bo'ladi.
    @State private var searchResults: [ChatMessage] = []
    /// `searchResults` ichida hozir ko'rsatilayotgan natijaning indeksi.
    @State private var searchResultIndex: Int = 0
    @State private var isSearchingMessages = false
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @FocusState private var searchFieldFocused: Bool
    /// nil bo'lmasa — shu ID'li xabar pufakchasi hozir qisqa muddat ajratib
    /// ko'rsatilmoqda (qidiruv natijasiga sakralganda).
    @State private var highlightedMessageId: Int? = nil
    @State private var highlightClearTask: Task<Void, Never>? = nil
    /// nil bo'lmasa — pastdagi kiritish maydoni hozir shu xabarni tahrirlash
    /// rejimida turibdi (yangi xabar yozish EMAS). `vm.replyTo` bilan bir
    /// vaqtda faol bo'lmaydi (`startEditing`/`cancelEditing` ikkisini ham
    /// nazorat qiladi).
    @State private var editingMessage: ChatMessage? = nil
    /// `messagesList`dagi `ScrollViewReader`ning proxy'si — qidiruv natijasi
    /// bosilganda shu xabarga sakrash uchun shu yerda saqlanadi.
    @State private var scrollProxy: ScrollViewProxy? = nil
    /// Hozir ekranda ko'rinib turgan xabarlar ID to'plami — suzuvchi sana
    /// tasmasi qaysi kunni ko'rsatishini aniqlash uchun ishlatiladi.
    @State private var visibleMsgIds: Set<Int> = []
    /// `true` bo'lganda `vm.messages.count`ning o'zgarishi ESKIROQ xabarlar
    /// ro'yxat BOSHIGA qo'shilgani sababli (`loadOlderIfNeeded()`) — bu holda
    /// pastga avtomatik scroll qilinmasligi kerak (faqat YANGI xabar kelganda/
    /// yuborilganda pastga scroll qilinadi). `onChange(of: vm.messages.count)`
    /// shu bayroqni o'qib, bittagina marta "iste'mol qiladi" (false qilib qo'yadi).
    @State private var isPrependingOlder = false
    /// `true` bo'lganda suhbat eng pastida (oxirgi xabar ko'rinib turibdi).
    /// `false` bo'lsa — foydalanuvchi yuqoriroq (eski xabarlarni) o'qiyapti,
    /// shu holatda "pastga tushish" tugmasi chiqadi (Telegram uslubida).
    @State private var isAtBottom = true
    /// `messagesList` ro'yxati TUBIDA turadigan ko'rinmas "langar" — pastda
    /// ekanligini aniqlash HAM, "pastga tushish" tugmasi bosilganda sakrash
    /// HAM shu ID orqali amalga oshiriladi (oxirgi xabar ID'siga bog'lanib
    /// qolmaydi, shu sababli yangi xabar qo'shilishidan ta'sirlanmaydi).
    private let bottomAnchorId = "chat-bottom-anchor"

    // O'chib ketadigan rasm: endi alohida tugma/oqim YO'Q — galereyadan
    // ODDIY rasm tanlangandan keyin chiqadigan tasdiqlash ekranida
    // (`ImageSendPreviewView`) o'ng yuqori burchakdagi taymer tugmasi orqali
    // davomiylik tanlanadi va SHU ZAHOTI yuboriladi (pastga, `pendingPhoto`).
    // Hozir ochiq turgan (qabul qilingan/yuborilgan) o'chib ketadigan rasm —
    // nil bo'lmasa to'liq ekran ko'rinishi ochiq.
    @State private var disappearingPhoto: ChatMessage? = nil
    /// Galereyadan tanlangan, hali yuborilmagan rasm — tasdiqlash ekranini
    /// (`ImageSendPreviewView`) ko'rsatish uchun. nil bo'lmasa shu ekran ochiq.
    @State private var pendingPhoto: PendingPhoto? = nil
    /// Telegram uslubidagi video_note overlay URL — nil bo'lmasa overlay ko'rinadi.
    @State private var videoNoteOverlayURL: URL? = nil

    init(room: ChatRoomModel, myId: Int?, onDismiss: @escaping () -> Void,
         onMessageActivity: ((ChatMessage) -> Void)? = nil) {
        let model = ChatRoomViewModel(room: room, myId: myId)
        model.onMessageActivity = onMessageActivity
        _vm = StateObject(wrappedValue: model)
        self.onDismiss = onDismiss
        self.onMessageActivity = onMessageActivity
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            // ── Video note Telegram-style overlay ───────────────────────
            if let vnUrl = videoNoteOverlayURL {
                VideoNoteOverlay(url: vnUrl) { videoNoteOverlayURL = nil }
                    .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .center)))
                    .zIndex(10)
            }

            VStack(spacing: 0) {
                ChatHeaderBar(
                    vm: vm,
                    onDismiss: onDismiss,
                    showSearch: $showSearch,
                    searchQuery: $searchQuery,
                    searchFieldFocused: $searchFieldFocused,
                    isSearchingMessages: isSearchingMessages,
                    searchResults: searchResults,
                    searchResultIndex: searchResultIndex,
                    showBlockReasonPicker: $showBlockReasonPicker,
                    showClearChatConfirm: $showClearChatConfirm,
                    onSearchQueryChanged: { scheduleSearch($0) },
                    onCloseSearch: { closeSearch() },
                    onGoToResult: { goToSearchResult($0) }
                )

                if vm.isLocked {
                    lockedState
                } else {
                    messagesList
                    typingBar
                    replyBar
                    ChatInputBar(
                        vm: vm,
                        recorder: recorder,
                        videoRecorder: videoRecorder,
                        locationManager: locationManager,
                        draft: $draft,
                        editingMessage: $editingMessage,
                        galleryItem: $galleryItem,
                        isLoadingVideo: isLoadingVideo,
                        awaitingLocationSend: $awaitingLocationSend
                    )
                }
            }
        }
        .task { await vm.start() }
        .onDisappear { vm.stop(); recorder.cancel(); videoRecorder.cancel() }
        .alert(lang[.chatVoiceMicDenied], isPresented: $recorder.permissionDenied) {
            Button(lang[.chatVoiceOpenSettings]) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(lang[.cancel], role: .cancel) {}
        }
        .alert(lang[.chatCameraMicDenied], isPresented: $videoRecorder.permissionDenied) {
            Button(lang[.chatVoiceOpenSettings]) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(lang[.cancel], role: .cancel) {}
        }
        .alert(lang[.chatLocationDenied], isPresented: $locationDeniedAlert) {
            Button(lang[.chatVoiceOpenSettings]) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(lang[.cancel], role: .cancel) {}
        }
        // Lokatsiya tugmasi bosilgandan keyin kelgan GPS natijasini bir martagina
        // (awaitingLocationSend orqali) xabar sifatida yuboramiz.
        .onReceive(locationManager.$location.compactMap { $0 }) { loc in
            guard awaitingLocationSend else { return }
            awaitingLocationSend = false
            Task { await vm.sendLocation(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) }
        }
        .onReceive(locationManager.$denied) { denied in
            guard denied, awaitingLocationSend else { return }
            awaitingLocationSend = false
            locationDeniedAlert = true
        }
        .onChange(of: galleryItem) { _, item in
            guard let item else { return }
            // Tanlangan element video ekanligini supportedContentTypes orqali
            // aniqlaymiz — bitta umumiy galereya tanlagichidan rasm HAM, video
            // HAM tanlanishi mumkin (.any(of: [.images, .videos])).
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            if isVideo {
                isLoadingVideo = true
                Task {
                    if let picked = try? await item.loadTransferable(type: ChatPickedVideo.self),
                       let data = try? Data(contentsOf: picked.url) {
                        await vm.sendVideo(data)
                        try? FileManager.default.removeItem(at: picked.url)
                    }
                    galleryItem = nil
                    isLoadingVideo = false
                }
            } else {
                // Endi rasm tanlangan zahoti YUBORILMAYDI — avval tasdiqlash
                // ekrani (`ImageSendPreviewView`) ko'rsatiladi, u yerda
                // foydalanuvchi oddiy yuborish YOKI o'ng yuqoridagi taymer
                // tugmasi orqali "o'chib ketadigan rasm" sifatida yuborishni tanlaydi.
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        let jpegData = img.jpegData(compressionQuality: 0.7) ?? data
                        pendingPhoto = PendingPhoto(data: jpegData, image: img)
                    }
                    galleryItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewerStartIndex != nil },
            set: { if !$0 { viewerStartIndex = nil } }
        )) {
            if let start = viewerStartIndex {
                ChatMediaViewerView(items: mediaMessages, startIndex: start) {
                    viewerStartIndex = nil
                }
            }
        }
        .fullScreenCover(item: $disappearingPhoto) { msg in
            DisappearingPhotoViewerView(
                message: msg,
                mine: msg.isMine(vm.myId),
                onExpire: { vm.expireLocally(msg.id) },
                onScreenshotDetected: { Task { await vm.sendScreenshotAlert() } },
                onClose: { disappearingPhoto = nil }
            )
        }
        // Bloklash sababini tanlash — tanlangan zahoti bitta REST chaqiruv
        // bilan ham bloklaydi, HAM (backend tomonida) admin-panelga Report
        // sifatida yoziladi ("bildirgi bilan bloklash").
        .confirmationDialog(lang[.chatBlockReasonTitle], isPresented: $showBlockReasonPicker, titleVisibility: .visible) {
            Button(lang[.chatBlockReasonSpam]) { Task { await performBlock(reason: "spam") } }
            Button(lang[.chatBlockReasonHarassment]) { Task { await performBlock(reason: "harassment") } }
            Button(lang[.chatBlockReasonFakeProfile]) { Task { await performBlock(reason: "fake_profile") } }
            Button(lang[.chatBlockReasonInappropriate]) { Task { await performBlock(reason: "inappropriate") } }
            Button(lang[.chatBlockReasonOther]) { Task { await performBlock(reason: "other") } }
            Button(lang[.cancel], role: .cancel) {}
        } message: {
            Text(lang[.chatBlockConfirmBody])
        }
        // "Chatni tozalash" — tasdiqlangandan keyin FAQAT shu foydalanuvchi
        // uchun xabarlar ko'rinishdan yashiriladi; bazadan hech narsa o'chmaydi.
        .confirmationDialog(lang[.chatClearChatConfirmTitle], isPresented: $showClearChatConfirm, titleVisibility: .visible) {
            Button(lang[.chatMenuClearChat], role: .destructive) { Task { await performClearChat() } }
            Button(lang[.cancel], role: .cancel) {}
        } message: {
            Text(lang[.chatClearChatConfirmBody])
        }
        // Galereyadan tanlangan rasmni tasdiqlash ekrani — oddiy yuborish
        // YOKI o'ng yuqoridagi taymer tugmasi orqali "o'chib ketadigan rasm"
        // sifatida (davomiylik tanlangan zahoti) yuborish.
        .fullScreenCover(item: $pendingPhoto) { pending in
            ImageSendPreviewView(
                image: pending.image,
                onCancel: { pendingPhoto = nil },
                onSendNormal: {
                    let data = pending.data
                    pendingPhoto = nil
                    Task { await vm.sendImage(data) }
                },
                onSendDisappearing: { seconds in
                    let data = pending.data
                    pendingPhoto = nil
                    Task { await vm.sendDisappearingPhoto(data, seconds: seconds) }
                }
            )
        }
        // Bu ekran o'zi ChatListView'ning .fullScreenCover'i ICHIDA turgani
        // uchun MainTabView darajasidagi Obuna cover'i bu yerga "ko'rinmaydi" —
        // shu sababli xuddi shu umumiy `paywallGate`ni kuzatuvchi IKKINCHI
        // .fullScreenCover shart (joriy modal qatlami ustiga ochilishi uchun).
        .fullScreenCover(isPresented: $paywallGate.isPresented) {
            SubscriptionView()
        }
    }

    private func performBlock(reason: String) async {
        _ = await vm.blockUser(reason: reason)
    }

    private func performUnblock() async {
        _ = await vm.unblockUser()
    }

    /// "Chatni tozalash" — FAQAT shu foydalanuvchi uchun xabarlarni
    /// ko'rinishdan yashiradi. MUHIM: bazadan hech narsa o'chmaydi,
    /// suhbatdosh tomonida hamma xabar to'liq saqlanib qoladi.
    private func performClearChat() async {
        _ = await vm.clearChat()
    }

    /// Qidiruv natijasidagi xabarga sakraydi (`messagesList`dagi
    /// `ScrollViewReader` proxy'si orqali).
    private func jumpToMessage(_ msg: ChatMessage) {
        withAnimation { scrollProxy?.scrollTo(msg.id, anchor: .center) }
    }

    // MARK: - Suhbat ichida qidiruv (Telegram uslubida)

    /// Qidiruvni butunlay yopadi va barcha holatni tozalaydi.
    private func closeSearch() {
        searchDebounceTask?.cancel()
        highlightClearTask?.cancel()
        showSearch = false
        searchQuery = ""
        searchResults = []
        searchResultIndex = 0
        isSearchingMessages = false
        highlightedMessageId = nil
        searchFieldFocused = false
    }

    /// Yozilgan so'rovni debounce qilib (350ms) `vm.searchMessages`ni
    /// chaqiradi, natijalarni ESKI->YANGI tartibda saralaydi va ENG YANGI
    /// moslikka avtomatik sakraydi (Telegram'dagi kabi).
    private func scheduleSearch(_ query: String) {
        searchDebounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchResultIndex = 0
            isSearchingMessages = false
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            isSearchingMessages = true
            let found = await vm.searchMessages(query: trimmed)
            if Task.isCancelled { return }
            // Backend tartibi kafolatlanmagan — qat'iy eski->yangi tartibga
            // o'zimiz saralaymiz, shu orqali strelkalar izchil ishlaydi.
            let sorted = found.sorted {
                (parseChatDate($0.created_at) ?? .distantPast) < (parseChatDate($1.created_at) ?? .distantPast)
            }
            searchResults = sorted
            isSearchingMessages = false
            if let last = sorted.last {
                searchResultIndex = sorted.count - 1
                jumpAndHighlight(last)
            } else {
                searchResultIndex = 0
            }
        }
    }

    private func goToSearchResult(_ index: Int) {
        guard searchResults.indices.contains(index) else { return }
        searchResultIndex = index
        jumpAndHighlight(searchResults[index])
    }

    /// Xabarga sakraydi va qisqa muddat (1.2s) "yarq etib" ajratib ko'rsatadi.
    private func jumpAndHighlight(_ msg: ChatMessage) {
        jumpToMessage(msg)
        highlightClearTask?.cancel()
        highlightedMessageId = msg.id
        highlightClearTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if Task.isCancelled { return }
            highlightedMessageId = nil
        }
    }

    /// O'z matnli xabarini tahrirlash rejimini boshlaydi — kiritish maydonini
    /// shu xabar matni bilan to'ldiradi va pastdagi panelni "Tahrirlanmoqda"
    /// ko'rinishiga o'tkazadi. Reply bilan bir vaqtda bo'lmasligi uchun
    /// `vm.replyTo` tozalanadi.
    private func startEditing(_ msg: ChatMessage) {
        vm.replyTo = nil
        editingMessage = msg
        draft = msg.content ?? ""
    }

    private func cancelEditing() {
        editingMessage = nil
        draft = ""
    }

    /// Boshqa ishtirokchi yuborgan o'chib ketadigan rasm ochilganda — agar
    /// hali muddati tugamagan bo'lsa, serverga "ko'rildi" deb belgilaymiz
    /// (shu lahzadan boshlab orqaga qaytarib bo'lmaydigan countdown boshlanadi)
    /// va to'liq ekranda ochamiz. MUHIM: `disappear_expired` xabar darajasida
    /// (foydalanuvchiga bog'liq emas) hisoblanadi — qabul qiluvchi ko'rib,
    /// countdown tugagandan keyin rasm IKKI TOMON uchun ham (jo'natuvchi
    /// uchun ham) yopiladi. Shu sababli sender o'z rasmini faqat qabul
    /// qiluvchi HALI ko'rmagan paytda istalgancha qayta ochishi mumkin.
    private func openDisappearingPhoto(_ msg: ChatMessage) {
        guard msg.disappear_expired != true, !vm.locallyExpiredPhotoIds.contains(msg.id) else { return }
        if !msg.isMine(vm.myId) {
            Task { await vm.markPhotoViewed(msg.id) }
        }
        disappearingPhoto = msg
    }

    // MARK: - Media gallery (fullscreen viewer)

    /// Galereyada ko'rsatiladigan xabarlar — rasm va video, o'chirilmagan va
    /// media URL'i mavjud bo'lganlari (shu tartibda, suhbatdagi tartibga mos).
    private var mediaMessages: [ChatMessage] {
        vm.messages.filter { msg in
            (msg.message_type == "image" || msg.message_type == "video" || msg.message_type == "video_note")
                && msg.is_deleted != true && msg.mediaURL != nil
        }
    }

    private func openMediaViewer(for msg: ChatMessage) {
        if let idx = mediaMessages.firstIndex(where: { $0.id == msg.id }) {
            viewerStartIndex = idx
        }
    }

    // MARK: - Locked state

    private var lockedState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: vm.isBlocked ? "hand.raised.slash.fill" : "lock.circle.fill")
                .font(.system(size: 54))
                .foregroundColor(theme.textSecondary.opacity(0.4))
            Text(vm.isBlocked ? lang[.chatBlockedTitle] : lang[.chatLockedAlertTitle])
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(vm.lockMessage ?? lang[.chatLockedAlertBody])
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if vm.isBlocked {
                Button { Task { await performUnblock() } } label: {
                    Text(lang[.chatUnblockButton])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(theme.primary)
                        .clipShape(Capsule())
                }
                .padding(.top, 6)
            } else {
                // Bloklanmagan bo'lsa, qulflanish sababi obuna muddati tugashi
                // (chat_duration_days) — shu yerdan to'g'ridan-to'g'ri Obuna
                // sahifasiga yo'naltiramiz.
                Button { paywallGate.present() } label: {
                    Text(lang[.vipReqBtn])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [Color.red, theme.primary, Color.orange],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.top, 6)
            }
            Spacer()
        }
    }

    // MARK: - Suzuvchi sana tasmasi

    /// Ekranda ko'rinib turgan xabarlarning eng eskisiga mos sana yorlig'i.
    /// "Bugun" / "Kecha" / "d MMMM" formatida — `chatDateHeader()` orqali.
    private var topVisibleDateLabel: String {
        guard !visibleMsgIds.isEmpty else { return "" }
        let visible = vm.messages.filter { visibleMsgIds.contains($0.id) }
        guard let oldest = visible.min(by: {
            (parseChatDate($0.created_at) ?? .distantFuture) <
            (parseChatDate($1.created_at) ?? .distantFuture)
        }) else { return "" }
        return chatDateHeader(oldest.created_at)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if vm.isLoading && vm.messages.isEmpty {
                            ProgressView().padding(.top, 40)
                        }
                        // Yuqoriga scroll qilinganda eskirog'i yuklanayotganini
                        // bildiruvchi kichik spinner (butun ekranni emas).
                        if vm.isLoadingOlderMessages {
                            ProgressView().padding(.vertical, 8)
                        }
                        ForEach(vm.messages) { msg in
                            MessageRowView(
                                msg: msg,
                                mine: msg.isMine(vm.myId),
                                onReply: { if editingMessage == nil { vm.replyTo = msg } },
                                onDelete: { Task { await vm.deleteMessage(msg.id) } },
                                onEdit: { startEditing(msg) },
                                onTapMedia: { openMediaViewer(for: msg) },
                                onTapVideoNote: { url in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                        videoNoteOverlayURL = url
                                    }
                                },
                                isExpiredLocally: vm.locallyExpiredPhotoIds.contains(msg.id),
                                onTapDisappearing: { openDisappearingPhoto(msg) },
                                isHighlighted: msg.id == highlightedMessageId
                            )
                            .id(msg.id)
                            .onAppear {
                                // Klaviatura ochilishi ro'yxat balandligini o'zgartiradi.
                                // Shu paytda har bir qator uchun @State yangilash SwiftUI'ni
                                // qayta-qayta render qilib, inputni qotirib qo'ymasligi kerak.
                                // Suzuvchi sana tasmasi uchun ko'rinish to'plamini yangilaydi.
                                visibleMsgIds.insert(msg.id)
                                // Ro'yxatdagi ENG BIRINCHI (eng eski) xabar ko'rinib
                                // qolganda — navbatdagi eskirog' sahifasini so'raymiz
                                // (Telegram uslubidagi cheksiz yuqoriga scroll).
                                if msg.id == vm.messages.first?.id {
                                    Task { await loadOlderIfNeeded(proxy: proxy) }
                                }
                            }
                            .onDisappear {
                                visibleMsgIds.remove(msg.id)
                            }
                        }
                        // Ro'yxat tubidagi ko'rinmas langar — "pastga tushish"
                        // tugmasini ko'rsatish/yashirish shu orqali aniqlanadi.
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorId)
                            .onAppear { isAtBottom = true }
                            .onDisappear { isAtBottom = false }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    // Eskirog'i yuqoriga qo'shilgani sababli o'zgargan bo'lsa,
                    // pastga scroll qilmaymiz — pozitsiyani `loadOlderIfNeeded`
                    // o'zi (yuqoridagi xabarga qarab) saqlab turadi.
                    if isPrependingOlder {
                        isPrependingOlder = false
                        return
                    }
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: vm.isLoading) { _, loading in
                    if !loading, let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onAppear { scrollProxy = proxy }
                .scrollDismissesKeyboard(.interactively)

                if !isAtBottom && !vm.messages.isEmpty {
                    scrollToBottomButton(proxy: proxy)
                }
            }
            .overlay(alignment: .top) {
                // Suzuvchi sana tasmasi — foydalanuvchi qaysi kungi xabarlarni
                // o'qiyotganini telegram uslubida tepada ko'rsatadi.
                let label = topVisibleDateLabel
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: label)
                }
            }
        }
    }

    /// Suhbatni o'qishda yuqoriga chiqib ketilganda chiqadigan, eng pastga
    /// (oxirgi xabarga) bir bosishda qaytaradigan suzuvchi tugma.
    private func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation { proxy.scrollTo(bottomAnchorId, anchor: .bottom) }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(theme.primary))
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
        }
        .padding(.trailing, 14)
        .padding(.bottom, 10)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isAtBottom)
    }

    /// Suhbat yuqorisiga yetilganda eskirog' sahifasini yuklaydi va, agar
    /// yangi xabar qo'shilgan bo'lsa, oldingi ENG ESKI xabar hozir turgan
    /// joyda qolishi uchun scroll pozitsiyasini saqlab qoladi (aks holda
    /// yuqoriga yangi pufakchalar qo'shilishi bilan ko'rinish "sirpanib"
    /// pastga tushib ketardi).
    private func loadOlderIfNeeded(proxy: ScrollViewProxy) async {
        guard !vm.isLoadingOlderMessages, vm.hasMoreOlderMessages,
              let anchorId = vm.messages.first?.id else { return }
        let countBefore = vm.messages.count
        isPrependingOlder = true
        await vm.loadOlderMessages()
        guard vm.messages.count != countBefore else {
            // Hech narsa qo'shilmadi (masalan, aslida ko'proq xabar yo'q
            // ekan) — `onChange(of: vm.messages.count)` ishga tushmaydi,
            // shu sababli bayroqni o'zimiz qaytaramiz.
            isPrependingOlder = false
            return
        }
        proxy.scrollTo(anchorId, anchor: .top)
    }

    // MARK: - Typing bar

    @ViewBuilder
    private var typingBar: some View {
        if vm.otherTyping {
            HStack {
                TypingDotsView(color: theme.textSecondary, bg: theme.cardBackground)
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.bottom, 4)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    // MARK: - Reply bar (yuborishdan oldin)


    @ViewBuilder
    private var replyBar: some View {
        if let editing = editingMessage {
            // Tahrirlash rejimi — `vm.replyTo` bilan bir vaqtda faol bo'lmaydi
            // (`startEditing` uni tozalaydi).
            HStack {
                Rectangle().fill(theme.primary).frame(width: 2.5).frame(maxHeight: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(lang[.chatEditingLabel]).font(.system(size: 11, weight: .semibold)).foregroundColor(theme.primary)
                    Text(editing.content ?? "").font(.system(size: 12)).foregroundColor(theme.textSecondary).lineLimit(1)
                }
                Spacer()
                Button { cancelEditing() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(theme.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(.systemGray6).opacity(0.5))
        } else if let reply = vm.replyTo {
            HStack {
                // MUHIM: Rectangle() o'zicha balandlik bo'yicha cheksiz kengaymoqchi
                // bo'ladi (shape'ning "ideal" o'lchami yo'q) — shu sababli bu chiziq
                // butun reply panelini ekranni to'ldirib yuboradigan darajada
                // kattalashtirib qo'yardi. `.frame(maxHeight:)` bilan qattiq chegara
                // qo'yib, faqat matn balandligiga mos kichik chiziqcha qilib qo'yamiz.
                Rectangle().fill(theme.primary).frame(width: 2.5).frame(maxHeight: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(lang[.chatReply]).font(.system(size: 11, weight: .semibold)).foregroundColor(theme.primary)
                    Text(reply.listPreview(myId: vm.myId)).font(.system(size: 12)).foregroundColor(theme.textSecondary).lineLimit(1)
                }
                Spacer()
                Button { vm.replyTo = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(theme.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(.systemGray6).opacity(0.5))
        }
    }

}

// ── Typing dots bubble (Telegram/WhatsApp uslubida) ──────────────────────────
private struct TypingDotsView: View {
    let color: Color
    let bg:    Color

    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color.opacity(0.75))
                    .frame(width: 7, height: 7)
                    .offset(y: phase ? -5 : 0)
                    .animation(
                        .easeInOut(duration: 0.42)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.14),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        .onAppear { phase = true }
        .onDisappear { phase = false }
    }
}

// ── Video note Telegram-style overlay ─────────────────────────────────────────
/// Bosiganda to'liq ekranga kirmay, suhbat ustida kichik doira video o'ynaydi.
private struct VideoNoteOverlay: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) { onDismiss() }
                }

            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(Circle())
                    .frame(width: 280, height: 280)
                    .allowsHitTesting(false)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
            }
        }
        .onAppear {
            let p = AVPlayer(url: url)
            player = p
            p.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
