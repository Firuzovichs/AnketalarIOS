import SwiftUI

// MARK: - Generic bottom-sheet overlay

struct DetailOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) { isPresented = false }
                }

            content()
                // MainTabView pastki tab bar'ni alohida overlay sifatida
                // (GeometryReader orqali to'liq ekran balandligida) chizadi —
                // bu safe area emas, shunchaki ustiga chiziladigan qattiq
                // balandlik (56 + 28 = 84pt). Shuning uchun bu yerda kamida
                // shuncha bo'sh joy qoldirmasak, sheet ichidagi pastki
                // tugmalar (masalan Tozalash/Qo'llash) tab bar ostida
                // ko'rinmay qolardi.
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .transition(.opacity)
    }
}

// MARK: - Banner detail

struct BannerBottomSheetOverlay: View {
    let banner: DashBanner
    var onDismiss: () -> Void

    @EnvironmentObject var theme: AppTheme
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }

                BannerDetailCard(banner: banner, onClose: onDismiss)
                    .frame(width: geo.size.width)
                    .frame(height: geo.size.height * 0.47)
                    .background(theme.background)
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: 28,
                                bottomLeading: 0,
                                bottomTrailing: 0,
                                topTrailing: 28
                            )
                        )
                    )
                    .shadow(color: .black.opacity(0.22), radius: 24, y: -5)
                    .offset(y: max(0, dragOffset))
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 || value.predictedEndTranslation.height > 180 {
                                    onDismiss()
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
}

struct BannerDetailCard: View {
    let banner: DashBanner
    var onClose: () -> Void
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(theme.textSecondary.opacity(0.22))
                .frame(width: 42, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Batafsil")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text("Maxsus taklif")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.primary)
                        .frame(width: 38, height: 38)
                        .background(theme.primary.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        if let url = banner.imageURL {
                            AsyncImage(url: url) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFill()
                                } else {
                                    LinearGradient(
                                        colors: [theme.primary, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        } else {
                            LinearGradient(
                                colors: [theme.primary, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.58)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        Text("ANKETALAR.UZ")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))
                            .padding(16)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 4)

                    Text(banner.title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.top, 20)

                    if !banner.description.isEmpty {
                        Text(banner.description)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textSecondary)
                            .lineSpacing(5)
                            .padding(.top, 8)
                    }

                    if let link = banner.link_url, let url = URL(string: link), !link.isEmpty {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Text("Batafsil ko‘rish")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(theme.buttonGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.top, 22)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.background)
    }
}

// MARK: - News detail

struct NewsBottomSheetOverlay: View {
    let news: DashNews
    var onDismiss: () -> Void

    @EnvironmentObject var theme: AppTheme
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }

                NewsDetailCard(news: news, onClose: onDismiss)
                    .frame(width: geo.size.width)
                    .frame(height: geo.size.height * 0.47)
                    .background(theme.background)
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: 28,
                                bottomLeading: 0,
                                bottomTrailing: 0,
                                topTrailing: 28
                            )
                        )
                    )
                    .shadow(color: .black.opacity(0.22), radius: 24, y: -5)
                    .offset(y: max(0, dragOffset))
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 || value.predictedEndTranslation.height > 180 {
                                    onDismiss()
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
}

struct NewsDetailCard: View {
    let news: DashNews
    var onClose: () -> Void
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(theme.textSecondary.opacity(0.22))
                .frame(width: 42, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yangiliklar")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text(news.formattedDate.isEmpty ? "So‘nggi yangilik" : news.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.primary)
                        .frame(width: 38, height: 38)
                        .background(theme.primary.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        if let url = news.imageURL {
                            AsyncImage(url: url) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFill()
                                } else {
                                    LinearGradient(
                                        colors: [theme.primary, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        } else {
                            LinearGradient(
                                colors: [theme.primary, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.58)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        Text("ANKETALAR.UZ")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))
                            .padding(16)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 4)

                    if !news.formattedDate.isEmpty {
                        Text(news.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary.opacity(0.72))
                            .padding(.top, 18)
                    }

                    Text(news.title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.top, 6)

                    Text(news.content ?? news.description)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textSecondary)
                        .lineSpacing(5)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.background)
    }
}
