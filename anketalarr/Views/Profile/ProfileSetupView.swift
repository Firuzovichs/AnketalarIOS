import SwiftUI
import PhotosUI
import CoreLocation

// MARK: - Bosqichlar
enum ProfileStep: Int, CaseIterable {
    case basicInfo  = 0   // Ism, sana, jins
    case bodyInfo   = 1   // Bo'y, vazn
    case interests  = 2   // Qiziqishlar
    case goals      = 3   // Maqsadlar
    case photos     = 4   // Rasmlar
    case location   = 5   // Joylashuv
    case faceScan   = 6   // Yuz tekshiruvi
}

struct ProfileSetupView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @StateObject private var vm  = AuthViewModel()
    @StateObject private var loc = LocationManager()

    @AppStorage("profile_setup_done") private var profileSetupDone = false
    @AppStorage("access_token") private var accessToken = ""

    // Bosqich
    @State private var step: ProfileStep = .basicInfo

    // basicInfo
    @State private var firstName  = ""
    @State private var lastName   = ""
    @State private var patronymic = ""
    @State private var birthDate  = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var gender     = ""
    @State private var showDateSheet = false

    // bodyInfo
    @State private var heightVal: Int = 170
    @State private var weightVal: Int = 65
    @State private var showHeightSheet = false
    @State private var showWeightSheet = false

    // interests / goals
    @State private var selectedInterestIds: Set<Int> = []
    @State private var selectedGoalIds:     Set<Int> = []

    // photos
    @State private var pickerItems:    [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage]          = []
    @State private var uploadingPhotos = false

    // face scan
    @State private var faceImage:       UIImage? = nil
    @State private var showCamera               = false
    @State private var uploadingFace            = false
    @State private var faceUploaded             = false

    // animation
    @State private var slideOffset:    CGFloat = 60
    @State private var contentOpacity: Double  = 0

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        stepContent
                            .offset(y: slideOffset)
                            .opacity(contentOpacity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }

            // Orqaga tugma bor — ikkala settings tugma o'ngda
            SettingsBar(hasBackButton: true)
        }
        .onAppear {
            animateIn()
            vm.fetchInterests()
            vm.fetchGoals()
        }
        .onChange(of: step) { _, _ in
            slideOffset = 60; contentOpacity = 0
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
                slideOffset = 0; contentOpacity = 1
            }
        }
        .onChange(of: pickerItems) { _, newItems in loadImages(from: newItems) }
        .toast($vm.errorMessage)
        // Date sheet
        .sheet(isPresented: $showDateSheet) {
            DatePickerSheet(selection: $birthDate)
                .presentationDetents([.height(360)])
                .environmentObject(theme)
                .environmentObject(lang)
        }
        // Height sheet
        .sheet(isPresented: $showHeightSheet) {
            WheelPickerSheet(
                value: $heightVal,
                range: 140...220, unit: lang.language == .en ? "ft" : "sm",
                title: lang[.psHeight]
            )
            .presentationDetents([.height(320)])
            .environmentObject(theme)
            .environmentObject(lang)
        }
        // Weight sheet
        .sheet(isPresented: $showWeightSheet) {
            WheelPickerSheet(
                value: $weightVal,
                range: 40...200, unit: "kg",
                title: lang[.psWeight]
            )
            .presentationDetents([.height(320)])
            .environmentObject(theme)
            .environmentObject(lang)
        }
        // Camera
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture(capturedImage: $faceImage)
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        VStack(spacing: 6) {
            HStack {
                // Orqaga
                if step != .basicInfo {
                    Button {
                        withAnimation(.spring()) {
                            step = ProfileStep(rawValue: step.rawValue - 1)!
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 6)
                    }
                } else {
                    Button {
                        TokenManager.shared.clear()
                        accessToken = ""
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 6)
                    }
                }

                Spacer()

                Text(lang[.psTitle])
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                // SettingsBar tugmalari shu joyda chiqadi — placeholder
                Color.clear.frame(width: 88, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.primary.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(colors: [theme.primary, theme.primary.opacity(0.7)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(
                            width: geo.size.width * CGFloat(step.rawValue + 1) / CGFloat(ProfileStep.allCases.count),
                            height: 5
                        )
                        .animation(.spring(response: 0.4), value: step)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 20)

            HStack {
                Text(stepName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(step.rawValue + 1) / \(ProfileStep.allCases.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
        .background(theme.background)
    }

    private var stepName: String {
        switch step {
        case .basicInfo: return lang[.psStep1]
        case .bodyInfo:  return lang[.psStep2]
        case .interests: return lang[.psStep3]
        case .goals:     return lang[.psStep4]
        case .photos:    return lang[.psStep5]
        case .location:  return lang[.psStep6]
        case .faceScan:  return lang[.psStep7]
        }
    }

    // MARK: - Bosqich kontent
    // Har bir bosqich endi alohida komponent (Views/Profile/Profile*Step.swift).
    // Bu yerda faqat tegishli holat (binding) va o'tish callback'lari ulanadi.
    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .basicInfo:
            ProfileBasicInfoStep(
                vm: vm,
                firstName: $firstName,
                lastName: $lastName,
                patronymic: $patronymic,
                birthDate: $birthDate,
                gender: $gender,
                showDateSheet: $showDateSheet,
                onContinue: { withAnimation(.spring()) { step = .bodyInfo } }
            )
        case .bodyInfo:
            ProfileBodyInfoStep(
                heightVal: $heightVal,
                weightVal: $weightVal,
                showHeightSheet: $showHeightSheet,
                showWeightSheet: $showWeightSheet,
                onContinue: { withAnimation(.spring()) { step = .interests } }
            )
        case .interests:
            ProfileInterestsStep(
                vm: vm,
                selectedInterestIds: $selectedInterestIds,
                onContinue: { withAnimation(.spring()) { step = .goals } }
            )
        case .goals:
            ProfileGoalsStep(
                vm: vm,
                selectedGoalIds: $selectedGoalIds,
                onContinue: { submitProfile() }
            )
        case .photos:
            ProfilePhotosStep(
                vm: vm,
                pickerItems: $pickerItems,
                selectedImages: $selectedImages,
                uploadingPhotos: $uploadingPhotos,
                onUpload: { uploadAllPhotos() }
            )
        case .location:
            ProfileLocationStep(
                loc: loc,
                onContinue: { withAnimation(.spring()) { step = .faceScan } }
            )
        case .faceScan:
            ProfileFaceScanStep(
                faceImage: $faceImage,
                showCamera: $showCamera,
                uploadingFace: $uploadingFace,
                faceUploaded: $faceUploaded,
                onUploadFace: { img in uploadFaceAndFinish(img) },
                onFinish: { profileSetupDone = true }
            )
        }
    }

    // MARK: - Profile yuborish
    private func submitProfile() {
        vm.setupProfile(
            firstName:   firstName,
            lastName:    lastName,
            patronymic:  patronymic,
            birthDate:   formatDate(birthDate),
            gender:      gender,
            height:      heightVal,
            weight:      weightVal,
            latitude:    loc.location?.coordinate.latitude,
            longitude:   loc.location?.coordinate.longitude,
            interestIds: Array(selectedInterestIds),
            goalIds:     Array(selectedGoalIds)
        ) { success in
            if success {
                withAnimation(.spring()) { step = .photos }
            }
        }
    }

    // MARK: - Rasmlarni yuklash
    private func uploadAllPhotos() {
        uploadingPhotos = true
        let total = selectedImages.count
        var uploaded = 0
        for (idx, img) in selectedImages.enumerated() {
            guard let data = img.jpegData(compressionQuality: 0.8) else {
                uploaded += 1; if uploaded == total { onPhotosUploaded() }; continue
            }
            vm.uploadPhoto(imageData: data, isMain: idx == 0, order: idx) { _ in
                uploaded += 1; if uploaded == total { self.onPhotosUploaded() }
            }
        }
    }

    private func onPhotosUploaded() {
        uploadingPhotos = false
        withAnimation(.spring()) { step = .location }
    }

    // MARK: - Yuz skanerlash va yuklash
    private func uploadFaceAndFinish(_ img: UIImage) {
        guard let data = img.jpegData(compressionQuality: 0.85) else {
            profileSetupDone = true; return
        }
        uploadingFace = true
        vm.uploadFaceScan(imageData: data) { success in
            self.uploadingFace = false
            self.faceUploaded  = success
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.profileSetupDone = true
                }
            }
        }
    }

    // MARK: - Helpers
    private func loadImages(from items: [PhotosPickerItem]) {
        selectedImages = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    if case .success(let data) = result, let data, let img = UIImage(data: data) {
                        self.selectedImages.append(img)
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
            slideOffset = 0; contentOpacity = 1
        }
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
