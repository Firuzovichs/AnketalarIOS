import SwiftUI

/// Faqat top bar satrini ko'rsatadi — oddiy o'lchamli view.
/// Dropdown state DashboardView darajasida boshqariladi.
struct DashTopBar: View {
    let me: DashMe?
    let unreadCount: Int
    let onSettingsTap: () -> Void
    let onBellTap: () -> Void

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager

    static let barHeight: CGFloat = 64

    var body: some View {
        HStack(spacing: 12) {
            avatarAndName
            Spacer()
            rightButtons
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: Self.barHeight)
        .background(
            theme.background
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Avatar + Name

    private var avatarAndName: some View {
        HStack(spacing: 10) {
            avatarCircle
            VStack(alignment: .leading, spacing: 1) {
                Text(lang[.dbHello])
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                Text(me?.profile?.first_name ?? lang[.dbUser])
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    private var avatarCircle: some View {
        let size: CGFloat = 42
        return ZStack {
            Circle().fill(theme.primaryLight).frame(width: size, height: size)
            if let url = me?.main_photo?.image.flatMap({ URL(string: $0) }) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                            .frame(width: size, height: size).clipShape(Circle())
                    } else { defaultIcon(size: size) }
                }
            } else { defaultIcon(size: size) }
        }
        .overlay(Circle().stroke(theme.primary.opacity(0.25), lineWidth: 2))
    }

    private func defaultIcon(size: CGFloat) -> some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.44))
            .foregroundColor(theme.primary)
    }

    // MARK: - Right buttons

    private var rightButtons: some View {
        HStack(spacing: 8) {
            // Settings
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.primary)
                    .frame(width: 38, height: 38)
                    .background(theme.primaryLight)
                    .clipShape(Circle())
            }
            // Notification bell
            Button(action: onBellTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primary)
                        .frame(width: 38, height: 38)
                        .background(theme.primaryLight)
                        .clipShape(Circle())
                    if unreadCount > 0 {
                        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
    }
}
