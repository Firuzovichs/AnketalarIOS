import Foundation
import SwiftUI
import Combine

// MARK: - Own profile screen ViewModel
// Dashboard'dagi DashMe/DashProfile/DashPhoto/DashStory modellaridan
// foydalanadi — qayta e'lon qilinmaydi.

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var me: DashMe? = nil
    @Published var myStories: [DashStory] = []
    @Published var isLoading = false
    @Published var isUploadingPhoto = false
    @Published var isSavingProfile = false
    @Published var errorMsg: String? = nil

    // Manzil (davlat/viloyat/tuman) — Tahrirlash ekranidagi Manzil tanlovi uchun.
    // LocCountry/LocRegion/LocDistrict — SearchFilterState.swift dagi umumiy lookup
    // modellari, bu yerda takror e'lon qilinmaydi.
    @Published var countries: [LocCountry] = []
    @Published var regions: [LocRegion] = []
    @Published var districts: [LocDistrict] = []
    @Published var interests: [DashInterest] = []
    @Published var goals: [DashGoal] = []

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        async let a: () = fetchMe()
        async let b: () = fetchMyStories()
        _ = await (a, b)
        isLoading = false
    }

    func refresh() async {
        await loadAll()
    }

    func fetchMe() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/auth/me/") else { return }
        if let decoded = try? JSONDecoder().decode(DashMe.self, from: data) {
            me = decoded
        }
    }

    func fetchMyStories() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/stories/my/") else { return }
        if let list = try? JSONDecoder().decode([DashStory].self, from: data) {
            myStories = list
        }
    }

    // MARK: - Photos

    /// MAX_USER_PHOTOS limitiga qarab — true bo'lsa yana rasm qo'shish mumkin
    var canAddMorePhotos: Bool {
        (me?.sortedPhotos.count ?? 0) < 5
    }

    /// Profil to'ldirilganlik foizi (0...100) — Profil tabidagi progress ring uchun.
    /// Og'irliklar: asosiy rasm 20, ≥3 rasm 10, bio 15, qiziqish 15, maqsad 15,
    /// manzil 10, yuz tasdiqlangan 15.
    var profileCompletionPercent: Int {
        var score = 0
        let photos = me?.sortedPhotos ?? []
        if !photos.isEmpty { score += 20 }
        if photos.count >= 3 { score += 10 }
        if let bio = me?.profile?.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 15
        }
        if let interests = me?.profile?.interests, !interests.isEmpty { score += 15 }
        if let goals = me?.profile?.goals, !goals.isEmpty { score += 15 }
        if me?.profile?.district != nil { score += 10 }
        if me?.profile?.is_face_verified == true { score += 15 }
        return score
    }

    func fetchCountries() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/locations/countries/") else { return }
        if let list = decodeList(LocCountry.self, from: data) { countries = list }
    }

    func fetchRegions(countryId: Int) async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/locations/regions/?country=\(countryId)") else { return }
        if let list = decodeList(LocRegion.self, from: data) { regions = list }
    }

    func fetchDistricts(regionId: Int) async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/locations/districts/?region=\(regionId)") else { return }
        if let list = decodeList(LocDistrict.self, from: data) { districts = list }
    }

    func fetchInterests() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.authBase)/interests/") else { return }
        struct Page: Decodable { let results: [DashInterest] }
        if let page = try? JSONDecoder().decode(Page.self, from: data), !page.results.isEmpty {
            interests = page.results
        }
    }

    func fetchGoals() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.authBase)/goals/") else { return }
        struct Page: Decodable { let results: [DashGoal] }
        if let page = try? JSONDecoder().decode(Page.self, from: data), !page.results.isEmpty {
            goals = page.results
        }
    }

    func uploadPhoto(imageData: Data) async -> Bool {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        guard let url = URL(string: "\(APIConfig.base)/auth/photos/") else { return false }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        var body = Data()
        let nl = "\r\n"
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(nl)\(nl)".data(using: .utf8)!)
        body.append(imageData)
        body.append(nl.data(using: .utf8)!)
        body.append("--\(boundary)--\(nl)".data(using: .utf8)!)
        req.httpBody = body

        let (_, status) = await APIClient.shared.send(req)
        guard status == 201 else {
            if status == 400 { errorMsg = LocalizationManager.get(.profPhotoLimitReached) }
            return false
        }
        await fetchMe()
        return true
    }

    /// Soft delete — backend faqat is_deleted=True qiladi, baza yozuvi qolaveradi
    func deletePhoto(id: Int) async -> Bool {
        guard let url = URL(string: "\(APIConfig.base)/auth/photos/\(id)/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.timeoutInterval = 10
        let (_, status) = await APIClient.shared.send(req)
        guard status == 204 else { return false }
        await fetchMe()
        return true
    }

    // MARK: - Stories

    /// Soft delete — backend StoryDetailView.delete() is_deleted=True qiladi
    func deleteStory(id: Int) async -> Bool {
        guard let url = URL(string: "\(APIConfig.base)/stories/\(id)/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.timeoutInterval = 10
        let (_, status) = await APIClient.shared.send(req)
        guard status == 204 else { return false }
        myStories.removeAll { $0.id == id }
        return true
    }

    // MARK: - Edit profile (mavjud /profile/setup/ endpoint, partial update)

    func updateProfile(
        firstName: String, lastName: String, patronymic: String,
        birthDate: String, gender: String, bio: String,
        height: Int?, weight: Int?,
        interestIds: [Int], goalIds: [Int],
        districtId: Int? = nil,
        socialTiktok: String? = nil,
        socialInstagram: String? = nil,
        socialTelegram: String? = nil
    ) async -> Bool {
        isSavingProfile = true
        defer { isSavingProfile = false }

        guard let url = URL(string: "\(APIConfig.base)/auth/profile/setup/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        var bodyDict: [String: Any] = [
            "first_name": firstName,
            "last_name":  lastName,
            "patronymic": patronymic,
            "birth_date": birthDate,
            "gender":     gender,
            "bio":        bio,
            "interest_ids": interestIds,
            "goal_ids":     goalIds,
        ]
        if let h = height { bodyDict["height"] = h }
        if let w = weight { bodyDict["weight"] = w }
        if let d = districtId { bodyDict["district_id"] = d }
        bodyDict["social_tiktok"] = socialTiktok?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        bodyDict["social_instagram"] = socialInstagram?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        bodyDict["social_telegram"] = socialTelegram?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

        let (data, status) = await APIClient.shared.send(req)
        guard (200..<300).contains(status) else { return false }
        if let data, let decoded = try? JSONDecoder().decode(DashMe.self, from: data) {
            me = decoded
        } else {
            await fetchMe()
        }
        return true
    }

    // MARK: - Logout

    func logout() {
        TokenManager.shared.clear()
    }
}
