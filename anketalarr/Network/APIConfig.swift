import Foundation

/// Backend manzillari — BUTUN ilova bo'ylab FAQAT shu yerdan foydalanilsin.
/// Muhitni almashtirish kerak bo'lsa (masalan, real serverga o'tishda),
/// faqat shu faylni o'zgartirish kifoya — boshqa hech qayerda
/// "http://localhost:8001..." qayta yozilmasin.
enum APIConfig {
    /// `/api/...` — search, matches, chat, stories, notifications va h.k.
    static let base = "http://localhost:8001/api"
    /// `/api/auth/...` — login, register, profile, photos
    static let authBase = "http://localhost:8001/api/auth"
    /// WebSocket (chat) bazasi
    static let wsBase = "ws://localhost:8001"
}
