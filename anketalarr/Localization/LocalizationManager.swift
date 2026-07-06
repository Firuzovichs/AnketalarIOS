import SwiftUI
import Combine

// MARK: - Til
enum AppLanguage: String, CaseIterable {
    case uz = "uz"
    case ru = "ru"
    case en = "en"

    var displayName: String {
        switch self {
        case .uz: return "O'z"
        case .ru: return "Рус"
        case .en: return "Eng"
        }
    }

    var flag: String {
        switch self {
        case .uz: return "🇺🇿"
        case .ru: return "🇷🇺"
        case .en: return "🇬🇧"
        }
    }
}

// MARK: - Manager
class LocalizationManager: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "app_language") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "uz"
        language = AppLanguage(rawValue: saved) ?? .uz
    }

    subscript(_ key: LKey) -> String {
        translations[language.rawValue]?[key] ?? translations["uz"]?[key] ?? key.rawValue
    }

    /// ViewModel va boshqa non-View joylar uchun
    static func get(_ key: LKey) -> String {
        let code = UserDefaults.standard.string(forKey: "app_language") ?? "uz"
        return translations[code]?[key] ?? translations["uz"]?[key] ?? key.rawValue
    }

    /// Backenddan kelgan xato javobini joriy tilga mos matnga aylantiradi.
    /// Backend har bir xato javobida (status >= 400) til biriga bog'liq
    /// bo'lmagan barqaror `'code'` maydonini qaytaradi (masalan "user_not_found");
    /// shu kod orqali mos `LKey` topiladi va joriy tilda ko'rsatiladi.
    /// `detail` (backenddan kelgan, doim o'zbekcha matn) FAQAT kod tanilmagan
    /// holatlarda zaxira sifatida ishlatiladi. `limit` — "daily_like_limit" va
    /// "daily_story_limit" kabi sondan foydalanadigan matnlar uchun (backend
    /// shu kodlar bilan birga qaytaradigan `limit` qiymati shu yerga beriladi).
    static func errorText(code: String?, detail: String?, limit: Int? = nil) -> String {
        guard let code, let key = errorCodeMap[code] else {
            return detail ?? get(.errOccurred)
        }
        let text = get(key)
        if let limit {
            return text.replacingOccurrences(of: "%d", with: String(limit))
        }
        return text
    }
}

/// Backend error 'code' -> LKey moslashtirish jadvali. Bir nechta kod bir xil
/// LKey'ga ishora qilishi mumkin (masalan "voice_premium_only" allaqachon mavjud
/// `chatVoicePremiumRequired` matnidan foydalanadi — bu yerda qayta yozilmaydi).
private let errorCodeMap: [String: LKey] = [
    "already_registered":    .errAlreadyRegistered,
    "otp_invalid":            .errOtpInvalid,
    "user_not_found":         .errUserNotFound,
    "wrong_password":         .errWrongPassword,
    "account_blocked":        .errAccountBlocked,
    "photo_not_found":        .errPhotoNotFound,
    "identifier_required":    .errIdentifier,
    "not_registered":         .errNotRegistered,
    "fill_all_fields":        .errFillAll,
    "password_too_short":     .errMinPwd,
    "cant_block_self":        .errCantBlockSelf,
    "cant_like_self":         .errCantLikeSelf,
    "daily_like_limit":       .errDailyLikeLimit,
    "super_like_limit":       .errSuperLikeLimit,
    "already_liked":          .errAlreadyLiked,
    "like_not_found":         .errLikeNotFound,
    "to_user_id_required":    .errToUserIdRequired,
    "cant_skip_self":         .errCantSkipSelf,
    "chat_blocked":           .errChatBlocked,
    "chat_locked":            .chatLockedDetail,
    "voice_premium_only":     .chatVoicePremiumRequired,
    "video_premium_only":     .chatVideoPremiumRequired,
    "empty_message":         .errEmptyMessage,
    "daily_story_limit":      .errDailyStoryLimit,
    "story_not_found":        .errStoryNotFound,
    "cant_reply_own_story":   .errCantReplyOwnStory,
    "story_reply_forbidden":  .errStoryReplyForbidden,
    "profile_incomplete":     .errProfileIncomplete,
    "radius_premium_only":    .errRadiusPremiumOnly,
    "latlng_required":        .errLatLngRequired,
    "latlng_invalid":         .errLatLngInvalid,
    "no_candidates":          .errNoCandidates,
    "not_found":              .errNotFound,
    "unknown_apple_product":  .errUnknownAppleProduct,
]

// MARK: - Kalidlar
// `LKey` enum endi alohida faylda: Localization/LKey.swift

// MARK: - Tarjimalar
// `uzT`/`ruT`/`enT` lug'atlari endi alohida fayllarda:
// Localization/Translations+UZ.swift, Translations+RU.swift, Translations+EN.swift
private let translations: [String: [LKey: String]] = [
    "uz": uzT, "ru": ruT, "en": enT
]

