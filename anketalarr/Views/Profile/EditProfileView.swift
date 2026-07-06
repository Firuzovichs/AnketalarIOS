import SwiftUI

// Profilni tahrirlash — mavjud /auth/profile/setup/ endpoint orqali partial
// update qiladi (backendda hech qanday o'zgarish kerak emas). FlowLayout,
// DatePickerSheet, WheelPickerSheet — ProfileSetupView.swift dagi reusable
// top-level structlar.

struct EditProfileView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var lookupVM = AuthViewModel()
    @StateObject private var saveVM   = ProfileViewModel()

    let me: DashMe?
    var onSaved: () -> Void

    @State private var firstName  = ""
    @State private var lastName   = ""
    @State private var patronymic = ""
    @State private var birthDate  = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var gender     = ""
    @State private var bio        = ""
    @State private var heightVal: Int = 170
    @State private var weightVal: Int = 65

    @State private var selectedInterestIds: Set<Int> = []
    @State private var selectedGoalIds:     Set<Int> = []

    // Manzil (davlat/viloyat/tuman) — mavjud profile.district dan oldindan to'ldiriladi
    @State private var selectedCountryId:  Int? = nil
    @State private var selectedRegionId:   Int? = nil
    @State private var selectedDistrictId: Int? = nil
    @State private var initialDistrict: DashDistrict? = nil

    @State private var showDateSheet   = false
    @State private var showHeightSheet = false
    @State private var showWeightSheet = false
    @State private var errorMsg: String? = nil

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        nameFields
                        birthDateField
                        genderField
                        addressField
                        bodyFields
                        bioField
                        interestsField
                        goalsField

                        PrimaryButton(title: lang[.save], isLoading: saveVM.isSavingProfile) {
                            Task { await save() }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            prefill()
            lookupVM.fetchInterests()
            lookupVM.fetchGoals()
            Task {
                await saveVM.fetchCountries()
                // Yagona davlat bo'lsa — foydalanuvchi tanlamasa ham avtomatik belgilanadi
                if selectedCountryId == nil, saveVM.countries.count == 1 {
                    selectedCountryId = saveVM.countries.first?.id
                }
                if let countryId = selectedCountryId {
                    await saveVM.fetchRegions(countryId: countryId)
                    if let regionId = selectedRegionId {
                        await saveVM.fetchDistricts(regionId: regionId)
                    }
                }
            }
        }
        .sheet(isPresented: $showDateSheet) {
            DatePickerSheet(selection: $birthDate)
                .presentationDetents([.height(360)])
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .sheet(isPresented: $showHeightSheet) {
            WheelPickerSheet(value: $heightVal, range: 140...220, unit: "sm", title: lang[.psHeight])
                .presentationDetents([.height(320)])
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .sheet(isPresented: $showWeightSheet) {
            WheelPickerSheet(value: $weightVal, range: 40...200, unit: "kg", title: lang[.psWeight])
                .presentationDetents([.height(320)])
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .toast($errorMsg)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
            }
            Spacer()
            Text(lang[.profEditTitle])
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(theme.background)
    }

    // MARK: - Fields

    private var nameFields: some View {
        VStack(spacing: 12) {
            CustomTextField(icon: "person",      placeholder: lang[.psFirstName], text: $firstName)
            CustomTextField(icon: "person",      placeholder: lang[.psLastName],  text: $lastName)
            CustomTextField(icon: "person.fill", placeholder: "\(lang[.psPatronymic]) (\(lang[.psOptional]))",
                            text: $patronymic)
        }
    }

    private var birthDateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(lang[.psBirthDate], systemImage: "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)

            Button { showDateSheet = true } label: {
                HStack {
                    Text(formatDateDisplay(birthDate))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: theme.primary.opacity(0.12), radius: 8, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.primary.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    private var genderField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(lang[.psGender], systemImage: "person.2")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)

            HStack(spacing: 12) {
                genderButton("M", label: lang[.psMale],   icon: "♂")
                genderButton("F", label: lang[.psFemale], icon: "♀")
            }
        }
    }

    private func genderButton(_ value: String, label: String, icon: String) -> some View {
        let sel = gender == value
        return Button { withAnimation(.spring(response: 0.25)) { gender = value } } label: {
            VStack(spacing: 6) {
                Text(icon).font(.system(size: 24))
                Text(label)
                    .font(.system(size: 13, weight: sel ? .semibold : .regular))
                    .foregroundColor(sel ? .white : theme.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(sel ? theme.primary : theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(sel ? theme.primary : theme.primary.opacity(0.3), lineWidth: 1.5)
            )
        }
    }

    // MARK: - Manzil (davlat / viloyat / tuman)

    private var addressField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(lang[.profAddressTitle], systemImage: "mappin.and.ellipse")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)

            VStack(spacing: 10) {
                locationPickerRow(
                    placeholder: lang[.profSelectCountry],
                    selectedName: selectedCountryName,
                    options: saveVM.countries.map { ($0.id, $0.localName(lang: lang)) },
                    onSelect: { id in
                        selectedCountryId = id
                        selectedRegionId = nil
                        selectedDistrictId = nil
                        saveVM.regions = []
                        saveVM.districts = []
                        if let id { Task { await saveVM.fetchRegions(countryId: id) } }
                    }
                )
                locationPickerRow(
                    placeholder: lang[.profSelectRegion],
                    selectedName: selectedRegionName,
                    options: saveVM.regions.map { ($0.id, $0.localName(lang: lang)) },
                    onSelect: { id in
                        selectedRegionId = id
                        selectedDistrictId = nil
                        saveVM.districts = []
                        if let id { Task { await saveVM.fetchDistricts(regionId: id) } }
                    }
                )
                .opacity(selectedCountryId == nil ? 0.4 : 1)
                .disabled(selectedCountryId == nil)

                locationPickerRow(
                    placeholder: lang[.profSelectDistrict],
                    selectedName: selectedDistrictName,
                    options: saveVM.districts.map { ($0.id, $0.localName(lang: lang)) },
                    onSelect: { id in selectedDistrictId = id }
                )
                .opacity(selectedRegionId == nil ? 0.4 : 1)
                .disabled(selectedRegionId == nil)
            }
        }
    }

    private var selectedCountryName: String {
        if let id = selectedCountryId, let m = saveVM.countries.first(where: { $0.id == id }) {
            return m.localName(lang: lang)
        }
        return lang[.profSelectCountry]
    }

    private var selectedRegionName: String {
        if let id = selectedRegionId, let m = saveVM.regions.first(where: { $0.id == id }) {
            return m.localName(lang: lang)
        }
        // Ro'yxat hali yuklanmagan bo'lsa — profildagi xom nomdan foydalanish
        return initialDistrict?.region.flatMap(localizedName) ?? lang[.profSelectRegion]
    }

    private var selectedDistrictName: String {
        if let id = selectedDistrictId, let m = saveVM.districts.first(where: { $0.id == id }) {
            return m.localName(lang: lang)
        }
        return initialDistrict.flatMap(localizedName) ?? lang[.profSelectDistrict]
    }

    private func localizedName(_ d: DashRegion) -> String? {
        switch lang.language {
        case .uz: return d.name_uz ?? d.name
        case .ru: return d.name_ru ?? d.name
        case .en: return d.name ?? d.name_uz
        }
    }

    private func localizedName(_ d: DashDistrict) -> String? {
        switch lang.language {
        case .uz: return d.name_uz ?? d.name
        case .ru: return d.name_ru ?? d.name
        case .en: return d.name ?? d.name_uz
        }
    }

    private func locationPickerRow(placeholder: String, selectedName: String, options: [(Int, String)],
                                    onSelect: @escaping (Int?) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.0) { id, name in
                Button(name) { onSelect(id) }
            }
        } label: {
            HStack {
                Text(selectedName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(selectedName == placeholder ? theme.textSecondary.opacity(0.6) : theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13))
                    .foregroundColor(theme.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: theme.primary.opacity(0.12), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.primary.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var bodyFields: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label(lang[.psHeight], systemImage: "arrow.up.and.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Button { showHeightSheet = true } label: { metricCard(value: heightVal, unit: "sm") }
            }
            VStack(alignment: .leading, spacing: 6) {
                Label(lang[.psWeight], systemImage: "scalemass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Button { showWeightSheet = true } label: { metricCard(value: weightVal, unit: "kg") }
            }
        }
    }

    private func metricCard(value: Int, unit: String) -> some View {
        HStack {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.primary)
            Text(unit)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.primary.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: theme.primary.opacity(0.1), radius: 6, x: 0, y: 2)
        )
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(lang[.profBioTitle], systemImage: "text.alignleft")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)

            ZStack(alignment: .topLeading) {
                if bio.isEmpty {
                    Text(lang[.profBioPlaceholder])
                        .font(.system(size: 15))
                        .foregroundColor(theme.textSecondary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $bio)
                    .font(.system(size: 15))
                    .foregroundColor(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(height: 100)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: theme.primary.opacity(0.12), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.primary.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var interestsField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.psSelectInterests])
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            if lookupVM.interests.isEmpty {
                ProgressView().tint(theme.primary)
            } else {
                chipGrid(
                    items: lookupVM.interests.map { ($0.id, $0.displayName(lang: lang.language.rawValue), $0.icon) },
                    selected: $selectedInterestIds
                )
            }
        }
    }

    private var goalsField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.psSelectGoals])
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            if lookupVM.goals.isEmpty {
                ProgressView().tint(theme.primary)
            } else {
                chipGrid(
                    items: lookupVM.goals.map { ($0.id, $0.displayName(lang: lang.language.rawValue), $0.icon) },
                    selected: $selectedGoalIds
                )
            }
        }
    }

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

    // MARK: - Prefill

    private func prefill() {
        guard let profile = me?.profile else { return }
        firstName  = profile.first_name ?? ""
        lastName   = profile.last_name ?? ""
        patronymic = profile.patronymic ?? ""
        gender     = profile.gender ?? ""
        bio        = profile.bio ?? ""
        if let h = profile.height { heightVal = h }
        if let w = profile.weight { weightVal = w }
        if let bd = profile.birth_date, let parsed = parseDate(bd) {
            birthDate = parsed
        }
        selectedInterestIds = Set(profile.interests?.map { $0.id } ?? [])
        selectedGoalIds     = Set(profile.goals?.map { $0.id } ?? [])

        initialDistrict     = profile.district
        selectedDistrictId  = profile.district?.id
        selectedRegionId    = profile.district?.region?.id
        selectedCountryId   = profile.district?.region?.country
    }

    // MARK: - Save

    private func save() async {
        guard !firstName.isEmpty, !lastName.isEmpty, !gender.isEmpty else {
            errorMsg = lang[.errFillRequired]; return
        }
        let ok = await saveVM.updateProfile(
            firstName: firstName, lastName: lastName, patronymic: patronymic,
            birthDate: formatDate(birthDate), gender: gender, bio: bio,
            height: heightVal, weight: weightVal,
            interestIds: Array(selectedInterestIds), goalIds: Array(selectedGoalIds),
            districtId: selectedDistrictId
        )
        if ok {
            onSaved()
            dismiss()
        } else {
            errorMsg = lang[.errOccurred]
        }
    }

    // MARK: - Date helpers

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func formatDateDisplay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: lang.language == .ru ? "ru_RU" : lang.language == .en ? "en_US" : "uz_UZ")
        return f.string(from: date)
    }

    private func parseDate(_ str: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }
}

#Preview {
    EditProfileView(me: nil, onSaved: {})
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
