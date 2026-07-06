import Foundation

// MARK: - Typing (debounced — har bosilgan harfda WS ga yubormaymiz) & WebSocket
extension ChatRoomViewModel {

    func userIsTyping() {
        sendTyping(true)
        typingSendTask?.cancel()
        typingSendTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if Task.isCancelled { return }
            self?.sendTyping(false)
        }
    }

    /// `ChatRoomViewModel+Send.swift`dagi `performSend(_:...)` oxirida ham
    /// chaqiriladi — shu sababli `private` emas (boshqa fayldan ham foydalaniladi).
    func sendTyping(_ flag: Bool) {
        guard flag != lastSentTyping, !isLocked else { return }
        lastSentTyping = flag
        sendWS(["action": "typing", "is_typing": flag])
    }

    /// `start()` (asosiy faylda) va `unblockUser()` (`+Actions.swift`) dan ham
    /// chaqiriladi — shu sababli `private` emas.
    func connectWebSocket() {
        guard !isLocked else { return }
        guard let token = UserDefaults.standard.string(forKey: "access_token"), !token.isEmpty,
              let url = URL(string: "\(APIConfig.wsBase)/ws/chat/\(room.id)/?token=\(token)") else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        listen()
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                Task { @MainActor in
                    self.scheduleReconnect()
                }
            case .success(let frame):
                Task { @MainActor in
                    self.handleFrame(frame)
                    self.listen()
                }
            }
        }
    }

    /// WS uzilganda 2 soniyadan keyin qaytadan ulanishga harakat qiladi va,
    /// ulangandan so'ng, shu orada o'tkazib yuborilgan xabarlarni qo'lga
    /// olish uchun xabarlar ro'yxatini bir martagina qaytadan yuklaydi.
    private func scheduleReconnect() {
        guard !isLocked else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.connectWebSocket()
            await self.fetchMessages()
        }
    }

    private func sendWS(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func handleFrame(_ frame: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = frame,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        switch event {
        case "new_message":
            // O'ZIMIZ yuborgan xabar uchun (sendText/sendImage/sendVoice) bu
            // xabar ALLAQACHON performSend ichida mahalliy (optimistic) qo'shib
            // qo'yilgan — shu sababli bu yerda yana ishlov berish SHART EMAS.
            // Faqat BOSHQA foydalanuvchidan kelgan xabar uchun ishlov beramiz
            // — WS payload'da uning to'liq sender obyekti yo'q, shu sababli
            // shu BITTA xabarni `MessageDetailView` orqali alohida olib
            // kelamiz. MUHIM: avval bu yerda BUTUN tarix (`fetchMessages()`)
            // qayta yuklanardi — suhbat uzayishi bilan har bir yangi xabar
            // tobora SEKINLASHIB borardi (har safar minglab eski xabarni
            // qayta yuklash kerak bo'lardi). Endi har bir yangi xabar
            // suhbat uzunligidan qat'i nazar BIR XIL tezlikda keladi.
            guard let senderId = json["sender_id"] as? Int, senderId != myId,
                  let messageId = json["id"] as? Int else { return }
            Task {
                guard let msg = await self.fetchSingleMessage(messageId) else { return }
                // Poyga holatidan saqlanish (masalan WS ikki marta yetib
                // kelsa) — id bo'yicha allaqachon bor bo'lsa qayta qo'shmaymiz.
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                }
                // Suhbat OCHIQ turgan paytda kelgan xabarni darhol "o'qildi"
                // deb belgilaymiz — avval buni `fetchMessages()`ning ichidagi
                // (list endpoint) yon ta'siri bajarardi, endi har bir xabar
                // uchun BUTUN ro'yxatni qayta yuklamasdan, mavjud WS `read`
                // amali orqali (consumer: `handle_read`) faqat shu BITTA
                // xabar belgilanadi va suhbatdoshga "ko'rildi" (✓✓) hodisasi
                // jonli yuboriladi.
                self.sendWS(["action": "read", "message_id": msg.id])
                // Suhbatdosh yozdi — shu xonani ham ro'yxat boshiga ko'chirish
                // uchun xabar beramiz (men yozganimdagi kabi).
                self.onMessageActivity?(msg)
            }
        case "typing":
            if let uid = json["user_id"] as? Int, uid != myId {
                let flag = json["is_typing"] as? Bool ?? false
                otherTyping = flag
                typingHideTask?.cancel()
                if flag {
                    typingHideTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if Task.isCancelled { return }
                        self?.otherTyping = false
                    }
                }
            }
        case "message_read":
            if let messageId = json["message_id"] as? Int,
               let idx = messages.firstIndex(where: { $0.id == messageId }) {
                let old = messages[idx]
                messages[idx] = ChatMessage(
                    id: old.id, room: old.room, sender: old.sender, message_type: old.message_type,
                    content: old.content, media: old.media, story: old.story, duration: old.duration,
                    latitude: old.latitude, longitude: old.longitude,
                    reply_to: old.reply_to,
                    is_read: old.is_read, seen_by_other: true,
                    is_deleted: old.is_deleted, is_edited: old.is_edited, created_at: old.created_at,
                    disappear_seconds: old.disappear_seconds, viewed_at: old.viewed_at, disappear_expired: old.disappear_expired
                )
            }
        case "presence":
            if let uid = json["user_id"] as? Int, uid != myId {
                otherOnline = json["is_online"] as? Bool ?? otherOnline
            }
        default:
            break
        }
    }

    /// WS orqali kelgan "new_message" hodisasi uchun — BUTUN tarixni qayta
    /// yuklamasdan, faqat shu BITTA xabarning to'liq ma'lumotini (sender,
    /// media, reply_to va h.k. — WS broadcast yengil payload yuboradi)
    /// serverdan olib keladi. Tezlik uchun: `GET /chat/messages/<id>/`.
    private func fetchSingleMessage(_ id: Int) async -> ChatMessage? {
        let req = makeRequest(path: "/chat/messages/\(id)/", method: "GET")
        let (data, status) = await APIClient.shared.send(req)
        guard status == 200, let data,
              let msg = try? JSONDecoder().decode(ChatMessage.self, from: data) else { return nil }
        return msg
    }
}
