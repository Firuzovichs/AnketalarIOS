import SwiftUI

/// iOS 26 system `.sheet`ni yon va pastdan ichkariga surib, floating card
/// ko'rinishiga o'tkazadi. Android bilan bir xil, ekranning ikki yoni va
/// pastiga zich yopishgan bottom sheet uchun to'liq ekranli overlay.
struct SearchFilterBottomOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }

                content()
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                    .frame(width: geo.size.width)
                    .frame(height: geo.size.height * 0.70)
                    .background(Color(.systemBackground))
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: 24,
                                bottomLeading: 0,
                                bottomTrailing: 0,
                                topTrailing: 24
                            )
                        )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 20, y: -4)
                    .offset(y: max(0, dragOffset))
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 110 || value.predictedEndTranslation.height > 190 {
                                    dismiss()
                                } else {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .background(Color.clear)
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
            isPresented = false
        }
    }
}

/// Umumiy qidiruv filtri — "Qidirish" (xarita) va "Like" (swipe) tablari
/// IKKALASI HAM shu bitta komponentni ishlatadi (kod takrorlanmasligi uchun).
/// Holat tashqaridan `SearchFilterState` orqali beriladi; bu sheet faqat UI va
/// draft-qiymatlarni boshqaradi, qaysi tarmoq so'rovini qachon yuborishni
/// chaqiruvchi (`onApply`) hal qiladi.
struct SearchFilterSheet: View {
    @ObservedObject var filters: SearchFilterState
    /// Like tabida radius (masofa) qatori yashiriladi — chunki u xarita
    /// nuqtasiga bog'lanmagan va hozircha Premium gating UI'i yo'q.
    var showRadius: Bool = true
    /// Radius filtri Premium/VIP talab qiladi (backend: `can_use_radius_filter`).
    /// `false` bo'lsa, qator qulflangan holatda ko'rsatiladi va slayder
    /// o'rniga bosilganda Obuna sahifasi ochiladi.
    var viewerIsVip: Bool = true
    var onApply: () -> Void = {}

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @EnvironmentObject var paywallGate: PaywallGate

    // Draft state — faqat "Qo'llash" bosilganda `filters` ga yoziladi
    @State private var minAgeText = ""
    @State private var maxAgeText = ""
    @State private var minHeightText = ""
    @State private var maxHeightText = ""
    @State private var minWeightText = ""
    @State private var maxWeightText = ""
    @State private var selectedInterestIds: Set<Int> = []
    @State private var selectedGoalIds: Set<Int> = []
    @State private var countryId: Int? = nil
    @State private var regionId: Int? = nil
    @State private var districtId: Int? = nil
    @State private var radiusVal: Double = 10

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text(lang[.mapFilterTitle])
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.top, 4)

                    rangeRow(title: lang[.mapAge], minText: $minAgeText, maxText: $maxAgeText)
                    rangeRow(title: lang[.psHeight], minText: $minHeightText, maxText: $maxHeightText)
                    rangeRow(title: lang[.psWeight], minText: $minWeightText, maxText: $maxWeightText)

                    if showRadius {
                        radiusRow
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        pickerRow(
                            title: lang[.mapCountry],
                            selectedName: countryId.flatMap { id in filters.countries.first { $0.id == id }?.localName(lang: lang) } ?? lang[.mapAny],
                            options: filters.countries.map { ($0.id, $0.localName(lang: lang)) },
                            onSelect: { id in
                                countryId = id; regionId = nil; districtId = nil
                                filters.countryChanged(id)
                            }
                        )
                        pickerRow(
                            title: lang[.mapRegion],
                            selectedName: regionId.flatMap { id in filters.regions.first { $0.id == id }?.localName(lang: lang) } ?? lang[.mapAny],
                            options: filters.regions.map { ($0.id, $0.localName(lang: lang)) },
                            onSelect: { id in
                                regionId = id; districtId = nil
                                filters.regionChanged(id)
                            }
                        )
                        .opacity(countryId == nil ? 0.4 : 1)
                        .disabled(countryId == nil)

                        pickerRow(
                            title: lang[.mapDistrict],
                            selectedName: districtId.flatMap { id in filters.districts.first { $0.id == id }?.localName(lang: lang) } ?? lang[.mapAny],
                            options: filters.districts.map { ($0.id, $0.localName(lang: lang)) },
                            onSelect: { id in districtId = id }
                        )
                        .opacity(regionId == nil ? 0.4 : 1)
                        .disabled(regionId == nil)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang[.psStep3])
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        chipGrid(
                            items: filters.interests.map { ($0.id, $0.localName(lang: lang), $0.icon ?? "") },
                            selected: $selectedInterestIds
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang[.psStep4])
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        chipGrid(
                            items: filters.goals.map { ($0.id, $0.localName(lang: lang), $0.icon ?? "") },
                            selected: $selectedGoalIds
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // Tozalash/Qo'llash — ScrollView ICHIDA emas, doim ko'rinadigan
            // qattiq footer sifatida. Aks holda uzun ro'yxatlar (qiziqishlar/
            // maqsadlar ko'p bo'lganda) tugmalarni scroll qilib chiqarib
            // yuborardi va ular butunlay ko'rinmay qolardi.
            Divider().opacity(0.5)

            HStack(spacing: 12) {
                Button(action: clearAll) {
                    Text(lang[.mapClear])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.primaryLight.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button(action: applyAll) {
                    Text(lang[.mapApply])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.buttonGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .onAppear(perform: syncFromState)
    }

    // MARK: - Sync

    private func syncFromState() {
        minAgeText = filters.minAge.map(String.init) ?? ""
        maxAgeText = filters.maxAge.map(String.init) ?? ""
        minHeightText = filters.minHeight.map(String.init) ?? ""
        maxHeightText = filters.maxHeight.map(String.init) ?? ""
        minWeightText = filters.minWeight.map(String.init) ?? ""
        maxWeightText = filters.maxWeight.map(String.init) ?? ""
        selectedInterestIds = filters.selectedInterestIds
        selectedGoalIds = filters.selectedGoalIds
        countryId = filters.selectedCountryId
        regionId = filters.selectedRegionId
        districtId = filters.selectedDistrictId
        radiusVal = filters.radiusKm
    }

    private func applyAll() {
        filters.minAge = Int(minAgeText); filters.maxAge = Int(maxAgeText)
        filters.minHeight = Int(minHeightText); filters.maxHeight = Int(maxHeightText)
        filters.minWeight = Int(minWeightText); filters.maxWeight = Int(maxWeightText)
        filters.selectedInterestIds = selectedInterestIds
        filters.selectedGoalIds = selectedGoalIds
        filters.selectedCountryId = countryId
        filters.selectedRegionId = regionId
        filters.selectedDistrictId = districtId
        if showRadius { filters.radiusKm = radiusVal }
        onApply()
    }

    private func clearAll() {
        minAgeText = ""; maxAgeText = ""
        minHeightText = ""; maxHeightText = ""
        minWeightText = ""; maxWeightText = ""
        selectedInterestIds = []; selectedGoalIds = []
        countryId = nil; regionId = nil; districtId = nil
        radiusVal = 10
        filters.clear()
        onApply()
    }

    // MARK: - Radius

    @ViewBuilder
    private var radiusRow: some View {
        if viewerIsVip {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(lang[.mapRadiusLabel])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("\(Int(radiusVal)) km")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.primary)
                }
                Slider(value: $radiusVal, in: 1...50, step: 1)
                    .tint(theme.primary)
            }
        } else {
            // Bepul foydalanuvchi uchun qator butunlay qulflangan ko'rinishda —
            // slayder o'rniga bosilganda Obuna sahifasi ochiladi.
            Button { paywallGate.present() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(lang[.mapRadiusLabel])
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary.opacity(0.7))
                    }
                    Slider(value: .constant(radiusVal), in: 1...50, step: 1)
                        .tint(theme.textSecondary.opacity(0.4))
                        .disabled(true)
                        .allowsHitTesting(false)
                }
                .opacity(0.55)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Range row (Yosh / Bo'y / Vazn)

    private func rangeRow(title: String, minText: Binding<String>, maxText: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            HStack(spacing: 10) {
                numberField(placeholder: lang[.mapFrom], text: minText)
                Text("—").foregroundColor(theme.textSecondary.opacity(0.6))
                numberField(placeholder: lang[.mapTo], text: maxText)
            }
        }
    }

    private func numberField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .font(.system(size: 14))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(theme.primaryLight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Location picker row (Davlat / Viloyat / Tuman)

    private func pickerRow(title: String, selectedName: String, options: [(Int, String)],
                            onSelect: @escaping (Int?) -> Void) -> some View {
        Menu {
            Button(lang[.mapAny]) { onSelect(nil) }
            ForEach(options, id: \.0) { id, name in
                Button(name) { onSelect(id) }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text(selectedName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(theme.primaryLight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Chip tanlash (Qiziqishlar / Maqsadlar)

    private func chipGrid(items: [(Int, String, String)], selected: Binding<Set<Int>>) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.0) { id, name, icon in
                let isSelected = selected.wrappedValue.contains(id)
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        if isSelected { selected.wrappedValue.remove(id) }
                        else          { selected.wrappedValue.insert(id) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if !icon.isEmpty { Text(icon).font(.system(size: 16)) }
                        Text(name)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundColor(isSelected ? .white : theme.primary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isSelected ? theme.primary : theme.primaryLight)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(theme.primary.opacity(isSelected ? 0 : 0.3), lineWidth: 1))
                }
            }
        }
    }
}

#Preview {
    SearchFilterSheet(filters: SearchFilterState())
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
