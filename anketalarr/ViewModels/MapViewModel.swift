import Foundation
import SwiftUI
import Combine
import CoreLocation

/// "Qidirish" (xarita) tab uchun ViewModel. Filtr holati endi bu yerda emas —
/// `SearchFilterState` orqali ushlab turiladi va "Like" tab bilan BIRGALIKDA
/// bitta `SearchFilterSheet` komponentini ishlatadi (kod takrorlanmasligi uchun).
@MainActor
class MapViewModel: ObservableObject {
    // Joriy foydalanuvchi
    @Published var me: DashMe?
    var viewerIsVip: Bool {
        me?.subscription_type == "premium" || me?.subscription_type == "vip"
    }

    // Xaritadagi odamlar
    @Published var users: [DashUser] = []
    @Published var isLoading = false

    /// Umumiy filtr holati — Map va Like tablari BIRGALIKDA ishlatadi.
    @Published var filters = SearchFilterState()
    private var lastLat: Double?
    private var lastLng: Double?
    private var moveTask: Task<Void, Never>?

    // MARK: - Me

    func fetchMe() async {
        guard let data = await get("\(APIConfig.base)/auth/me/") else { return }
        me = try? JSONDecoder().decode(DashMe.self, from: data)
    }

    // MARK: - Atrofdagilarni yuklash

    /// Xarita harakatlanganda chaqiriladi — debounce bilan (600ms)
    func regionDidChange(lat: Double, lng: Double) {
        lastLat = lat
        lastLng = lng
        moveTask?.cancel()
        moveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await fetchNearby(lat: lat, lng: lng)
        }
    }

    /// Filtr "Qo'llash"/"Tozalash" bosilganda — joriy markaz bo'yicha qayta yuklash
    func applyFilters() {
        guard let lat = lastLat, let lng = lastLng else { return }
        Task { await fetchNearby(lat: lat, lng: lng) }
    }

    func fetchNearby(lat: Double, lng: Double) async {
        lastLat = lat; lastLng = lng
        isLoading = true
        defer { isLoading = false }

        // `radius_km` server tomonda Premium+ bilan cheklangan (403
        // "radius_premium_only") — bepul foydalanuvchi uchun bu parametrni
        // umuman yubormaymiz, aks holda javob jim-jit dekodlanmay qolardi
        // (xuddi SwipeViewModel.fetchCandidate'dagi kabi).
        let radiusParam = viewerIsVip ? "&radius_km=\(filters.radiusKm)" : ""
        let url = "\(APIConfig.base)/search/map/?lat=\(lat)&lng=\(lng)" + radiusParam + filters.queryString

        guard let data = await get(url) else { return }
        if let list = try? JSONDecoder().decode([DashUser].self, from: data) {
            users = list
        }
    }

    // MARK: - HTTP helper

    private func get(_ urlStr: String) async -> Data? {
        return await APIClient.shared.getData(urlStr)
    }
}
