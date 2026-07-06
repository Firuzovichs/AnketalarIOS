import Foundation
import SwiftUI
import Combine
// MARK: - Lookup modellari (filter dropdownlar uchun — Map va Like tablari BIRGALIKDA ishlatadi)

struct LocCountry: Identifiable, Decodable {
    let id: Int
    let name: String?
    let name_uz: String?
    let name_ru: String?
    let code: String?

    func localName(lang: LocalizationManager) -> String {
        switch lang.language {
        case .uz: return name_uz ?? name ?? ""
        case .ru: return name_ru ?? name ?? ""
        case .en: return name ?? name_uz ?? ""
        }
    }
}

struct LocRegion: Identifiable, Decodable {
    let id: Int
    let name: String?
    let name_uz: String?
    let name_ru: String?
    let country: Int?

    func localName(lang: LocalizationManager) -> String {
        switch lang.language {
        case .uz: return name_uz ?? name ?? ""
        case .ru: return name_ru ?? name ?? ""
        case .en: return name ?? name_uz ?? ""
        }
    }
}

struct LocDistrict: Identifiable, Decodable {
    let id: Int
    let name: String?
    let name_uz: String?
    let name_ru: String?
    let region: Int?

    func localName(lang: LocalizationManager) -> String {
        switch lang.language {
        case .uz: return name_uz ?? name ?? ""
        case .ru: return name_ru ?? name ?? ""
        case .en: return name ?? name_uz ?? ""
        }
    }
}

// MARK: - DRF pagination wrapper
// Backend ro'yxat endpointlari sahifalangan javob qaytaradi:
// {"count":N,"next":null,"previous":null,"results":[...]}
// Oddiy [T] sifatida decode qilishga urinish muvaffaqiyatsiz bo'lardi —
// shuning uchun avval shu wrapper bilan, bo'lmasa oddiy massiv bilan urinamiz.
struct PaginatedResponse<T: Decodable>: Decodable {
    let results: [T]
}

func decodeList<T: Decodable>(_ type: T.Type, from data: Data) -> [T]? {
    if let page = try? JSONDecoder().decode(PaginatedResponse<T>.self, from: data) {
        return page.results
    }
    return try? JSONDecoder().decode([T].self, from: data)
}

// MARK: - Umumiy filtr holati

/// "Qidirish" (xarita) va "Like" (swipe) tablari BIRGALIKDA ishlatadigan filtr holati:
/// yosh/bo'y/vazn oraliqlari, qiziqish/maqsad tanlovlari, davlat/viloyat/tuman va radius.
/// Har bir ekran o'z ViewModel'ida shu klassdan bitta nusxani composition orqali ushlab
/// turadi (`let filters = SearchFilterState()`), UI tomonida esa bitta umumiy
/// `SearchFilterSheet` ikkala tabda ham ishlatiladi — kod va fayllar takrorlanmaydi.
@MainActor
final class SearchFilterState: ObservableObject {
    // Yosh / Bo'y / Vazn
    @Published var minAge: Int? = nil
    @Published var maxAge: Int? = nil
    @Published var minHeight: Int? = nil
    @Published var maxHeight: Int? = nil
    @Published var minWeight: Int? = nil
    @Published var maxWeight: Int? = nil

    // Qiziqishlar / Maqsadlar
    @Published var selectedInterestIds: Set<Int> = []
    @Published var selectedGoalIds: Set<Int> = []

    // Davlat / Viloyat / Tuman
    @Published var selectedCountryId: Int? = nil
    @Published var selectedRegionId: Int? = nil
    @Published var selectedDistrictId: Int? = nil

    // Lookup ro'yxatlari
    @Published var countries: [LocCountry] = []
    @Published var regions: [LocRegion] = []
    @Published var districts: [LocDistrict] = []
    @Published var interests: [DashInterest] = []
    @Published var goals: [DashGoal] = []

    /// Radius (km). Bu qiymatni query'ga qo'shish-qo'shmaslik har bir
    /// chaqiruvchi ViewModel'ning o'zига bog'liq (markazi turlicha bo'ladi:
    /// xaritada bosilgan nuqta yoki o'z profil joylashuvi).
    @Published var radiusKm: Double = 10
    var hasActiveFilters: Bool {
        minAge != nil || maxAge != nil || minHeight != nil || maxHeight != nil ||
        minWeight != nil || maxWeight != nil || !selectedInterestIds.isEmpty ||
        !selectedGoalIds.isEmpty || selectedCountryId != nil || selectedRegionId != nil ||
        selectedDistrictId != nil
    }

    /// Backenddagi `apply_common_filters` qabul qiladigan query qismi
    /// (boshida "&" bilan, yoki bo'sh string). Radius BUNDA YO'Q.
    var queryString: String {
        var parts: [String] = []
        if let v = minAge        { parts.append("min_age=\(v)") }
        if let v = maxAge        { parts.append("max_age=\(v)") }
        if let v = minHeight     { parts.append("min_height=\(v)") }
        if let v = maxHeight     { parts.append("max_height=\(v)") }
        if let v = minWeight     { parts.append("min_weight=\(v)") }
        if let v = maxWeight     { parts.append("max_weight=\(v)") }
        if !selectedInterestIds.isEmpty {
            parts.append("interests=\(selectedInterestIds.map(String.init).joined(separator: ","))")
        }
        if !selectedGoalIds.isEmpty {
            parts.append("goals=\(selectedGoalIds.map(String.init).joined(separator: ","))")
        }
        if let v = selectedCountryId  { parts.append("country_id=\(v)") }
        if let v = selectedRegionId   { parts.append("region_id=\(v)") }
        if let v = selectedDistrictId { parts.append("district_id=\(v)") }
        return parts.isEmpty ? "" : "&" + parts.joined(separator: "&")
    }

    // MARK: - Lookup yuklash

    func loadLookups() {
        Task {
            async let a: () = fetchCountries()
            async let b: () = fetchInterests()
            async let c: () = fetchGoals()
            _ = await (a, b, c)
        }
    }

    func fetchCountries() async {
        guard let data = await get("\(APIConfig.base)/locations/countries/") else { return }
        if let list = decodeList(LocCountry.self, from: data) { countries = list }
    }

    func fetchRegions(countryId: Int) async {
        guard let data = await get("\(APIConfig.base)/locations/regions/?country=\(countryId)") else { return }
        if let list = decodeList(LocRegion.self, from: data) { regions = list }
    }

    func fetchDistricts(regionId: Int) async {
        guard let data = await get("\(APIConfig.base)/locations/districts/?region=\(regionId)") else { return }
        if let list = decodeList(LocDistrict.self, from: data) { districts = list }
    }

    func fetchInterests() async {
        guard let data = await get("\(APIConfig.base)/auth/interests/") else { return }
        if let list = decodeList(DashInterest.self, from: data) { interests = list }
    }

    func fetchGoals() async {
        guard let data = await get("\(APIConfig.base)/auth/goals/") else { return }
        if let list = decodeList(DashGoal.self, from: data) { goals = list }
    }

    /// Davlat tanlanganda — viloyat/tuman ro'yxatlarini tozalash va qaytadan yuklash
    func countryChanged(_ countryId: Int?) {
        selectedCountryId = countryId
        selectedRegionId = nil
        selectedDistrictId = nil
        regions = []
        districts = []
        guard let countryId else { return }
        Task { await fetchRegions(countryId: countryId) }
    }

    /// Viloyat tanlanganda — tuman ro'yxatini tozalash va qaytadan yuklash
    func regionChanged(_ regionId: Int?) {
        selectedRegionId = regionId
        selectedDistrictId = nil
        districts = []
        guard let regionId else { return }
        Task { await fetchDistricts(regionId: regionId) }
    }

    func clear() {
        minAge = nil; maxAge = nil
        minHeight = nil; maxHeight = nil
        minWeight = nil; maxWeight = nil
        selectedInterestIds = []
        selectedGoalIds = []
        selectedCountryId = nil
        selectedRegionId = nil
        selectedDistrictId = nil
        regions = []
        districts = []
        radiusKm = 10
    }

    private func get(_ urlStr: String) async -> Data? {
        await APIClient.shared.getData(urlStr)
    }
}
