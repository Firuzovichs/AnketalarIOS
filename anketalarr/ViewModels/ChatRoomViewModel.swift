import Foundation
import Combine
/// Bitta suhbat oynasi uchun ViewModel — xabarlarni yuklash/yuborish va
/// real-vaqt WebSocket ulanishini boshqaradi (yangi xabar, "yozayapti...",
/// o'qildi belgisi).
///
/// Funksionallik bir nechta faylga bo'lingan (`extension ChatRoomViewModel` orqali,
/// hammasi shu klassning bir qismi — faqat fayllar bo'yicha ajratilgan):
/// - `ChatRoomViewModel+Fetch.swift` — xabarlarni yuklash
/// - `ChatRoomViewModel+Send.swift` — xabar yuborish (matn/rasm/ovoz/video/joylashuv)
/// - `ChatRoomViewModel+Actions.swift` — blok/mute/tozalash/qidirish/tahrirlash
/// - `ChatRoomViewModel+WebSocket.swift` — real-vaqt ulanish va "yozayapti" holati
/// - `ChatRoomViewModel+Helpers.swift` — umumiy yordamchi (`makeRequest`)
@MainActor
class ChatRoomViewModel: ObservableObject {
    let room: ChatRoomModel
    var myId: Int?

    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    /// Yuqoriga scroll qilinganda eskirog'i yuklanayotganini bildiradi
    /// (kichik spinner — butun ekranni emas).
    @Published var isLoadingOlderMessages = false
    /// `false` bo'lsa, demak suhbatning ENG BOSHIGA yetilgan — yana
    /// "eskirog'ini yukla" so'rovi yuborilmaydi. Birinchi `fetchMessages()`
    /// javobi kelguncha "true" deb (ehtiyot yuzasidan) hisoblanadi.
    @Published var hasMoreOlderMessages = true
    /// `ChatRoomViewModel+Fetch.swift`dagi `loadOlderMessages()` ichida ishlatiladi.
    var isFetchingOlderMessages = false
    @Published var isLocked = false
    /// `isLocked == true` bo'lganda buni ham tekshirib, sabab "obuna muddati
    /// tugagan" emas, balki "bloklangan" ekanini ajratamiz (lockedState
    /// ekranida boshqa ikon/matn/"blokdan chiqarish" tugmasi ko'rsatish uchun).
    @Published var isBlocked = false
    /// Shu xona uchun bildirishnoma o'chirib qo'yilganmi (faqat menga ta'sir
    /// qiladi — xabarning o'zi suhbatdoshga odatdagidek yetib boradi).
    @Published var isMuted: Bool
    @Published var lockMessage: String? = nil
    @Published var replyTo: ChatMessage? = nil
    @Published var isSending = false
    @Published var otherTyping = false
    /// O'chib ketadigan rasm mahalliy ravishda (server bilan qayta so'rov
    /// yubormasdan) "muddati tugadi" deb belgilangan xabar id'lari — to'liq
    /// ekran ko'rgazmasi hisoblagichi 0 ga yetganda shu yerga qo'shiladi, shu
    /// orqali pufakcha darhol "expired" holatiga o'tadi (serverga qayta
    /// so'rov yuborib, javobni kutib turishga ehtiyoj qolmaydi).
    @Published var locallyExpiredPhotoIds: Set<Int> = []
    /// `room.isOnline` faqat xona ro'yxati yuklangan paytdagi "muzlab qolgan"
    /// holatni bildiradi (qayta yangilanmaydi). Bu xususiyat esa WS orqali
    /// kelgan `presence_status` hodisalari bilan suhbat OCHIQ turgan paytda
    /// ham jonli (real-vaqt) yangilanib turadi.
    @Published var otherOnline: Bool
    /// Xona umuman qulflanmagan, lekin masalan ovozli xabar Premium/VIP talab
    /// qilgani uchun rad etilganda shu yerda vaqtinchalik ko'rsatiladi (isLocked
    /// dan farqli — butun suhbatni yopmaydi, faqat banner ko'rsatiladi).
    @Published var voiceError: String? = nil
    /// `ChatRoomViewModel+Send.swift`dagi `showVoiceError(_:)` ichida ishlatiladi.
    var voiceErrorClearTask: Task<Void, Never>? = nil

    /// Xabar yuborilganda (men) yoki qabul qilinganda (suhbatdosh) chaqiriladi —
    /// ChatListView shu orqali tashqi suhbatlar ro'yxatini (ChatListViewModel)
    /// SERVERGA QAYTA SO'ROV YUBORMASDAN, shu zahoti shu xonani ro'yxat
    /// boshiga ko'chirishi uchun xabardor qilinadi (Telegram uslubida: "men
    /// yozsam ham, suhbatdosh yozsa ham" ro'yxat darhol tepaga chiqishi
    /// kerak — avval faqat ro'yxat ekraniga QAYTILGANDA yoki 12 soniyalik
    /// poll orqali yangilanardi, shu sababli "men yozganimda tepaga
    /// chiqmayapti" degan shikoyat shu yerdan kelib chiqqan edi).
    var onMessageActivity: ((ChatMessage) -> Void)? = nil
    /// `ChatRoomViewModel+WebSocket.swift` ichida boshqariladi.
    var webSocketTask: URLSessionWebSocketTask?
    var typingHideTask: Task<Void, Never>? = nil
    var typingSendTask: Task<Void, Never>? = nil
    var lastSentTyping = false
    /// WebSocket uzilganda avtomatik qayta ulanish uchun (oldin bu umuman
    /// yo'q edi — bitta tarmoq uzilishi butun suhbat davomida WS'ni butunlay
    /// "o'lik" qilib qo'yardi, va yangi xabarlar faqat ekranni qayta ochganda
    /// ko'rinardi; bu "chat ko'rinmay qolyapti" shikoyatining yana bir manbai edi).
    var reconnectTask: Task<Void, Never>? = nil
    /// `fetchMessages()` bir vaqtda bir martagina ishlashi uchun (masalan,
    /// ovozli xabar yuborilayotganda WS orqali kelgan "new_message" hodisasi
    /// bilan poyga qilib, ro'yxat vaqtincha bo'sh ko'rinib ketishining oldini
    /// olish uchun).
    var isFetchingMessages = false

    /// Optimistik pending xabarlar uchun mahalliy ID generatori.
    /// Manfiy son bo'lib, server ID'laridan farqlanadi (server har doim musbat ID beradi).
    private var _pendingIdCounter = -1
    func nextPendingId() -> Int {
        let id = _pendingIdCounter
        _pendingIdCounter -= 1
        return id
    }

    init(room: ChatRoomModel, myId: Int?) {
        self.room = room
        self.myId = myId
        self.otherOnline = room.isOnline
        self.isMuted = room.isMuted
    }

    // MARK: - Lifecycle

    func start() async {
        await fetchMessages()
        connectWebSocket()
        // WS to'liq ulangach tarixiy xabarlarni "o'qildi" deb belgilaymiz.
        // sendReadReceiptsAfterConnect WebSocket extension'da — ping orqali
        // ulanishni tasdiqlab keyin read yuboradi.
        Task {
            await sendReadReceiptsAfterConnect(for: messages)
        }
    }

    func stop() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        typingHideTask?.cancel()
        typingSendTask?.cancel()
        reconnectTask?.cancel()
    }
}
