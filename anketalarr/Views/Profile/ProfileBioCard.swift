import SwiftUI

// MARK: - Bio kartasi
// Bio mavjud bo'lsa — matn ko'rinadi. Bo'lmasa — boy empty-state CTA
// (ikonka + sarlavha + tushuntirish + "Bio qo'shish" tugmasi).

struct ProfileBioCard: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    let bio: String?
    var onAddBio: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang[.profBioTitle])
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            if let bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                emptyState
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(theme.primaryLight).frame(width: 48, height: 48)
                Image(systemName: "pencil")
                    .font(.system(size: 19))
                    .foregroundColor(theme.primary)
            }
            Text(lang[.profBioEmptyTitle])
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(lang[.profBioEmptySubtitle])
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAddBio) {
                Text(lang[.profAddBioButton])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(theme.buttonGradient)
                    .clipShape(Capsule())
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
