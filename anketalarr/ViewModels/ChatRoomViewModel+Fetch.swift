import Foundation

// MARK: - Fetch
extension ChatRoomViewModel {

    func fetchMessages() async {
        // Bir vaqtning o'zida ikkita fetch ishga tushmasin (masalan, ekran
        // ochilganda boshlangan birinchi yuklash bilan WS'dan kelgan
        // "new_message" hodisasi bir-biriga poyga qilib, natijada ro'yxat
        // vaqtincha bo'sh ko'rinib ketmasligi uchun).
        guard !isFetchingMessages else { return }
        isFetchingMessages = true
        defer { isFetchingMessages = false }

        isLoading = true
        let req = makeRequest(path: "/chat/rooms/\(room.id)/messages/", method: "GET")
        let (data, status) = await APIClient.shared.send(req)

        if status == 403 {
            let errDetail = data.flatMap { try? JSONDecoder().decode(ChatErrorDetail.self, from: $0) }
            isLocked = true
            isBlocked = errDetail?.blocked == true
            lockMessage = LocalizationManager.errorText(code: errDetail?.code, detail: errDetail?.detail ?? LocalizationManager.get(.chatLockedDetail))
            isLoading = false
            return
        }

        // MessageListView endi har doim {"results": [...], "has_more": bool}
        // shaklida javob beradi (suhbatning faqat ENG SO'NGGI PAGE_SIZE
        // xabarini qaytaradi — tezlik uchun; eskirog'i `loadOlderMessages()`
        // orqali alohida so'raladi). Eski xom-massiv shakli ham (ehtiyot
        // yuzasidan) zaxira yo'l sifatida qoldirilgan.
        var decoded: [ChatMessage]? = nil
        var hasMore: Bool? = nil
        if let data, let page = try? JSONDecoder().decode(ChatMessagesPage.self, from: data), let results = page.results {
            decoded = results
            hasMore = page.has_more
        } else if let data, let list = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            decoded = list
        }
        // Ikkisi ham muvaffaqiyatsiz bo'lsa — ANIQ sababini (qaysi maydon/turdagi
        // nomuvofiqlik) Xcode konsolida ko'rsatish uchun xatoni qayta ushlaymiz
        // ("DECODE-FAILED" degan umumiy belgidan farqli, bu yerda DecodingError'ning
        // to'liq tasvirini chiqaramiz — masalan "keyNotFound", "typeMismatch" va
        // qaysi keyPath'da, shu orqali aniq qaysi maydon xato ekanini bilamiz).
        if decoded == nil, let data {
            _ = try? JSONDecoder().decode(ChatMessagesPage.self, from: data)
        }
        // Suhbatda allaqachon xabarlar bor ekan, ular hech qachon (hatto
        // o'chirilganda ham — DeleteMessageView faqat is_deleted=true qilib
        // matnini bo'shatadi, qatorni ro'yxatdan butunlay olib tashlamaydi)
        // 0 taga qaytib bo'lmaydi. Shu sababli bo'sh natijani e'tiborsiz
        // qoldiramiz — aks holda vaqtinchalik tarmoq/server uzilishida
        // suhbat bo'sh ko'rinib (xabarlar "yo'qolib") qolardi.
        if let decoded {
            if decoded.isEmpty && !messages.isEmpty {
                // Bo'sh natija e'tiborsiz qoldiriladi — oldingi xabarlar saqlanib qoladi.
            } else {
                messages = decoded
                if let hasMore { hasMoreOlderMessages = hasMore }
            }
        }
        isLoading = false
    }

    /// Suhbat yuqorisiga scroll qilinganda chaqiriladi — hozirgi eng ESKI
    /// (ro'yxatdagi birinchi) xabardan OLDINGI navbatdagi sahifani
    /// (`?before=<id>`) so'rab, natijani ro'yxat BOSHIGA qo'shadi. Bu
    /// `fetchMessages()`dagi kabi BUTUN tarixni qayta yuklamaydi — shu
    /// sababli suhbat qancha uzun bo'lishidan qat'i nazar tez ishlaydi.
    func loadOlderMessages() async {
        guard !isFetchingOlderMessages, hasMoreOlderMessages,
              let oldestId = messages.first?.id else { return }
        isFetchingOlderMessages = true
        isLoadingOlderMessages = true
        defer { isFetchingOlderMessages = false; isLoadingOlderMessages = false }

        let req = makeRequest(path: "/chat/rooms/\(room.id)/messages/?before=\(oldestId)", method: "GET")
        let (data, status) = await APIClient.shared.send(req)
        guard status == 200, let data,
              let page = try? JSONDecoder().decode(ChatMessagesPage.self, from: data),
              let older = page.results else { return }

        hasMoreOlderMessages = page.has_more ?? false
        guard !older.isEmpty else { return }
        // Poyga holatidan saqlanish uchun — shu orada (so'rov davomida)
        // allaqachon ro'yxatga qo'shilgan bo'lishi mumkin bo'lgan id'larni
        // ikki marta qo'shib qo'ymaslik uchun filtrlaymiz.
        let existingIds = Set(messages.map(\.id))
        let toPrepend = older.filter { !existingIds.contains($0.id) }
        guard !toPrepend.isEmpty else { return }
        messages = toPrepend + messages
    }

    /// O'chib ketadigan rasm ochilganda chaqiriladi — `viewed_at`ni serverda
    /// belgilab qo'yadi (faqat jo'natuvchidan boshqa ishtirokchi uchun ta'sir
    /// qiladi), so'ng yangilangan xabarni mahalliy ro'yxatda ham almashtiradi.
    func markPhotoViewed(_ id: Int) async {
        let req = makeRequest(path: "/chat/messages/\(id)/view/", method: "POST")
        let (data, status) = await APIClient.shared.send(req)
        guard status == 200, let data,
              let updated = try? JSONDecoder().decode(ChatMessage.self, from: data),
              let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx] = updated
    }

    /// To'liq ekran ko'rgazmasi hisoblagichi 0 ga yetganda chaqiriladi —
    /// serverga qayta murojaat qilmasdan, shu zahoti pufakchani "expired"
    /// holatiga o'tkazadi.
    func expireLocally(_ id: Int) {
        locallyExpiredPhotoIds.insert(id)
    }
}
