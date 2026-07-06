import SwiftUI

/// Tinder-uslubidagi bitta surilib ketuvchi karta — surganda LIKE/NOPE belgisi chiqadi,
/// chap/o'ng surilganda kartaning o'zi ekrandan uchib ketadi.
struct SwipeCardView: View {
    enum SwipeDirection: Equatable { case like, skip }

    let user: DashUser
    var isInteractive: Bool = true
    @Binding var triggerDirection: SwipeDirection?
    var onSwipe: ((SwipeDirection) -> Void)? = nil
    /// Rasm ustiga (o'rta qismiga) yoki ⓘ belgisiga bosilganda chaqiriladi —
    /// LikeTabView shu orqali ushbu odamning TO'LIQ profilini (UserProfileView)
    /// ochadi ("rasm ustiga bosilganda ma'lumotlar ko'rinsin" talabi).
    var onShowInfo: (() -> Void)? = nil

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    @State private var offset: CGSize = .zero
    @State private var photoIndex = 0
    @State private var cardWidth: CGFloat = 0

    private var photos: [DashPhoto] { user.sortedPhotos }
    private var rotation: Double { Double(offset.width) / 16.0 }
    private var likeOpacity: Double {
        let raw: Double = Double(offset.width) / 110.0
        return min(max(raw, 0.0), 1.0)
    }
    private var nopeOpacity: Double {
        let raw: Double = Double(-offset.width) / 110.0
        return min(max(raw, 0.0), 1.0)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                photoLayer(geo: geo)
                photoDots
                gradientAndInfo
                stamps
                infoHint
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
            .offset(offset)
            .rotationEffect(.degrees(isInteractive ? rotation : 0), anchor: .bottom)
            .scaleEffect(isInteractive ? 1 : 0.93)
            .onAppear { cardWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, newValue in cardWidth = newValue }
        }
        .modifier(DragModifier(isInteractive: isInteractive, offset: $offset, onEnded: handleDragEnd))
        .onChange(of: triggerDirection) { _, newValue in
            guard isInteractive, let newValue else { return }
            swipeAway(direction: newValue)
        }
    }

    // MARK: - Layers

    private func photoLayer(geo: GeometryProxy) -> some View {
        ZStack {
            if photos.isEmpty {
                Rectangle()
                    .fill(theme.primaryLight)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(theme.primary.opacity(0.3))
                    )
            } else {
                AsyncImage(url: photos[min(photoIndex, photos.count - 1)].photoURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(theme.primaryLight).overlay(ProgressView())
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // Rasm ustidagi bosish zonalari. Bir nechta surat bo'lsa:
                // chap/o'ng QIRRALAR — suratlar orasida o'tish (eski xatti-
                // harakat saqlanadi), O'RTADAGI keng zona — shu odam haqida
                // TO'LIQ ma'lumotni ochish (onShowInfo). Faqat bitta surat
                // bo'lsa, butun rasm shu maqsadda ishlaydi.
                if photos.count > 1 {
                    let edge = geo.size.width * 0.24
                    HStack(spacing: 0) {
                        Color.clear.contentShape(Rectangle())
                            .frame(width: edge)
                            .onTapGesture { changePhoto(by: -1) }
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { onShowInfo?() }
                        Color.clear.contentShape(Rectangle())
                            .frame(width: edge)
                            .onTapGesture { changePhoto(by: 1) }
                    }
                } else {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { onShowInfo?() }
                }
            }
        }
    }

    private var photoDots: some View {
        Group {
            if photos.count > 1 {
                HStack(spacing: 4) {
                    ForEach(photos.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == photoIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
            }
        }
    }

    /// O'ng-yuqori burchakdagi kichik ⓘ belgisi — foydalanuvchi rasm ustiga
    /// bosish orqali ham, shu aniq belgini bosish orqali ham profil haqida
    /// to'liq ma'lumotni ochishi mumkinligini ko'rsatib turadi.
    private var infoHint: some View {
        HStack {
            Spacer()
            ZStack {
                Circle().fill(Color.black.opacity(0.32)).frame(width: 30, height: 30)
                Image(systemName: "info")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .contentShape(Rectangle())
            .onTapGesture { onShowInfo?() }
        }
        .padding(.top, 26)
        .padding(.trailing, 14)
    }

    private var gradientAndInfo: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                    .frame(height: 170)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(user.displayName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        if let age = user.age {
                            Text("\(age)")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        if user.is_online == true {
                            Circle().fill(Color.green).frame(width: 10, height: 10)
                        }
                    }
                    if let districtName = user.profile?.district?.name_uz ?? user.profile?.district?.name {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
                            Text(districtName).font(.system(size: 13))
                        }
                        .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }

    private var stamps: some View {
        ZStack {
            stampLabel(text: lang[.likeStampLike], color: .green, rotation: -16)
                .opacity(likeOpacity)
                .padding(.top, 50)
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            stampLabel(text: lang[.likeStampNope], color: .red, rotation: 16)
                .opacity(nopeOpacity)
                .padding(.top, 50)
                .padding(.trailing, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func stampLabel(text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(rotation))
    }

    // MARK: - Gestures

    private func changePhoto(by delta: Int) {
        guard photos.count > 1 else { return }
        photoIndex = max(0, min(photos.count - 1, photoIndex + delta))
    }

    private func handleDragEnd(_ translation: CGSize) {
        let threshold: CGFloat = 110
        if translation.width > threshold {
            swipeAway(direction: .like)
        } else if translation.width < -threshold {
            swipeAway(direction: .skip)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offset = .zero }
        }
    }

    private func swipeAway(direction: SwipeDirection) {
        let width = cardWidth > 0 ? cardWidth : 400
        let endX: CGFloat = direction == .like ? width * 1.6 : -width * 1.6
        withAnimation(.easeOut(duration: 0.32)) {
            offset = CGSize(width: endX, height: offset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onSwipe?(direction)
        }
    }
}

/// Faqat tepadagi (interactive) kartaga drag gesture biriktiradi —
/// orqadagi "peek" karta uchun hech narsa qo'shmaydi.
private struct DragModifier: ViewModifier {
    let isInteractive: Bool
    @Binding var offset: CGSize
    let onEnded: (CGSize) -> Void

    func body(content: Content) -> some View {
        if isInteractive {
            content.gesture(
                DragGesture()
                    .onChanged { value in offset = value.translation }
                    .onEnded { value in onEnded(value.translation) }
            )
        } else {
            content
        }
    }
}
