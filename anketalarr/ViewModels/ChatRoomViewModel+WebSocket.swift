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
            // Qayta ulanishda o'qilmagan xabarlarni qayta belgilash
            Task { await self.sendReadReceiptsAfterConnect(for: self.messages) }
        }
    }

    private func sendWS(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }

    /// `fetchMessages()` kabi boshqa fayllardan chaqirilishi uchun — tarixdagi
    /// o'qilmagan xabarlarni WS orqali "o'qildi" deb belgilaydi.
    /// Natijada unread_count sifirga tushadi va jo'natuvchida ✓✓ paydo bo'ladi.
    func sendReadReceipts(for msgs: [ChatMessage]) {
        guard !isLocked, let me = myId else { return }
        msgs.filter { $0.is_read != true && $0.sender?.id != me && $0.id > 0 }
            .forEach { sendWS(["action": "read", "message_id": $0.id]) }
    }

    /// WS ulanishi tayyor bo'lganda (ping orqali tasdiqlab) read receipt yuboradi.
    /// URLSessionWebSocketTask.send() WS ochilmagan bo'lsa jim o'tib ketadi,
    /// shuning uchun ping bilan ulanish holatini tekshirish zarur.
    func sendReadReceiptsAfterConnect(for msgs: [ChatMessage]) async {
        // myId nil bo'lsa (ChatListViewModel hali yuklamagan bo'lsa) — o'zimiz olamiz.
        // Bu sendReadReceipts ichidagi `guard let me = myId else { return }` ni
        // ishonchli qiladi — read receipt hech qachon o'tkazib yuborilmaydi.
        if myId == nil {
            let req = makeRequest(path: "/auth/me/", method: "GET")
            let (data, _) = await APIClient.shared.send(req)
            if let data, let me = try? JSONDecoder().decode(DashMe.self, from: data) {
                myId = me.id
            }
        }

        for _ in 1...10 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard let task = webSocketTask, task.state == .running else { continue }
            var pingOK = false
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                task.sendPing { error in
                    pingOK = (error == nil)
                    cont.resume()
                }
            }
            if pingOK {
                sendReadReceipts(for: msgs)
                return
            }
        }
        // 5 soniya ichida ulanmasa — baribir yuboramiz
        sendReadReceipts(for: msgs)
    }

    private func handleFrame(_ frame: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = frame,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "chat_message":
            // Backend signals.py to'liq MessageSerializer ma'lumotini
            // json["message"] ichida yuboradi — sender, reply_to, media bilan.
            // Shu sababli endi alohida HTTP so'rov (fetchSingleMessage) kerak
            // emas: to'g'ridan-to'g'ri ChatMessage sifatida decode qilamiz.
            // O'ZIMIZ yuborgan xabar optimistic UI orqali allaqachon qo'shilgan —
            // faqat BOSHQA foydalanuvchidan kelgan xabarni qo'shamiz.
            guard let msgDict = json["message"],
                  let msgData = try? JSONSerialization.data(withJSONObject: msgDict),
                  let msg = try? JSONDecoder().decode(ChatMessage.self, from: msgData),
                  let senderId = msg.sender?.id, senderId != myId else { return }
            // Poyga holatidan saqlanish — id bo'yicha allaqachon bor bo'lsa
            // qayta qo'shmaymiz.
            if !messages.contains(where: { $0.id == msg.id }) {
                messages.append(msg)
            }
            // Suhbat OCHIQ turgan paytda kelgan xabarni darhol "o'qildi"
            // deb belgilaymiz — WS `read` amali orqali.
            sendWS(["action": "read", "message_id": msg.id])
            // Suhbatdosh xabar yozdi — ro'yxatni boshiga ko'tirish uchun.
            onMessageActivity?(msg)

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
}
