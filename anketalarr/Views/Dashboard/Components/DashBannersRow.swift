import SwiftUI
import Combine

struct DashBannersRow: View {
    let banners: [DashBanner]
    let screenWidth: CGFloat
    let onTap: (DashBanner) -> Void

    @EnvironmentObject var theme: AppTheme

    @State private var currentIndex = 0
    private let cardHeight: CGFloat = 160
    private var cardWidth: CGFloat { screenWidth - 48 }
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            if banners.isEmpty {
                // Skeleton
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.primaryLight)
                    .frame(width: cardWidth, height: cardHeight)
                    .overlay(
                        LinearGradient(colors: [.clear, theme.primary.opacity(0.08)],
                                       startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    )
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(banners.indices, id: \.self) { i in
                        BannerCard(
                            banner: banners[i],
                            width: cardWidth,
                            height: cardHeight,
                            theme: theme
                        ) { onTap(banners[i]) }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: screenWidth, height: cardHeight)
                .onReceive(timer) { _ in
                    guard banners.count > 1 else { return }
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentIndex = (currentIndex + 1) % banners.count
                    }
                }

                // Dot indicators
                HStack(spacing: 6) {
                    ForEach(banners.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentIndex ? theme.primary : theme.primary.opacity(0.3))
                            .frame(width: i == currentIndex ? 18 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
            }
        }
        .frame(height: banners.isEmpty ? cardHeight + 28 : cardHeight + 28)
        .padding(.top, 6)
    }
}

// MARK: - Single Banner Card

struct BannerCard: View {
    let banner: DashBanner
    let width: CGFloat
    let height: CGFloat
    let theme: AppTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                imageView
                    .frame(width: width, height: height)
                    .clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.72)],
                               startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 4) {
                    Text(banner.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white).lineLimit(2)
                    Text(banner.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85)).lineLimit(2)
                }
                .padding(14)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = banner.imageURL {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else { fallbackBg }
            }
        } else { fallbackBg }
    }

    private var fallbackBg: some View {
        LinearGradient(colors: [theme.primary.opacity(0.35), theme.primary.opacity(0.1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
