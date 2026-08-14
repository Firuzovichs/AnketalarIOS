import Foundation

// MARK: - Send
extension ChatRoomViewModel {

    func sendText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLocked, !isSending else { return }
        isSending = true

        // Optimistik: matn darhol chatda ko'rinsin
        let pendingId = nextPendingId()
        messages.append(.pending(id: pendingId, type: "text", content: trimmed))
        replyTo = nil
        isSending = false

        var req = makeRequest(path: "/chat/rooms/\(room.id)/messages/send/", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["message_type": "text", "content": trimmed]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        await performSend(req, pendingId: pendingId)
    }

    func sendImage(_ imageData: Data) async {
        guard !isLocked, !isSending else { return }
        isSending = true

        // Optimistik: darhol pufakcha ko'rsat, input tozalansin
        let pendingId = nextPendingId()
        messages.append(.pending(id: pendingId, type: "image"))
        replyTo = nil
        isSending = false

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = makeRequest(path: "/chat/rooms/\(room.id)/messages/send/", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendField(&body, boundary: boundary, name: "message_type", value: "image")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"chat_photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        await performSend(req, pendingId: pendingId)
    }

    /// `duration` — qurilmada yozish vaqtida o'lchangan haqiqiy uzunlik
    /// (soniya). Buni serverga ham yuborib qo'yamiz, shunda pufakchada
    /// ko'rsatish uchun remote fayldan qaytadan hisoblashga ehtiyoj
    /// qolmaydi (00:00 xatosining ildizi shu remote-hisoblash edi).
    func sendVoice(_ audioData: Data, duration: Double) async {
        guard !isLocked, !isSending else { return }
        isSending = true

        // Optimistik: darhol pufakcha ko'rsat, input tozalansin
        let pendingId = nextPendingId()
        messages.append(.pending(id: pendingId, type: "voice", duration: duration))
        replyTo = nil
        isSending = false

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = makeRequest(path: "/chat/rooms/\(room.id)/messages/send/", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendField(&body, boundary: boundary, name: "message_type", value: "voice")
        appendField(&body, boundary: boundary, name: "duration", value: "\(duration)")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        // mediaGated: true — bu yo'lda 403 odatda "Ovozli xabar Premium/VIP
        // uchun" degani (xona qulflangan bo'lsa, mic tugmasi umuman ko'rinmaydi).
        await performSend(req, pendingId: pendingId, mediaGated: true)
    }

    func sendVideo(_ videoData: Data) async {
        guard !isLocked, !isSending else { return }
        isSending = true

        // Optimistik: darhol pufakcha ko'rsat, input tozalansin
        let pendingId = nextPendingId()
        messages.append(.pending(id: pendingId, type: "video"))
        replyTo = nil
        isSending = false

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = makeRequest(path: "/chat/rooms/\(room.id)/messages/send/", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendField(&body, boundary: boundary, name: "message_type", value: "video")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"chat_video.mov\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        // mediaGated: true — video xabar ham (ovozli kabi) Premium/VIP talab qiladi.
        await performSend(req, pendingId: pendingId, mediaGated: true, gatedFallback: .chatVideoPremiumRequired)
    }

    func sendVideoNote(_ videoData: Data) async {
        guard !isLocked, !isSending else { return }
        isSending = true

        // Optimistik: darhol pufakcha ko'rsat, input tozalansin
        let pendingId = nextPendingId()
        messages.append(.pending(id: pendingId, type: "video_note"))
        replyTo = nil
        isSending = false

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = makeRequest(path: "/chat/rooms/\(room.id)/messages/send/", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendField(&body, boundary: boundary, name: "message_type", value: "video_note")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"video_note.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        await performSend(req, pendingId: pendingId, mediaGated: true, gatedFallback: .chatVideoPremiumRequired)
    }

    func sendLocation(lat: Double, lng: Double) async {
        guard !isLocked, !isSending else { return }
        isSending = true

        var req = makeRequest(path: "/chat/rooms/\(room.id)/messages/send/", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["message_type": "location", "latitude": lat, "longitude": lng]
        if let replyId = replyTo?.id { body["reply_to_id"] = replyId }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        await performSend(req)
    }

    /// `seconds` — 3/5/10 (foydalanuvchi tanlaydi). Boshqa ishtirokchi birinchi
    /// marta ochganda (`markPhotoViewed`) hisoblagich ishga tushadi; jo'natuvchi
    /// uchun (o'zi ochsa) muddat hech qachon boshlanmaydi (backend: faqat
    /// `sender_id != request.user.id` bo'lganda `viewed_at` belgilanadi).
    func sendDisappearingPhoto(_ imageData: Data, seconds: Int) async {
        guard !isLocked, !isSending else { return }
        isSending = true

        // Optimistik: darhol pufakcha ko'rsat, input tozalansin
        let pendingId = nextPendingId()
        messages.append(.pending(id: pendingId, type: "disappearing_photo"))
        replyTo = nil
        isSending = false

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = makeRequest(path: "/chat/rooms/\(room.id)/messages/send/", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendField(&body, boundary: boundary, name: "message_type", value: "disappearing_photo")
        appendField(&body, boundary: boundary, name: "disappear_seconds", value: "\(seconds)")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"chat_photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        await performSend(req, pendingId: pendingId)
    }

    /// `pendingId` — pending placeholder xabar ID'si (manfiy son). Serverdan
    /// javob kelgach, shu ID li xabar o'chirib tashlanib, real xabar qo'shiladi.
    /// `nil` bo'lsa (text/location uchun) — placeholder yo'q, oddiy append.
    private func performSend(
        _ req: URLRequest,
        pendingId: Int? = nil,
        mediaGated: Bool = false,
        gatedFallback: LKey = .chatVoicePremiumRequired
    ) async {
        let (data, status) = await APIClient.shared.send(req)
        if status == 201, let data, let msg = try? JSONDecoder().decode(ChatMessage.self, from: data) {
            // Pending xabarni olib tashlash va real xabar qo'shish
            if let pid = pendingId {
                messages.removeAll { $0.id == pid }
            }
            messages.append(msg)
            replyTo = nil
            onMessageActivity?(msg)
        } else if status == 403 {
            let errDetail = data.flatMap { try? JSONDecoder().decode(ChatErrorDetail.self, from: $0) }
            if mediaGated {
                // Pending xabarni olib tashlash (upload muvaffaqiyatsiz)
                if let pid = pendingId { messages.removeAll { $0.id == pid } }
                showVoiceError(LocalizationManager.errorText(code: errDetail?.code, detail: errDetail?.detail ?? LocalizationManager.get(gatedFallback)))
            } else {
                if let pid = pendingId { messages.removeAll { $0.id == pid } }
                isLocked = true
                isBlocked = errDetail?.blocked == true
                lockMessage = LocalizationManager.errorText(code: errDetail?.code, detail: errDetail?.detail ?? LocalizationManager.get(.chatLockedDetail))
            }
        } else {
            // Boshqa xato (tarmoq muammo, 5xx va h.k.) — pending olib tashlash
            if let pid = pendingId { messages.removeAll { $0.id == pid } }
        }
        isSending = false
        sendTyping(false)
    }

    /// `voiceError` bannerini ko'rsatadi va bir necha soniyadan keyin avtomatik yashiradi.
    private func showVoiceError(_ text: String) {
        voiceError = text
        voiceErrorClearTask?.cancel()
        voiceErrorClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if Task.isCancelled { return }
            self?.voiceError = nil
        }
    }

    private func appendField(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }
}
