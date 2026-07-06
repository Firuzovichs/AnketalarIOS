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

struct BannerDetailCard: View {
    let banner: DashBanner
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let url = banner.imageURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 200).clipped()
                        } else {
                            Rectangle().fill(theme.primaryLight).frame(height: 130)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.bottom, 16)
                } else {
                    Rectangle().fill(theme.primaryLight).frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20)).padding(.bottom, 16)
                }

                Text(banner.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.bottom, 8)

                Text(banner.description)
                    .font(.system(size: 15))
                    .foregroundColor(theme.textSecondary)
                    .lineSpacing(4)

                if let link = banner.link_url, let url = URL(string: link), !link.isEmpty {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                            Text("Batafsil")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primary)
                    }
                    .padding(.top, 12)
                }
            }
            .padding(20)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.65)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: -4)
        .padding(.horizontal, 16)
    }
}

// MARK: - News detail

struct NewsDetailCard: View {
    let news: DashNews
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let url = news.imageURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 180).clipped()
                        } else {
                            Rectangle().fill(theme.primaryLight).frame(height: 100)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.bottom, 14)
                }

                if !news.formattedDate.isEmpty {
                    Text(news.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary.opacity(0.65))
                        .padding(.bottom, 6)
                }

                Text(news.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.bottom, 8)

                Text(news.content ?? news.description)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .lineSpacing(5)
            }
            .padding(20)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.68)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: -4)
        .padding(.horizontal, 16)
    }
}
