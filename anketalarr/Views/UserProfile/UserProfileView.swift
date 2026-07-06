import SwiftUI

// Boshqa foydalanuvchining profili — O'zining Profil tabi (ProfileView.swift)
// bilan bir xil karta uslubida: Asosiy ma'lumotlar (jins/manzil/yosh), Bio,
// Qiziqishlar, Maqsadlar. Faqat o'qish uchun — Tahrirlash/Bio qo'shish kabi
// tugmalar yo'q.
//
// Agar joriy foydalanuvchi bu odamni avval like bosgan bo'lsa (checkLikeStatus
// orqali aniqlanadi), Like tugmasi o'rniga Bloklash + Chatga o'tish tugmalari
// ko'rsatiladi.

struct UserProfileView: View {
    let user: DashUser
    var onDismiss: (() -> Void)? = nil

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @StateObject private var vm = UserProfileViewModel()

    @State private var currentPhotoIndex: Int = 0
    @State private var showBlockReasonPicker = false

    private var photos: [DashPhoto] { user.sortedPhotos }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                theme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        photoGallery(geo: geo)
                        infoCards
                        Spacer().frame(height: 110)
                    }
                }

                // Fixed bottom action area
                actionArea
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
            }
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .topLeading) {
            backButton
                .padding(.top, 56)
                .padding(.leading, 20)
        }
        .task {
            await vm.checkLikeStatus(userId: user.id)
            await vm.fetchMyId()
        }
        .confirmationDialog(lang[.chatBlockReasonTitle], isPresented: $showBlockReasonPicker, titleVisibility: .visible) {
            Button(lang[.chatBlockReasonSpam]) { Task { await performBlock(reason: "spam") } }
            Button(lang[.chatBlockReasonHarassment]) { Task { await performBlock(reason: "harassment") } }
            Button(lang[.chatBlockReasonFakeProfile]) { Task { await performBlock(reason: "fake_profile") } }
            Button(lang[.chatBlockReasonInappropriate]) { Task { await performBlock(reason: "inappropriate") } }
            Button(lang[.chatBlockReasonOther]) { Task { await performBlock(reason: "other") } }
            Button(lang[.cancel], role: .cancel) {}
        } message: {
            Text(lang[.chatBlockConfirmBody])
        }
        .fullScreenCover(item: $vm.openRoom) { room in
            ChatConversationView(room: room, myId: vm.myId, onDismiss: { vm.openRoom = nil })
                .environmentObject(theme)
                .environmentObject(lang)
        }
        .toast($vm.errorMsg, isError: true)
        .toast($vm.infoMsg, isError: false)
    }

    // MARK: - Photo Gallery

    private func photoGallery(geo: GeometryProxy) -> some View {
        let h = geo.size.height * 0.58

        return ZStack(alignment: .bottom) {
            if photos.isEmpty {
                Rectangle()
                    .fill(theme.primaryLight)
                    .frame(height: h)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 72))
                            .foregroundColor(theme.primary.opacity(0.3))
                    )
            } else {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(photos.indices, id: \.self) { i in
                        AsyncImage(url: photos[i].photoURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .frame(width: geo.size.width, height: h)
                                    .clipped()
                            default:
                                Rectangle()
                                    .fill(theme.primaryLight)
                                    .frame(width: geo.size.width, height: h)
                                    .overlay(ProgressView())
                            }
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: h)

                // Dot indicators
                if photos.count > 1 {
                    dotIndicators
                        .padding(.bottom, 56)
                }
            }

            // Gradient overlay for name/age
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center, endPoint: .bottom
            )
            .frame(height: h * 0.5)

            // Name + age + online
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 10) {
                    Text(user.displayName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    if let age = user.age {
                        Text("\(age) \(lang[.upYears])")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    if user.is_online == true {
                        onlineBadge
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(height: h)
    }

    private var dotIndicators: some View {
        HStack(spacing: 5) {
            ForEach(photos.indices, id: \.self) { i in
                Capsule()
                    .fill(i == currentPhotoIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: i == currentPhotoIndex ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentPhotoIndex)
            }
        }
    }

    private var onlineBadge: some View {
        HStack(spacing: 5) {
            Circle().fill(Color.green).frame(width: 8, height: 8)
            Text(lang[.upOnline])
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.green.opacity(0.25))
        .clipShape(Capsule())
    }

    // MARK: - Info cards (ProfileView.swift bilan bir xil karta uslubi)

    private var infoCards: some View {
        VStack(spacing: 14) {
            basicInfoCard
            bioCard
            interestsCard(items: user.profile?.interests ?? [])
            goalsCard(items: user.profile?.goals ?? [])
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang[.profBasicInfoTitle])
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 0) {
                infoColumn(glyph: genderGlyph, title: lang[.profGenderLabel], value: genderText)
                Divider().frame(height: 38)
                infoColumn(icon: "mappin.and.ellipse", title: lang[.profAddressLabel], value: locationText)
                Divider().frame(height: 38)
                infoColumn(icon: "calendar", title: lang[.profAgeLabel], value: ageText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private func infoColumn(glyph: String? = nil, icon: String? = nil, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            if let glyph {
                Text(glyph)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.primary)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(theme.primary)
            }
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.profBioTitle])
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            if let bio = user.profile?.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(lang[.profBioEmpty])
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private func interestsCard(items: [DashInterest]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.profInterestsTitle])
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            if items.isEmpty {
                Text(lang[.profInterestsEmpty])
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(items) { item in
                        chip(icon: item.icon, text: item.localName(lang: lang))
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

    private func goalsCard(items: [DashGoal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.profGoalsTitle])
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            if items.isEmpty {
                Text(lang[.profGoalsEmpty])
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(items) { item in
                        chip(icon: item.icon, text: item.localName(lang: lang))
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

    private func chip(icon: String?, text: String) -> some View {
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

    // MARK: - Gender / Location / Age (boshqa odamning profile'idan, o'zinikidan emas)

    private var genderGlyph: String {
        switch user.profile?.gender {
        case "M": return "♂"
        case "F": return "♀"
        default:  return "•"
        }
    }

    private var genderText: String {
        switch user.profile?.gender {
        case "M": return lang[.psMale]
        case "F": return lang[.psFemale]
        default:  return lang[.profGenderUnset]
        }
    }

    private var locationText: String {
        guard let district = user.profile?.district else { return lang[.profLocationUnset] }
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
        guard let age = user.profile?.age else { return "—" }
        return "\(age) \(lang[.upYears])"
    }

    // MARK: - Bottom action area

    private var actionArea: some View {
        Group {
            if vm.isCheckingStatus {
                Color.clear.frame(height: 56)
            } else if vm.isLiked {
                HStack(spacing: 12) {
                    blockButton
                    chatButton
                }
            } else {
                likeButton
            }
        }
    }

    private var likeButton: some View {
        Button {
            Task { await vm.like(userId: user.id) }
        } label: {
            HStack(spacing: 10) {
                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "heart")
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(lang[.upLike])
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.red, theme.primary, Color.orange],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: theme.primary.opacity(0.4), radius: 12, x: 0, y: 4)
        }
        .disabled(vm.isLoading)
    }

    private var blockButton: some View {
        Button {
            showBlockReasonPicker = true
        } label: {
            HStack(spacing: 8) {
                if vm.isBlocking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.textPrimary))
                } else {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(lang[.chatMenuBlock])
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(theme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(theme.textSecondary.opacity(0.25), lineWidth: 1)
            )
        }
        .disabled(vm.isBlocking)
    }

    private var chatButton: some View {
        Button {
            Task { await vm.openChat() }
        } label: {
            HStack(spacing: 8) {
                if vm.isOpeningChat {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(lang[.upGoToChat])
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.red, theme.primary, Color.orange],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: theme.primary.opacity(0.4), radius: 12, x: 0, y: 4)
            .opacity(vm.chatRoomId == nil ? 0.5 : 1)
        }
        .disabled(vm.chatRoomId == nil || vm.isOpeningChat)
    }

    // MARK: - Block flow

    private func performBlock(reason: String) async {
        let ok = await vm.block(userId: user.id, reason: reason)
        if ok {
            vm.infoMsg = lang[.chatBlockDone]
            try? await Task.sleep(nanoseconds: 900_000_000)
            onDismiss?()
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            onDismiss?()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    let user = DashUser(
        id: 1,
        profile: DashProfile(
            first_name: "Laylo", last_name: "Karimova", patronymic: nil, birth_date: nil,
            age: 24, gender: "F", bio: nil,
            height: 165, weight: 55,
            interests: [DashInterest(id: 1, name: "Travel", name_uz: "Sayohat", name_ru: "Путешествия", icon: "✈️")],
            goals: [DashGoal(id: 1, name: "Relationship", name_uz: "Munosabat", name_ru: "Отношения", icon: "💑")],
            latitude: nil, longitude: nil, district: nil
        ),
        main_photo: nil, photos: nil,
        subscription_type: nil, is_online: true, last_seen: nil
    )
    UserProfileView(user: user)
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
