import Foundation
import SwiftUI
import Combine

/// GET /api/matches/received/ javobidagi bitta element — bizni like
/// bosgan foydalanuvchi `from_user` maydonida keladi (apps/matches/serializers.py LikeSerializer).
struct ReceivedLike: Decodable {
    let id: Int
    let from_user: DashUser
    let created_at: String?
}

/// Backendda global pagination yoqilgan (DEFAULT_PAGINATION_CLASS —
/// utils.pagination.StandardPagination), shu sababli `/matches/received/`
/// XOM massiv emas, balki `{"count":..,"results":[...]}` obyektini qaytaradi —
/// `fetchRooms` pastda buni `ChatRoomsPage` bilan to'g'ri hisobga oladi, lekin
/// `fetchReceivedLikes` avval to'g'ridan-to'g'ri `[ReceivedLike]` sifatida
/// dekodlashga urinardi va bu HAR DOIM jim (try?) muvaffaqiyatsiz tugardi —
/// "Sizni yoqtirganlar" doim bo'sh ko'rinishining sababi aynan shu edi.
struct ReceivedLikesPage: Decodable {
    let results: [ReceivedLike]?
}

/// Suhbatlar ro'yxati uchun bitta umumiy ViewModel — MainTabView buni yaratib
/// pastga (Chat tab ikonkasidagi badge uchun ham, ChatListView uchun ham) beradi,
/// shunda "umumiy o'qilmagan xabarlar" soni ikkala joyda bitta manbadan keladi.
@MainActor
class ChatListViewModel: ObservableObject {
    @Published var rooms: [ChatRoomModel] = []
    @Published var isLoading = false
    @Published var myId: Int? = nil

    /// Joriy foydalanuvchi premium/vip obunaga ega — "sizga like bosganlar"
    /// ro'yxatini ko'rish shu bilan cheklangan (backendda ham bir xil shart:
    /// Plan.can_see_who_liked — apps/matches/views.py ReceivedLikesView).
    @Published var isPremiumViewer: Bool = false
    @Published var receivedLikes: [DashUser] = []
    @Published var isLoadingLikes = false
    private var pollTask: Task<Void, Never>? = nil

    var totalUnread: Int {
        rooms.reduce(0) { $0 + $1.unreadCount }
    }

    /// Admin (yordam) xonasi har doim tepada — backend ham shunday tartiblaydi,
    /// lekin himoya uchun bu yerda ham ta'minlaymiz.
    var sortedRooms: [ChatRoomModel] {
        rooms.sorted { a, b in
            if a.isAdmin != b.isAdmin { return a.isAdmin }
            return false // backend tartibini saqlaymiz (qolganlari uchun)
        }
    }

    func loadInitial() async {
        isLoading = true
        if myId == nil { await fetchMyId() }
        await fetchRooms()
        isLoading = false
    }

    func refresh() async {
        await fetchRooms()
    }

    /// Suhbat ichida xabar yuborilgan/qabul qilingan ZAHOTI (serverga qayta
    /// so'rov yubormasdan) shu xonani ro'yxat boshiga ko'chiradi — Telegram
    /// uslubida tezkor tartib yangilanishi uchun ("men yozganimda ham tepaga
    /// chiqib qolishi kerak" talabi shu orqali bajariladi). `unread_count`
    /// QASDDAN o'zgartirilmaydi — suhbat hozir OCHIQ turgani uchun bu xabar
    /// allaqachon o'qilgan hisoblanadi; ro'yxatga qaytilganda (`refresh()`)
    /// yoki keyingi pollda haqiqiy server qiymatlari bilan tasdiqlanadi.
    func bumpRoom(_ roomId: Int, lastMessage: ChatMessage) {
        guard let idx = rooms.firstIndex(where: { $0.id == roomId }) else { return }
        let old = rooms[idx]
        let updated = ChatRoomModel(
            id: old.id, room_type: old.room_type, other_user: old.other_user,
            last_message: lastMessage, unread_count: old.unread_count,
            is_locked: old.is_locked, is_blocked: old.is_blocked, is_muted: old.is_muted,
            expires_at: old.expires_at, created_at: old.created_at
        )
        rooms.remove(at: idx)
        rooms.insert(updated, at: 0)
    }

    /// Chat tabi ochiq turganda har 12 soniyada o'qilmagan xabarlarni yangilab turadi.
    func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                if Task.isCancelled { break }
                await self.fetchRooms()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - API

    private func fetchMyId() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/auth/me/") else { return }
        if let me = try? JSONDecoder().decode(DashMe.self, from: data) {
            myId = me.id
            isPremiumViewer = me.subscription_type == "premium" || me.subscription_type == "vip"
        }
    }

    /// Sizga like bosgan foydalanuvchilar ro'yxati — faqat premium/vip uchun
    /// (free hisobda backend bo'sh ro'yxat qaytaradi, shu sababli paywall
    /// chiqarish kerakligini `isPremiumViewer` orqali OLDINDAN bilamiz).
    func fetchReceivedLikes() async {
        isLoadingLikes = true
        defer { isLoadingLikes = false }
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/matches/received/") else { return }

        var decoded: [ReceivedLike]? = nil
        if let page = try? JSONDecoder().decode(ReceivedLikesPage.self, from: data), let results = page.results {
            decoded = results
        } else if let list = try? JSONDecoder().decode([ReceivedLike].self, from: data) {
            decoded = list
        }
        if let decoded {
            receivedLikes = decoded.map(\.from_user)
        }
    }

    private func fetchRooms() async {
        var req = URLRequest(url: URL(string: "\(APIConfig.base)/chat/rooms/")!)
        req.httpMethod = "GET"
        req.timeoutInterval = 10
        let (data, status) = await APIClient.shared.send(req)
        guard status == 200, let data else { return }

        var decoded: [ChatRoomModel]? = nil
        if let page = try? JSONDecoder().decode(ChatRoomsPage.self, from: data), let results = page.results {
            decoded = results
        } else if let list = try? JSONDecoder().decode([ChatRoomModel].self, from: data) {
            decoded = list
        }
        guard let decoded else { return }

        // Har bir foydalanuvchida HAR DOIM kamida bitta xona (admin/yordam)
        // bo'lishi shart — backend buni har so'rovda kafolatlaydi
        // (ensure_admin_room, ChatRoomListView.get_queryset). Shu sababli
        // ro'yxat haqiqatda HECH QACHON bo'sh bo'lishi mumkin emas. Agar
        // shunga qaramay bo'sh natija kelsa (server/tarmoq tomonidagi
        // vaqtinchalik uzilish, poll davrida bo'sh javob va hokazo) — buni
        // e'tiborsiz qoldirib, oldingi to'g'ri ro'yxatni saqlab qolamiz,
        // aks holda foydalanuvchi "barcha chatlar yo'qolib qoldi" deb
        // ko'radigan, har necha soniyada qaytalanadigan miltillashga olib
        // keladi (xona ro'yxati 12 soniyada bir marta pollanadi).
        if decoded.isEmpty && !rooms.isEmpty {
            return
        }
        rooms = decoded
    }
}
