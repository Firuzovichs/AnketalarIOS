import SwiftUI

struct NotificationsPage: View {
    @StateObject private var vm = NotificationsViewModel()
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    private var hasUnread: Bool {
        vm.notifications.contains { $0.is_read == false }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                content
            }
        }
        .onAppear {
            vm.load()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
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

            Button {
                vm.markAllRead()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(hasUnread ? theme.primary : theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .disabled(!hasUnread)
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(
            theme.background
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
                LazyVStack(spacing: 12) {
                    ForEach(vm.notifications) { item in
                        NotifRow(item: item, theme: theme) {
                            if item.is_read == false {
                                vm.markRead(item.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
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
    let onTap: () -> Void

    private var isUnread: Bool {
        item.is_read == false
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    Circle()
                        .fill(item.iconColor.opacity(0.14))
                        .frame(width: 48, height: 48)

                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(item.iconColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let title = item.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 14, weight: isUnread ? .semibold : .medium))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(2)
                    }

                    if let msg = item.message, !msg.isEmpty {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(3)
                    }

                    Text(item.formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary.opacity(0.6))
                }

                Spacer()

                if isUnread {
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 9, height: 9)
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(isUnread ? theme.primary.opacity(0.06) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isUnread ? theme.primary.opacity(0.16) : theme.textSecondary.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
