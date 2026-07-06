import SwiftUI
import CoreLocation
import Combine

/// "Qidirish" tab — Yandex xaritada atrofdagi (10 km, kengaytirilishi mumkin)
/// qarama-qarshi jinsdagi foydalanuvchilarni ko'rsatadi. Radius/qidiruv hammaga BEPUL.
/// VIP bo'lmagan ko'ruvchi uchun pin rasmlari xira (dashboard bilan bir xil uslub)
/// va pin bosilganda profil o'rniga "Premium kerak" oynasi chiqadi.
struct MapTabView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @EnvironmentObject var paywallGate: PaywallGate

    @StateObject private var vm = MapViewModel()
    @StateObject private var loc = LocationManager()

    @State private var showFilter = false
    @State private var selectedProfileUser: DashUser? = nil
    @State private var centerOverride: CLLocationCoordinate2D? = nil
    @State private var didCenterOnGPS = false
    @State private var pendingRecenter = false

    private let tashkentFallback = CLLocationCoordinate2D(latitude: 41.311081, longitude: 69.240562)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            YandexMapView(
                centerOverride: $centerOverride,
                users: vm.users,
                viewerIsVip: vm.viewerIsVip,
                onRegionChanged: { coord in
                    vm.regionDidChange(lat: coord.latitude, lng: coord.longitude)
                },
                onPinTap: { user in
                    if vm.viewerIsVip {
                        selectedProfileUser = user
                    } else {
                        paywallGate.present()
                    }
                }
            )
            .ignoresSafeArea(edges: .top)

            filterButton
                .padding(.trailing, 16)
                .padding(.bottom, 96)
                .zIndex(2)

            locateMeButton
                .padding(.trailing, 20)
                .padding(.bottom, 164)
                .zIndex(2)

            if showFilter {
                DetailOverlay(isPresented: $showFilter) {
                    SearchFilterSheet(filters: vm.filters, showRadius: true, viewerIsVip: vm.viewerIsVip, onApply: {
                        vm.applyFilters()
                        withAnimation(.spring()) { showFilter = false }
                    })
                }
                .zIndex(3)
            }
        }
        .overlay(alignment: .top) { topBanner }
        .fullScreenCover(item: $selectedProfileUser) { user in
            UserProfileView(user: user, onDismiss: { selectedProfileUser = nil })
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .onAppear {
            Task { await vm.fetchMe() }
            vm.filters.loadLookups()
            loc.requestLocation()
            if centerOverride == nil {
                centerOverride = tashkentFallback
                Task { await vm.fetchNearby(lat: tashkentFallback.latitude, lng: tashkentFallback.longitude) }
            }
        }
        .onReceive(loc.$location.compactMap { $0 }) { location in
            // Xarita birinchi ochilganda har doim Toshkent markazida turishi kerak —
            // GPS joylashuvi faqat "Joyimni top" tugmasi bosilganda (pendingRecenter)
            // qo'llaniladi, avtomatik emas.
            guard pendingRecenter else { return }
            didCenterOnGPS = true
            pendingRecenter = false
            let coord = location.coordinate
            centerOverride = coord
            Task { await vm.fetchNearby(lat: coord.latitude, lng: coord.longitude) }
        }
    }

    // MARK: - "Joyimni top" tugmasi

    private var locateMeButton: some View {
        Button {
            pendingRecenter = true
            loc.requestLocation()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                if loc.isLoading {
                    ProgressView()
                        .tint(theme.primary)
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter tugmasi

    private var filterButton: some View {
        Button {
            withAnimation(.spring()) { showFilter = true }
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(theme.buttonGradient)
                    .frame(width: 54, height: 54)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)

                if vm.filters.hasActiveFilters {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Holat banneri (yuklanmoqda / joylashuv rad etilgan / odam topilmadi)

    @ViewBuilder
    private var topBanner: some View {
        VStack(spacing: 8) {
            if loc.denied {
                bannerLabel(lang[.mapLocationDenied])
            } else if loc.isLoading && !didCenterOnGPS {
                bannerLabel(lang[.mapLocating])
            } else if !vm.isLoading && vm.users.isEmpty {
                bannerLabel(lang[.mapNoUsers])
            }

            if vm.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 14)
        .allowsHitTesting(false)
    }

    private func bannerLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
    }
}

#Preview {
    MapTabView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
