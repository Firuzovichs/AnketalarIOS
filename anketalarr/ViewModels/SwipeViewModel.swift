import Foundation
import SwiftUI
import Combine
/// `/api/matches/like/` javobidan kerakli qismi — qolgan maydonlar (from_user/to_user/...)
/// hozircha kerak emas, shuning uchun dekodlanmaydi.
private struct LikeActionResponse: Decodable {
    let matched: Bool?
    let match_id: Int?
    let chat_room_id: Int?
}

private struct DetailResponse: Decodable {
    let detail: String?
    let code: String?
    let limit: Int?
}

/// "Like" tab (Tinder-uslubidagi swipe) uchun ViewModel.
/// Har safar bitta nomzodni ko'rsatadi (`/api/search/single/`), like/skip bosilganda
/// navbatdagi nomzodni oldindan yuklab qo'yadi — kartalar orasida kutish bo'lmasligi uchun.
@MainActor
final class SwipeViewModel: ObservableObject {
    @Published var currentUser: DashUser? = nil
    /// `true` dan boshlanadi — birinchi `.task` ishga tushmasdan turib
    /// bo'sh holat ("hech kim topilmadi") bir lahzaga ko'rinib qolmasligi uchun.
    @Published var isLoading = true
    @Published var noMoreUsers = false
    @Published var limitReached = false
    @Published var limitMessage: String? = nil
    @Published var errorMsg: String? = nil

    /// Mutual like bo'lganda ko'rsatiladigan "Match!" popup
    @Published var matchedUser: DashUser? = nil
    @Published var matchedChatRoomId: Int? = nil

    /// Like/skip tugmalari bosilgan paytda qayta bosishni oldini olish
    @Published var isActing = false

    /// Fonda oldindan tayyorlangan keyingi nomzod — kartalar stekida orqada
    /// "peek" sifatida ko'rsatish uchun ham ishlatiladi (faqat o'qish uchun).
    @Published private(set) var nextUser: DashUser? = nil

    /// Umumiy filtr holati — "Qidirish" (xarita) tabi bilan BIRGALIKDA
    /// ishlatiladi (bitta `SearchFilterSheet`, ikki joyda import). Radius bu
    /// yerda ataylab yuborilmaydi — server tomonda Premium+ bilan cheklangan,
    /// shuning uchun bepul foydalanuvchilarga har bir swipe'da 403 qaytmasin.
    @Published var filters = SearchFilterState()
    // MARK: - Yuklash

    /// Birinchi marta ochilganda chaqiriladi
    func loadInitial() async {
        guard currentUser == nil else { return }
        isLoading = true
        noMoreUsers = false
        limitReached = false
        currentUser = await fetchCandidate()
        isLoading = false
        // Keyingisini fonda oldindan tayyorlab qo'yamiz
        if currentUser != nil {
            Task { nextUser = await fetchCandidate() }
        }
    }

    /// Limit ekranidan "Qayta urinish" yoki pull-to-refresh uchun
    func retry() async {
        limitReached = false
        limitMessage = nil
        noMoreUsers = false
        await loadInitial()
    }

    /// Filtr "Qo'llash"/"Tozalash" bosilganda — joriy va navbatdagi kartani
    /// tashlab, yangi filtr bilan boshidan yuklaydi.
    func applyFilters() {
        currentUser = nil
        nextUser = nil
        Task { await loadInitial() }
    }

    private func fetchCandidate() async -> DashUser? {
        // `filters.queryString` "&key=value..." ko'rinishida (Map tabidagi
        // "?lat=...&lng=..." ga qo'shib ishlatish uchun mo'ljallangan).
        // Bu yerda undan oldin boshqa majburiy param yo'q, shuning uchun
        // bosh "&"ni "?" ga almashtiramiz.
        var url = "\(APIConfig.base)/search/single/"
        let q = filters.queryString
        if !q.isEmpty {
            url += "?" + q.dropFirst()
        }
        guard let data = await APIClient.shared.getData(url) else { return nil }
        return try? JSONDecoder().decode(DashUser.self, from: data)
    }

    /// Joriy kartani olib tashlab, oldindan tayyorlangan keyingisini ko'rsatadi,
    /// so'ng fonda yana bittasini tayyorlaydi.
    private func advance() {
        currentUser = nextUser
        nextUser = nil
        if currentUser == nil {
            noMoreUsers = true
            return
        }
        Task { nextUser = await fetchCandidate() }
    }

    // MARK: - Harakatlar

    func skip(_ user: DashUser) async {
        guard !isActing else { return }
        isActing = true
        defer { isActing = false }

        guard let url = URL(string: "\(APIConfig.base)/matches/skip/") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["to_user_id": user.id])
        _ = await APIClient.shared.send(req)

        advance()
    }

    func like(_ user: DashUser, superLike: Bool = false, message: String? = nil) async {
        guard !isActing else { return }
        isActing = true
        defer { isActing = false }

        guard let url = URL(string: "\(APIConfig.base)/matches/like/") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "to_user_id": user.id,
            "like_type": superLike ? "super_like" : "like"
        ]
        // "Habar bilan like" — matn mutual match bo'lganda backend tomonidan
        // (apps/matches/views.py SendLikeView) yangi chat xonasiga birinchi
        // xabar sifatida ko'chiriladi. Match darrov bo'lmasa, matn Like
        // qatorida saqlanib qoladi va qarama-qarshi tomon keyinroq like
        // bossa, o'sha vaqtda chatga tushadi.
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["message"] = message
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, status) = await APIClient.shared.send(req)

        switch status {
        case 201:
            if let data, let resp = try? JSONDecoder().decode(LikeActionResponse.self, from: data),
               resp.matched == true {
                // Mutual like — "Match!" popup ko'rsatamiz, keyingisiga o'tish popup yopilganda bo'ladi
                matchedUser = user
                matchedChatRoomId = resp.chat_room_id
                return
            }
            advance()
        case 429:
            let resp = data.flatMap { try? JSONDecoder().decode(DetailResponse.self, from: $0) }
            limitMessage = LocalizationManager.errorText(code: resp?.code, detail: resp?.detail, limit: resp?.limit)
            limitReached = true
        default:
            // Kutilmagan xato — shu odamni o'tkazib, davom etamiz
            advance()
        }
    }

    /// "Match!" popup yopilgandan keyin chaqiriladi
    func dismissMatch() {
        matchedUser = nil
        matchedChatRoomId = nil
        advance()
    }
}
