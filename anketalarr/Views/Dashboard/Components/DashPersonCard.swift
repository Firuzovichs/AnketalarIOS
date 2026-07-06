import SwiftUI

// Fixed card dimensions — identical for every card
private let kPhotoHeight: CGFloat = 200

struct DashPersonCard: View {
    let user: DashUser
    let cardWidth: CGFloat
    let viewerIsVip: Bool           // current logged-in user's VIP status

    @EnvironmentObject var theme: AppTheme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // ── Photo background — blurred if viewer is not VIP ─────────
            photoBackground
                .frame(width: cardWidth, height: kPhotoHeight)
                .blur(radius: viewerIsVip ? 0 : 8)
                .clipped()
                .overlay(Color.black.opacity(viewerIsVip ? 0.22 : 0.15))

            // ── VIP lock badge ───────────────────────────────────────────
            if !viewerIsVip {
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.85))
                    Text("VIP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                }
                .frame(width: cardWidth, height: kPhotoHeight)
            }

            // ── Bottom gradient ──────────────────────────────────────────
            LinearGradient(
                colors: [.clear, .black.opacity(user.isPremium ? 0.68 : 0.55)],
                startPoint: .center, endPoint: .bottom
            )
            .frame(width: cardWidth, height: kPhotoHeight)

            // ── Name + age ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if user.isPremium {   // card person's crown badge (stays)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                    Text(user.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                if let age = user.age {
                    Text("\(age) yosh")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(10)

            // ── Online dot (top-right) ───────────────────────────────────
            if user.is_online == true {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .padding(10)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: cardWidth, height: kPhotoHeight)   // locked size
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var photoBackground: some View {
        if let url = user.photoURL {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: kPhotoHeight)
                        .clipped()
                } else {
                    placeholderBox
                }
            }
        } else {
            placeholderBox
        }
    }

    private var placeholderBox: some View {
        ZStack {
            LinearGradient(
                colors: [theme.primary.opacity(0.3), theme.primary.opacity(0.08)],
                startPoint: .top, endPoint: .bottom
            )
            Image(systemName: "person.fill")
                .font(.system(size: 44))
                .foregroundColor(theme.primary.opacity(0.35))
        }
        .frame(width: cardWidth, height: kPhotoHeight)
    }
}

// MARK: - News snippet row (shown between grid rows)

struct DashNewsSnippet: View {
    let news: DashNews
    let onTap: () -> Void

    @EnvironmentObject var theme: AppTheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 13))
                    .foregroundColor(theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(news.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text(news.description)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary.opacity(0.4))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(theme.primaryLight.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
