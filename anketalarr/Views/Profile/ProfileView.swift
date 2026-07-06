import SwiftUI
import PhotosUI

// Yangi dizayn — kartalarga ajratilgan profil ekrani. Yordamchi kartalar:
// `ProfileSummaryCards.swift` (to'ldirilganlik/tasdiqlanganlik),
// `ProfileBasicInfoCard.swift` (Jins/Manzil/Yosh), `ProfileBioCard.swift` (bio).
//
// Profil ekranidagi "Hikoyalarim" bo'limida bosilgan story uchun bitta-storyli
// StoryGroup yaratamiz (StoryViewerView storyIndex'ni 0 dan boshlaydi —
// DashStoriesRow.ownStoryItem'dagi xuddi shu workaround).
private struct ProfileStoryPresentation: Identifiable {
    let id = UUID()
    let group: StoryGroup
}

struct ProfileView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    // Faqat pastdagi SettingsSheetView'ga (Obuna qatori) qayta in'ektsiya
    // qilish uchun kerak — bu ekranning o'zi paywall ko'rsatmaydi.
    @EnvironmentObject var paywallGate: PaywallGate
    @StateObject private var vm = ProfileViewModel()

    @State private var showEdit = false
    @State private var showSettings = false
    @State private var newPhotoItem: PhotosPickerItem? = nil
    @State private var photoToDelete: DashPhoto? = nil
    @State private var storyItem: ProfileStoryPresentation? = nil
    @State private var selectedMediaTab = 0   // 0 = Rasmlar, 1 = Hikoyalar
    @State private var showPhone = false
    /// Asosiy rasmga bosilganda to'liq ekranda ochiladigan rasm ko'ruvchi
    /// shu indeksdan boshlanadi (nil = yopiq).
    @State private var photoViewerStartIndex: Int? = nil

    private let gridCols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection

                    VStack(spacing: 14) {
                        ProfileSummaryCardsRow(
                            completionPercent: vm.profileCompletionPercent,
                            isVerified: vm.me?.profile?.is_face_verified == true
                        )

                        ProfileBasicInfoCard(
                            genderGlyph: genderGlyph,
                            genderText: genderText,
                            locationText: locationText,
                            ageText: ageText,
                            onEdit: { showEdit = true }
                        )

                        ProfileBioCard(bio: vm.me?.profile?.bio, onAddBio: { showEdit = true })

                        interestsCard
                        goalsCard
                        mediaCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 130)
                }
            }
            .refreshable { await vm.refresh() }

            bottomEditButton

            if vm.isLoading && vm.me == nil {
                ProgressView().tint(theme.primary).scaleEffect(1.3)
            }
        }
        .ignoresSafeArea(edges: .top)
        .task { await vm.loadAll() }
        .onChange(of: newPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    _ = await vm.uploadPhoto(imageData: data)
                }
                newPhotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showEdit) {
            EditProfileView(me: vm.me) {
                Task { await vm.fetchMe() }
            }
            .environmentObject(theme)
            .environmentObject(lang)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView()
                .environmentObject(theme)
                .environmentObject(lang)
                .environmentObject(paywallGate)
        }
        .fullScreenCover(item: $storyItem) { item in
            StoryViewerView(
                groups: [item.group],
                startGroupIndex: 0,
                isOwner: true,
                canSeeViewers: vm.me?.subscription_type == "premium" || vm.me?.subscription_type == "vip",
                onDismiss: { storyItem = nil },
                onDeleteStory: { id in
                    storyItem = nil
                    Task { _ = await vm.deleteStory(id: id) }
                }
            )
            .environmentObject(theme)
            .environmentObject(lang)
        }
        .alert(lang[.profDeletePhotoTitle], isPresented: Binding(
            get: { photoToDelete != nil }, set: { if !$0 { photoToDelete = nil } }
        )) {
            Button(lang[.cancel], role: .cancel) { photoToDelete = nil }
            Button(lang[.storyDelete], role: .destructive) {
                if let id = photoToDelete?.id {
                    Task { _ = await vm.deletePhoto(id: id) }
                }
                photoToDelete = nil
            }
        } message: {
            Text(lang[.profDeletePhotoMsg])
        }
        .fullScreenCover(isPresented: Binding(
            get: { photoViewerStartIndex != nil },
            set: { if !$0 { photoViewerStartIndex = nil } }
        )) {
            ProfilePhotoViewerView(
                photos: vm.me?.sortedPhotos ?? [],
                startIndex: photoViewerStartIndex ?? 0,
                onClose: { photoViewerStartIndex = nil }
            )
        }
        .toast($vm.errorMsg)
    }

    /// Asosiy rasmga bosilganda chaqiriladi — rasmlar ro'yxati bo'sh bo'lmasa,
    /// to'liq ekran ko'ruvchini xuddi shu (asosiy) rasmdan boshlab ochadi.
    private func openMainPhotoViewer() {
        let photos = vm.me?.sortedPhotos ?? []
        guard !photos.isEmpty else { return }
        photoViewerStartIndex = photos.firstIndex(where: { $0.is_main == true }) ?? 0
    }

    // MARK: - Header (oq doiraviy tugmalar + yengil gradient fon)

    private var headerSection: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [theme.primaryLight, theme.background],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundColor(theme.primary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white))
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        Text(lang[.profTitle])
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                    }
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.white))
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                avatarBlock

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                        if vm.me?.profile?.is_face_verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    }

                    if !subtitleText.isEmpty {
                        Text(subtitleText)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }

                    if let phone = vm.me?.phone, !phone.isEmpty {
                        phoneRevealButton(phone: phone)
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 22)
            }
        }
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 32,
                                    bottomTrailingRadius: 32, topTrailingRadius: 0)
        )
    }

    private var avatarBlock: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle().fill(Color.white)
                .frame(width: 108, height: 108)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            if let url = vm.me?.main_photo?.image.flatMap({ URL(string: $0) }) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                            .frame(width: 100, height: 100).clipShape(Circle())
                    } else { personIcon }
                }
            } else { personIcon }

            if vm.me?.is_online == true {
                Circle().fill(Color.green)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
            }
        }
        .contentShape(Circle())
        .onTapGesture { openMainPhotoViewer() }
    }

    private var personIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 38))
            .foregroundColor(theme.primary.opacity(0.45))
    }

    private var displayName: String {
        let fn = vm.me?.profile?.first_name ?? ""
        let ln = vm.me?.profile?.last_name ?? ""
        let full = [fn, ln].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? lang[.dbUser] : full
    }

    private var subtitleText: String {
        var parts: [String] = []
        if let age = vm.me?.profile?.age { parts.append("\(age) \(lang[.upYears])") }
        if vm.me?.is_online == true { parts.append(lang[.upOnline]) }
        return parts.joined(separator: " · ")
    }

    private func phoneRevealButton(phone: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showPhone.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showPhone ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 11))
                Text(showPhone ? phone : lang[.profShowPhoneNumber])
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(theme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    // MARK: - Gender / Location / Age (ProfileBasicInfoCard uchun)

    private var genderGlyph: String {
        switch vm.me?.profile?.gender {
        case "M": return "♂"
        case "F": return "♀"
        default:  return "•"
        }
    }

    private var genderText: String {
        switch vm.me?.profile?.gender {
        case "M": return lang[.psMale]
        case "F": return lang[.psFemale]
        default:  return lang[.profGenderUnset]
        }
    }

    private var locationText: String {
        guard let district = vm.me?.profile?.district else { return lang[.profLocationUnset] }
        let dName: String
        switch lang.language {
        case .uz: dName = district.name_uz ?? district.name ?? ""
        case .ru: dName = district.name_ru ?? district.name ?? ""
        case .en: dName = district.name ?? ""
        }
        var rName = ""
        if let region = district.region {
            switch lang.language {
            case .uz: rName = region.name_uz ?? region.name ?? ""
            case .ru: rName = region.name_ru ?? region.name ?? ""
            case .en: rName = region.name ?? ""
            }
        }
        let parts = [dName, rName].filter { !$0.isEmpty }
        return parts.isEmpty ? lang[.profLocationUnset] : parts.joined(separator: ", ")
    }

    private var ageText: String {
        guard let age = vm.me?.profile?.age else { return "—" }
        return "\(age) \(lang[.upYears])"
    }

    // MARK: - Interests / Goals (kartaga o'ralgan)

    private var interestsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.profInterestsTitle])
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            let interests = vm.me?.profile?.interests ?? []
            if interests.isEmpty {
                Text(lang[.profInterestsEmpty])
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(interests) { item in
                        displayChip(icon: item.icon, text: item.localName(lang: lang))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.profGoalsTitle])
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            let goals = vm.me?.profile?.goals ?? []
            if goals.isEmpty {
                Text(lang[.profGoalsEmpty])
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(goals) { item in
                        displayChip(icon: item.icon, text: item.localName(lang: lang))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private func displayChip(icon: String?, text: String) -> some View {
        HStack(spacing: 6) {
            if let icon, !icon.isEmpty { Text(icon).font(.system(size: 14)) }
            Text(text).font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(theme.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.primaryLight)
        .clipShape(Capsule())
    }

    // MARK: - Rasmlar / Hikoyalar kartasi

    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 26) {
                mediaTabButton(title: photosTabTitle, index: 0)
                mediaTabButton(title: lang[.profStories], index: 1)
                Spacer()
            }
            Divider()

            if selectedMediaTab == 0 {
                photosGrid
            } else {
                storiesGrid
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private var photosTabTitle: String {
        "\(lang[.profPhotos]) (\(vm.me?.sortedPhotos.count ?? 0)/5)"
    }

    private func mediaTabButton(title: String, index: Int) -> some View {
        let sel = selectedMediaTab == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedMediaTab = index }
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: sel ? .bold : .regular))
                    .foregroundColor(sel ? theme.primary : theme.textSecondary)
                Rectangle()
                    .fill(sel ? theme.primary : Color.clear)
                    .frame(width: 30, height: 2.5)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private var photosGrid: some View {
        let photos = vm.me?.sortedPhotos ?? []
        return Group {
            if photos.isEmpty {
                VStack(spacing: 10) {
                    Text(lang[.profPhotosEmpty])
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                    addPhotoCell.frame(width: 90, height: 90)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                LazyVGrid(columns: gridCols, spacing: 8) {
                    ForEach(photos, id: \.id) { photo in gridPhotoCell(photo) }
                    if vm.canAddMorePhotos { addPhotoCell }
                }
            }
        }
    }

    private func gridPhotoCell(_ photo: DashPhoto) -> some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url = photo.photoURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Color.white
                            }
                        }
                    } else {
                        Color.white
                    }
                }
                .frame(width: side, height: side)
                .clipped()

                Button { photoToDelete = photo } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.45)).frame(width: 18, height: 18))
                }
                .padding(4)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(photo.is_main == true ? theme.primary : Color.clear, lineWidth: 2)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var addPhotoCell: some View {
        GeometryReader { geo in
            let side = geo.size.width
            PhotosPicker(selection: $newPhotoItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(theme.primaryLight)
                    if vm.isUploadingPhoto {
                        ProgressView().tint(theme.primary)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(theme.primary)
                    }
                }
                .frame(width: side, height: side)
            }
            .disabled(vm.isUploadingPhoto)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var storiesGrid: some View {
        Group {
            if vm.myStories.isEmpty {
                Text(lang[.profStoriesEmpty])
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                LazyVGrid(columns: gridCols, spacing: 8) {
                    ForEach(vm.myStories) { story in gridStoryCell(story) }
                }
            }
        }
    }

    private func gridStoryCell(_ story: DashStory) -> some View {
        Button {
            let myUser = DashUser(
                id: vm.me?.id ?? 0,
                profile: vm.me?.profile,
                main_photo: vm.me?.main_photo,
                photos: nil,
                subscription_type: vm.me?.subscription_type,
                is_online: vm.me?.is_online,
                last_seen: nil
            )
            storyItem = ProfileStoryPresentation(
                group: StoryGroup(id: myUser.id, user: myUser, stories: [story])
            )
        } label: {
            GeometryReader { geo in
                let side = geo.size.width
                Group {
                    if let url = story.mediaURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                theme.primaryLight
                            }
                        }
                    } else {
                        theme.primaryLight
                    }
                }
                .frame(width: side, height: side)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.primary.opacity(0.4), lineWidth: 1.5)
                )
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pastdagi to'liq kengliqdagi "Profilni tahrirlash" tugmasi

    private var bottomEditButton: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [theme.background.opacity(0), theme.background],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
                .allowsHitTesting(false)

            Button { showEdit = true } label: {
                Text(lang[.profEditTitle])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(theme.buttonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: theme.primary.opacity(0.35), radius: 12, y: 6)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .background(theme.background)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
