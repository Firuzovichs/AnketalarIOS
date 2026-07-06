import Foundation

// MARK: - Actions
extension ChatRoomViewModel {

    /// Suhbatdoshni bloklaydi va shu bilan birga adminga shikoyat (Report)
    /// yuboriladi (backend: BlockUserView — ikkisi BIR so'rovda birga
    /// bajariladi). Muvaffaqiyatli bo'lsa, suhbatni "bloklangan" holatga
    /// o'tkazadi (lockedState ekrani — isBlocked orqali "obuna tugagan"dan farqlanadi).
    func blockUser(reason: String) async -> Bool {
        guard let otherId = room.other_user?.id else { return false }
        var req = makeRequest(path: "/auth/block/\(otherId)/", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["reason": reason])
        let (_, status) = await APIClient.shared.send(req)
        guard status == 200 else { return false }
        isLocked = true
        isBlocked = true
        lockMessage = LocalizationManager.get(.chatBlockedBody)
        stop()
        return true
    }

    /// Blokdan chiqaradi — muvaffaqiyatli bo'lsa, suhbatni qaytadan yuklab,
    /// WebSocket'ni qayta ulaydi (oddiy, bloklanmagan suhbat holatiga qaytadi).
    func unblockUser() async -> Bool {
        guard let otherId = room.other_user?.id else { return false }
        let req = makeRequest(path: "/auth/unblock/\(otherId)/", method: "POST")
        let (_, status) = await APIClient.shared.send(req)
        guard status == 200 else { return false }
        isLocked = false
        isBlocked = false
        lockMessage = nil
        await fetchMessages()
        connectWebSocket()
        return true
    }

    /// Shu xona uchun bildirishnomani yoqadi/o'chiradi (toggle). MUHIM: bu
    /// FAQAT push/in-app bildirishnomaga ta'sir qiladi — xabarlarning o'zi
    /// (chat ichida/WebSocket orqali) har doim odatdagidek davom etadi,
    /// hech narsa o'chirilmaydi yoki bloklanmaydi.
    func toggleMute() async -> Bool {
        let req = makeRequest(path: "/chat/rooms/\(room.id)/mute/", method: "POST")
        let (data, status) = await APIClient.shared.send(req)
        guard status == 200, let data,
              let decoded = try? JSONDecoder().decode(ChatMuteResponse.self, from: data) else { return false }
        isMuted = decoded.is_muted
        return true
    }

    /// "Chatni tozalash" — FAQAT shu foydalanuvchi (men) uchun, xabarlarni
    /// ko'rinishdan yashiradi. MUHIM (loyihaning qattiq qoidasi): bu hech
    /// qachon xabarlarni bazadan o'chirmaydi — suhbatdosh tomonida hammasi
    /// to'liq saqlanib qoladi va odatdagidek ko'rinishda davom etadi.
    /// Muvaffaqiyatli bo'lsa, mahalliy ro'yxatni ham bo'shatadi (server bilan
    /// mos holatga kelishi uchun keyingi `fetchMessages()` ham bo'sh qaytaradi).
    func clearChat() async -> Bool {
        let req = makeRequest(path: "/chat/rooms/\(room.id)/clear/", method: "POST")
        let (_, status) = await APIClient.shared.send(req)
        guard status == 200 else { return false }
        messages = []
        return true
    }

    /// Suhbat ichida matn bo'yicha qidiradi — oddiy xabarlar ro'yxatidan
    /// ataylab ajratilgan, "o'qildi" deb belgilash kabi yon ta'sirsiz endpoint.
    func searchMessages(query: String) async -> [ChatMessage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let req = makeRequest(path: "/chat/rooms/\(room.id)/messages/search/?q=\(encoded)", method: "GET")
        let (data, status) = await APIClient.shared.send(req)
        guard status == 200, let data else { return [] }
        if let list = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            return list
        }
        if let page = try? JSONDecoder().decode(ChatMessagesPage.self, from: data) {
            return page.results ?? []
        }
        return []
    }

    /// iOS skrinshot olinganini TAQIQLAY OLMAYDI — faqat
    /// `UIApplication.userDidTakeScreenshotNotification` orqali KEYIN sezadi.
    /// Shu sababli bu yerda faqat suhbatdoshga "skrinshot olindi" degan
    /// tizim xabarini yuboramiz (backend: ScreenshotAlertView — yangi
    /// 'system' turidagi Message yaratadi, bu mavjud broadcast orqali
    /// ikkinchi tomonga real vaqtda yetib boradi).
    func sendScreenshotAlert() async {
        let req = makeRequest(path: "/chat/rooms/\(room.id)/screenshot-alert/", method: "POST")
        let (data, status) = await APIClient.shared.send(req)
        guard status == 201, let data, let msg = try? JSONDecoder().decode(ChatMessage.self, from: data) else { return }
        messages.append(msg)
        onMessageActivity?(msg)
    }

    func deleteMessage(_ id: Int) async {
        let req = makeRequest(path: "/chat/messages/\(id)/delete/", method: "DELETE")
        let (_, status) = await APIClient.shared.send(req)
        guard status == 200, let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        let old = messages[idx]
        messages[idx] = ChatMessage(
            id: old.id, room: old.room, sender: old.sender, message_type: old.message_type,
            content: "", media: nil, story: old.story, duration: old.duration, latitude: nil, longitude: nil, reply_to: old.reply_to,
            is_read: old.is_read, seen_by_other: old.seen_by_other,
            is_deleted: true, is_edited: old.is_edited, created_at: old.created_at,
            disappear_seconds: old.disappear_seconds, viewed_at: old.viewed_at, disappear_expired: old.disappear_expired
        )
    }

    /// Matnli xabarni tahrirlaydi — FAQAT o'zi yuborgan, "text" turidagi va
    /// hali o'chirilmagan xabarlar uchun (boshqa foydalanuvchining xabarini
    /// tahrirlab bo'lmaydi — unda faqat nusxa olish mumkin). MUHIM: bu hech
    /// qachon yangi qator yaratmaydi yoki eskisini o'chirmaydi — faqat shu
    /// Message qatorining matni serverda yangilanadi.
    func editMessage(_ id: Int, content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var req = makeRequest(path: "/chat/messages/\(id)/edit/", method: "PATCH")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["content": trimmed])
        let (data, status) = await APIClient.shared.send(req)
        guard status == 200, let data,
              let updated = try? JSONDecoder().decode(ChatMessage.self, from: data),
              let idx = messages.firstIndex(where: { $0.id == id }) else { return false }
        messages[idx] = updated
        return true
    }
}
