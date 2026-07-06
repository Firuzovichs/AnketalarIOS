import SwiftUI

struct NotificationsPage: View {
    @StateObject private var vm = NotificationsViewModel()
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider()
                content
            }
        }
        .onAppear { vm.load() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("Bildirishnomalar")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(theme.textPrimary)

            Spacer()

            // Mark all read
            Button {
                vm.markAllRead()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(
                        vm.notifications.contains { $0.is_read == false }
                        ? theme.primary : Color.clear
                    )
                    .frame(width: 44, height: 44)
            }
            .disabled(!vm.notifications.contains { $0.is_read == false })
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
        .background(
            theme.background
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.notifications.isEmpty {
            Spacer()
            ProgressView().tint(theme.primary)
            Spacer()
        } else if vm.notifications.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(vm.notifications) { item in
                        NotifRow(item: item, theme: theme)
                            .onTapGesture {
                                if item.is_read == false { vm.markRead(item.id) }
                            }
                        Divider().padding(.leading, 72)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 56))
                .foregroundColor(theme.textSecondary.opacity(0.25))
            Text("Hozircha bildirishnoma yo'q")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Row

struct NotifRow: View {
    let item: AppNotification
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 14) {
            // Avatar or icon
            ZStack {
                Circle()
                    .fill(item.iconColor.opacity(0.13))
                    .frame(width: 50, height: 50)

                if let url = item.actorPhotoURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } else { defaultIcon }
                    }
                } else { defaultIcon }

                // Type badge bottom-right
                ZStack {
                    Circle().fill(item.iconColor).frame(width: 20, height: 20)
                    Image(systemName: item.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 17, y: 17)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 14, weight: item.is_read == false ? .semibold : .regular))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                if let msg = item.message, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
                Text(item.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary.opacity(0.5))
            }

            Spacer()

            if item.is_read == false {
                Circle()
                    .fill(theme.primary)
                    .frame(width: 9, height: 9)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            item.is_read == false
            ? theme.primary.opacity(0.05)
            : Color.clear
        )
    }

    private var defaultIcon: some View {
        Image(systemName: item.icon)
            .font(.system(size: 20))
            .foregroundColor(item.iconColor)
    }
}
