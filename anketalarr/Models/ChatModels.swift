import Foundation

// MARK: - Sana yordamchisi (NotificationsViewModel/DashNews bilan bir xil uslub)

func parseChatDate(_ raw: String?) -> Date? {
    guard let raw else { return nil }
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFraction.date(from: raw) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: raw)
}

func formattedChatTime(_ raw: String?) -> String {
    guard let d = parseChatDate(raw) else { return "" }
    let cal = Calendar.current
    let f = DateFormatter()
    if cal.isDateInToday(d) {
        f.dateFormat = "HH:mm"
    } else if cal.isDateInYesterday(d) {
        return LocalizationManager.get(.chatYesterday)
    } else if let days = cal.dateComponents([.day], from: d, to: Date()).day, days < 7 {
        f.dateFormat = "EEE"
    } else {
        f.dateFormat = "dd.MM.yyyy"
    }
    return f.string(from: d)
}

/// Telegram uslubidagi suzuvchi sana tasmasi uchun yorliq:
/// bugun → "Bugun", kecha → "Kecha", boshqa → "d MMMM" yoki "d MMMM yyyy"
func chatDateHeader(_ raw: String?) -> String {
    guard let d = parseChatDate(raw) else { return "" }
    let cal = Calendar.current
    if cal.isDateInToday(d)     { return LocalizationManager.get(.chatToday)     }
    if cal.isDateInYesterday(d) { return LocalizationManager.get(.chatYesterday) }
    let f = DateFormatter()
    let thisYear = cal.component(.year, from: Date())
    let msgYear  = cal.component(.year, from: d)
    f.dateFormat = (msgYear == thisYear) ? "d MMMM" : "d MMMM yyyy"
    let langCode = UserDefaults.standard.string(forKey: "app_language") ?? "uz"
    f.locale     = Locale(identifier: langCode == "ru" ? "ru" : "uz")
    return f.string(from: d)
}

// MARK: - Reply preview (xabar ichidagi "javob berilgan xabar")

struct ChatReplyPreview: Identifiable, Decodable {
    let id: Int
    let sender: DashUser?
    let message_type: String?
    let content: String?
    let media: String?
    let created_at: String?

    var mediaURL: URL? {
        guard let media else { return nil }
        if media.hasPrefix("http://") || media.hasPrefix("https://") { return URL(string: media) }
        let host = APIConfig.base.components(separatedBy: "/api").first ?? ""
        return URL(string: host + media)
    }

    var previewText: String {
        switch message_type {
        case "image": return LocalizationManager.get(.chatMsgPhoto)
        case "video": return LocalizationManager.get(.chatMsgVideo)
        case "video_note": return LocalizationManager.get(.chatMsgVideoNote)
        case "voice": return LocalizationManager.get(.chatMsgVoice)
        case "location": return LocalizationManager.get(.chatMsgLocation)
        case "disappearing_photo": return LocalizationManager.get(.chatMsgDisappearingPhoto)
        case "story_reply": return LocalizationManager.get(.chatMsgStoryReply)
        default:
            let c = content ?? ""
            return c.isEmpty ? LocalizationManager.get(.chatMsgPhoto) : c
        }
    }
}

// MARK: - Story javobi (xabar "story_reply" turida bo'lganda qaysi storyga
// javob yozilganini ko'rsatish uchun yengil nested model — `ChatReplyPreview`
// bilan bir xil uslubda).

struct ChatStoryRef: Decodable {
    let id: Int
    let media: String?
    let media_type: String?
    let caption: String?

    var mediaURL: URL? {
        guard let media else { return nil }
        if media.hasPrefix("http://") || media.hasPrefix("https://") { return URL(string: media) }
        let host = APIConfig.base.components(separatedBy: "/api").first ?? ""
        return URL(string: host + media)
    }
}

// MARK: - Xabar

struct ChatMessage: Identifiable, Decodable, Equatable {
    let id: Int
    let room: Int?
    let sender: DashUser?
    let message_type: String?
    let content: String?
    let media: String?
    // Faqat message_type == "story_reply" uchun to'ldiriladi — javob
    // yozilgan storyning qisqacha ma'lumoti (thumbnail uchun).
    let story: ChatStoryRef?
    // Faqat voice/video uchun — qurilmada YOZILGAN haqiqiy davomiylik (soniya).
    // Buni serverdan kelgan holatda to'g'ridan-to'g'ri ko'rsatamiz (pufakchada
    // remote fayldan qayta hisoblashga urinish ishonchsiz — ba'zi serverlar
    // range so'rovni qo'llab-quvvatlamaydi va AVURLAsset.load(.duration) 0
    // qaytarib qoladi, aslida shu "00:00" xatosining ildizi edi).
    let duration: Double?
    // Faqat message_type == "location" uchun to'ldirilgan bo'ladi.
    let latitude: Double?
    let longitude: Double?
    let reply_to: ChatReplyPreview?
    let is_read: Bool?
    let seen_by_other: Bool?
    let is_deleted: Bool?
    // Matn xabari keyinroq tahrirlangan bo'lsa true bo'ladi (EditMessageView) —
    // pufakchada "tahrirlangan" yorlig'ini ko'rsatish uchun.
    let is_edited: Bool?
    let created_at: String?
    // Faqat message_type == "disappearing_photo" uchun to'ldiriladi.
    // `viewed_at` boshqa ishtirokchi birinchi marta ochganda belgilanadi
    // (shu paytdan boshlab `disappear_seconds` hisobi ishga tushadi),
    // `disappear_expired` esa serverda hisoblangan "muddati tugadimi" bayrog'i —
    // true bo'lganda `media` allaqachon serverdan null qilib yuborilgan bo'ladi.
    let disappear_seconds: Int?
    let viewed_at: String?
    let disappear_expired: Bool?

    /// JSON'dan yuklanmaydi — faqat mahalliy "yuborilmoqda" placeholder uchun.
    var isPending: Bool = false

    /// JSON maydonlari — `isPending` Decodable'dan chiqarib tashlangan,
    /// shuning uchun serverdan kelgan xabarlarda har doim `false` bo'ladi.
    private enum CodingKeys: String, CodingKey {
        case id, room, sender, message_type, content, media, story, duration
        case latitude, longitude, reply_to, is_read, seen_by_other, is_deleted
        case is_edited, created_at, disappear_seconds, viewed_at, disappear_expired
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.is_read == rhs.is_read &&
        lhs.seen_by_other == rhs.seen_by_other && lhs.is_deleted == rhs.is_deleted &&
        lhs.is_edited == rhs.is_edited
    }

    /// "Tahrirlangan" yorlig'i ko'rsatilishi kerakmi.
    var isEdited: Bool { is_edited == true }

    /// Pending xabarlar — `isMine` har doim `true` (sender null bo'lsa ham).
    func isMine(_ myId: Int?) -> Bool {
        if isPending { return true }
        guard let myId else { return false }
        return sender?.id == myId
    }

    /// Optimistik "yuborilmoqda" xabar — serverga javob kutmasdan darhol
    /// chatda ko'rsatish uchun. Upload tugagach real server xabari bilan almashtiriladi.
    static func pending(id: Int, type: String, content: String? = nil, duration: Double? = nil) -> ChatMessage {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var msg = ChatMessage(
            id: id, room: nil, sender: nil,
            message_type: type, content: content, media: nil,
            story: nil, duration: duration,
            latitude: nil, longitude: nil, reply_to: nil,
            is_read: nil, seen_by_other: nil, is_deleted: nil,
            is_edited: nil, created_at: iso.string(from: Date()),
            disappear_seconds: nil, viewed_at: nil, disappear_expired: nil
        )
        msg.isPending = true
        return msg
    }

    var mediaURL: URL? {
        guard let media else { return nil }
        if media.hasPrefix("http://") || media.hasPrefix("https://") { return URL(string: media) }
        let host = APIConfig.base.components(separatedBy: "/api").first ?? ""
        return URL(string: host + media)
    }

    var formattedTime: String {
        guard let d = parseChatDate(created_at) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    /// Suhbatlar ro'yxatida ko'rsatiladigan qisqa matn ("Siz: ..." prefiksi bilan).
    func listPreview(myId: Int?) -> String {
        let prefix = isMine(myId) ? LocalizationManager.get(.chatYouPrefix) : ""
        if is_deleted == true {
            return prefix + LocalizationManager.get(.chatMsgDeleted)
        }
        switch message_type {
        case "image": return prefix + LocalizationManager.get(.chatMsgPhoto)
        case "video": return prefix + LocalizationManager.get(.chatMsgVideo)
        case "video_note": return prefix + LocalizationManager.get(.chatMsgVideoNote)
        case "voice": return prefix + LocalizationManager.get(.chatMsgVoice)
        case "location": return prefix + LocalizationManager.get(.chatMsgLocation)
        case "disappearing_photo": return prefix + LocalizationManager.get(.chatMsgDisappearingPhoto)
        case "story_reply": return prefix + LocalizationManager.get(.chatMsgStoryReply)
        case "system": return content == "screenshot_taken"
            ? (isMine(myId) ? LocalizationManager.get(.chatSystemScreenshotSelf) : LocalizationManager.get(.chatSystemScreenshotOther))
            : (content ?? "")
        default:
            let c = content ?? ""
            return prefix + c
        }
    }
}

// MARK: - Suhbat (Room)

struct ChatRoomModel: Identifiable, Decodable {
    let id: Int
    let room_type: String?
    let other_user: DashUser?
    let last_message: ChatMessage?
    let unread_count: Int?
    let is_locked: Bool?
    let is_blocked: Bool?
    let is_muted: Bool?
    let expires_at: String?
    let created_at: String?

    var isAdmin: Bool { room_type == "admin" }
    /// Ikki tomonlama bloklash holati (men bloklaganman YOKI meni bloklashgan).
    var blocked: Bool { is_blocked == true }
    /// Shu xona uchun bildirishnoma o'chirib qo'yilganmi (faqat menga ta'sir qiladi).
    var isMuted: Bool { is_muted == true }

    var displayName: String {
        if isAdmin { return LocalizationManager.get(.chatSupportName) }
        return other_user?.displayName ?? LocalizationManager.get(.dbUser)
    }

    var photoURL: URL? { other_user?.photoURL }
    var isOnline: Bool { other_user?.is_online == true }
    var unreadCount: Int { unread_count ?? 0 }
    var locked: Bool { is_locked == true }

    func preview(myId: Int?) -> String {
        if let lm = last_message { return lm.listPreview(myId: myId) }
        return isAdmin ? LocalizationManager.get(.chatSupportSub) : LocalizationManager.get(.chatNoMessages)
    }

    var timeLabel: String {
        formattedChatTime(last_message?.created_at ?? created_at)
    }

    /// Muddati tugashiga necha kun qolganini ko'rsatadi (faqat qulflanmagan, admin bo'lmagan xonalar uchun).
    var daysRemainingLabel: String? {
        guard !isAdmin, !locked, let exp = parseChatDate(expires_at) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0
        if days <= 0 { return LocalizationManager.get(.chatExpiresToday) }
        return String(format: LocalizationManager.get(.chatExpiresInDays), Int32(days))
    }
}

struct ChatRoomsPage: Decodable {
    let count: Int?
    let results: [ChatRoomModel]?
}

struct ChatMessagesPage: Decodable {
    let count: Int?
    let results: [ChatMessage]?
    /// Backend `MessageListView`dan: hali yuklanmagan ESKIROQ xabarlar
    /// bor-yo'qligi (`?before=<id>` bilan keyingi sahifani so'rash kerakmi).
    let has_more: Bool?
}

struct ChatMuteResponse: Decodable {
    let is_muted: Bool
}

struct ChatErrorDetail: Decodable {
    let detail: String?
    // 403 javobida qaysi sabab ekanini ajratish uchun — "muddati tugagan"
    // (locked) yoki "bloklangan" (blocked). Ikkisi ham bo'lmasa nil qoladi.
    let blocked: Bool?
    let locked: Bool?
    // Tilga mos xato matnini LocalizationManager.errorText(code:detail:) orqali
    // chiqarish uchun — backend har bir xato javobida shuni qaytaradi.
    let code: String?
}
