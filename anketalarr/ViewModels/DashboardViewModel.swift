import Foundation
import SwiftUI
import Combine
import CoreLocation

// MARK: - Models

struct DashMe: Decodable {
    let id: Int
    let email: String?
    let phone: String?
    let profile: DashProfile?
    let main_photo: DashPhoto?
    let photos: [DashPhoto]?
    let subscription_type: String?
    let is_online: Bool?
    let created_at: String?

    /// Profil ekranida ko'rsatish uchun saralangan rasmlar ro'yxati
    var sortedPhotos: [DashPhoto] {
        if let all = photos, !all.isEmpty {
            return all.sorted { ($0.order ?? 999) < ($1.order ?? 999) }
        }
        if let main = main_photo { return [main] }
        return []
    }
}

struct DashInterest: Identifiable, Decodable {
    let id: Int
    let name: String?
    let name_uz: String?
    let name_ru: String?
    let icon: String?

    func localName(lang: LocalizationManager) -> String {
        switch lang.language {
        case .uz: return name_uz ?? name ?? ""
        case .ru: return name_ru ?? name ?? ""
        case .en: return name ?? name_uz ?? ""
        }
    }
}

struct DashGoal: Identifiable, Decodable {
    let id: Int
    let name: String?
    let name_uz: String?
    let name_ru: String?
    let icon: String?

    func localName(lang: LocalizationManager) -> String {
        switch lang.language {
        case .uz: return name_uz ?? name ?? ""
        case .ru: return name_ru ?? name ?? ""
        case .en: return name ?? name_uz ?? ""
        }
    }
}

struct DashRegion: Decodable {
    let id: Int
    let name: String?
    let name_uz: String?
    let name_ru: String?
    let country: Int?
}

struct DashDistrict: Decodable {
    let id: Int
    let name: String?
    let name_uz: String?
    let name_ru: String?
    let region: DashRegion?
}

struct DashProfile: Decodable {
    let first_name: String?
    let last_name: String?
    let patronymic: String?
    let birth_date: String?
    let social_tiktok: String?
    let social_instagram: String?
    let social_telegram: String?
    let age: Int?
    let gender: String?
    let bio: String?
    let height: Int?
    let weight: Int?
    let interests: [DashInterest]?
    let goals: [DashGoal]?
    let latitude: String?
    let longitude: String?
    let district: DashDistrict?
    let is_face_verified: Bool?
    let is_complete: Bool?

    init(first_name: String?, last_name: String?, patronymic: String?, birth_date: String?,
         social_tiktok: String? = nil, social_instagram: String? = nil, social_telegram: String? = nil,
         age: Int?, gender: String?, bio: String?, height: Int?, weight: Int?,
         interests: [DashInterest]?, goals: [DashGoal]?, latitude: String?, longitude: String?,
         district: DashDistrict?, is_face_verified: Bool? = nil, is_complete: Bool? = nil) {
        self.first_name = first_name
        self.last_name = last_name
        self.patronymic = patronymic
        self.birth_date = birth_date
        self.social_tiktok = social_tiktok
        self.social_instagram = social_instagram
        self.social_telegram = social_telegram
        self.age = age
        self.gender = gender
        self.bio = bio
        self.height = height
        self.weight = weight
        self.interests = interests
        self.goals = goals
        self.latitude = latitude
        self.longitude = longitude
        self.district = district
        self.is_face_verified = is_face_verified
        self.is_complete = is_complete
    }
}

struct DashPhoto: Decodable {
    let id: Int?
    let image: String?
    let is_main: Bool?
    let order: Int?

    var photoURL: URL? { image.flatMap { URL(string: $0) } }
}

struct DashUser: Identifiable, Decodable {
    let id: Int
    let profile: DashProfile?
    let main_photo: DashPhoto?
    let photos: [DashPhoto]?
    let subscription_type: String?
    let is_online: Bool?
    let last_seen: String?

    var displayName: String {
        let fn = profile?.first_name ?? ""
        let ln = profile?.last_name ?? ""
        let full = [fn, ln].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? LocalizationManager.get(.dbUser) : full
    }

    /// Xarita pin'i ostida ko'rsatiladigan qisqa ism — to'liq ism o'rniga
    /// faqat ism (familiya yo'q, pin labeli uchun joy tejaydi).
    var mapLabel: String {
        let fn = profile?.first_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fn.isEmpty ? displayName : fn
    }

    var age: Int? { profile?.age }
    var photoURL: URL? { main_photo?.image.flatMap { URL(string: $0) } }
    var isPremium: Bool { subscription_type == "premium" || subscription_type == "vip" }

    /// Sorted photos array (falls back to main_photo if photos is empty)
    var sortedPhotos: [DashPhoto] {
        if let all = photos, !all.isEmpty {
            return all.sorted { ($0.order ?? 999) < ($1.order ?? 999) }
        }
        if let main = main_photo { return [main] }
        return []
    }

    /// Xarita uchun koordinata (lat/lng string → Double)
    var coordinate: CLLocationCoordinate2D? {
        guard let latStr = profile?.latitude, let lngStr = profile?.longitude,
              let lat = Double(latStr), let lng = Double(lngStr) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct DashBanner: Identifiable, Decodable {
    let id: Int
    let title: String
    let description: String
    let image: String?
    let link_url: String?
    let order: Int?

    var imageURL: URL? { image.flatMap { URL(string: $0) } }
}

struct DashNews: Identifiable, Decodable {
    let id: Int
    let title: String
    let description: String
    let content: String?
    let image: String?
    let published_at: String?

    var imageURL: URL? { image.flatMap { URL(string: $0) } }
    var formattedDate: String {
        guard let raw = published_at else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) {
            let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"
            return f.string(from: d)
        }
        return String(raw.prefix(10))
    }
}

struct DashStory: Identifiable, Decodable {
    let id: Int
    let user: DashUser?
    let media: String?
    let media_type: String?
    let caption: String?
    let is_viewed: Bool?
    let views_count: Int?
    let reactions_count: Int?
    let created_at: String?

    var mediaURL: URL? { media.flatMap { URL(string: $0) } }

    var formattedTime: String {
        guard let raw = created_at else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: raw) ?? {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
            return f.date(from: raw)
        }() else { return String(raw.prefix(10)) }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 3600 { return "\(diff / 60) \(LocalizationManager.get(.storyMinutes))" }
        if diff < 86400 { return "\(diff / 3600) \(LocalizationManager.get(.storyHours))" }
        return "\(diff / 86400) \(LocalizationManager.get(.storyDays))"
    }
}

struct SearchPage: Decodable {
    let count: Int?
    let results: [DashUser]
}

// MARK: - FilterTab

enum DashFilter: String, CaseIterable {
    case forYou  = "recommended"
    case nearby  = "nearby"
    case newUser = "newest"

    func title(lang: LocalizationManager) -> String {
        switch self {
        case .forYou:  return lang[.dbForYou]
        case .nearby:  return lang[.dbNearby]
        case .newUser: return lang[.dbNew]
        }
    }
}

// MARK: - ViewModel

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var me: DashMe?
    @Published var myStory: DashStory? = nil

    var viewerIsVip: Bool {
        me?.subscription_type == "premium" || me?.subscription_type == "vip"
    }

    /// Bugun story qo'yilganmi?
    var hasStoryToday: Bool { myStory != nil }

    @Published var stories: [DashStory] = []
    @Published var banners: [DashBanner] = []
    @Published var news: [DashNews] = []
    @Published var users: [DashUser] = []
    @Published var unreadCount: Int = 0
    @Published var selectedFilter: DashFilter = .forYou
    @Published var isLoading = false
    @Published var selectedBanner: DashBanner? = nil
    @Published var selectedNews: DashNews? = nil
    @Published var errorMsg: String? = nil
    // MARK: - Load all

    func loadAll() {
        Task {
            isLoading = true
            await fetchMe()
            async let b: () = fetchStories()
            async let c: () = fetchBanners()
            async let d: () = fetchNews()
            async let e: () = fetchUnreadCount()
            async let f: () = fetchUsers(filter: .forYou)
            async let g: () = fetchMyStory()
            _ = await (b, c, d, e, f, g)
            isLoading = false
        }
    }

    func switchFilter(_ f: DashFilter) {
        selectedFilter = f
        Task { await fetchUsers(filter: f) }
    }

    // MARK: - API Calls

    func fetchMe() async {
        guard let data = await get("\(APIConfig.base)/auth/me/") else { return }
        me = try? JSONDecoder().decode(DashMe.self, from: data)
    }

    func fetchStories() async {
        guard let data = await get("\(APIConfig.base)/stories/feed/") else { return }
        if let list = try? JSONDecoder().decode([DashStory].self, from: data) {
            stories = list
        }
    }

    func fetchMyStory() async {
        guard let data = await get("\(APIConfig.base)/stories/my/") else { return }
        if let list = try? JSONDecoder().decode([DashStory].self, from: data) {
            myStory = list.first
        }
    }

    /// Story soft-delete (backend is_deleted=True)
    func deleteMyStory() async {
        guard let story = myStory else { return }
        guard let url = URL(string: "\(APIConfig.base)/stories/\(story.id)/") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.timeoutInterval = 10
        _ = await APIClient.shared.send(req)
        myStory = nil
    }

    func fetchBanners() async {
        guard let data = await get("\(APIConfig.base)/home/banners/") else { return }
        if let list = try? JSONDecoder().decode([DashBanner].self, from: data) {
            banners = list
        }
    }

    func fetchNews() async {
        guard let data = await get("\(APIConfig.base)/home/news/") else { return }
        if let list = try? JSONDecoder().decode([DashNews].self, from: data) {
            news = list
        }
    }

    func fetchUsers(filter: DashFilter) async {
        var url = "\(APIConfig.base)/search/?ordering=\(filter.rawValue)&page_size=10"
        // Opposite gender filter
        if let gender = me?.profile?.gender {
            let opposite = gender.lowercased() == "male" ? "female" : "male"
            url += "&gender=\(opposite)"
        }
        guard let data = await get(url) else { return }
        if let page = try? JSONDecoder().decode(SearchPage.self, from: data) {
            users = page.results
        } else if let list = try? JSONDecoder().decode([DashUser].self, from: data) {
            users = list
        }
    }

    func fetchUnreadCount() async {
        guard let data = await get("\(APIConfig.base)/notifications/unread-count/") else { return }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // "count" yoki "unread_count" — backendga qarab
            if let c = obj["count"] as? Int        { unreadCount = c; return }
            if let c = obj["unread_count"] as? Int { unreadCount = c; return }
        }
        // Agar faqat raqam qaytsa
        if let c = try? JSONDecoder().decode(Int.self, from: data) {
            unreadCount = c
        }
    }

    // MARK: - Refresh

    func refresh() async {
        async let a: () = fetchMe()
        async let b: () = fetchStories()
        async let c: () = fetchBanners()
        async let d: () = fetchNews()
        async let e: () = fetchUnreadCount()
        async let f: () = fetchUsers(filter: selectedFilter)
        async let g: () = fetchMyStory()
        _ = await (a, b, c, d, e, f, g)
    }

    // MARK: - HTTP helper

    private func get(_ urlStr: String) async -> Data? {
        return await APIClient.shared.getData(urlStr)
    }
}
