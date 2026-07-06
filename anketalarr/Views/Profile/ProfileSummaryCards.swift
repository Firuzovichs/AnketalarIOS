import SwiftUI

// MARK: - Profil tabidagi ikki ustunli xulosa kartalari
// Chap — profil to'ldirilganlik foizi (progress ring), o'ng — yuz tasdiqlanganlik holati.
// `completionPercent` — ProfileViewModel.profileCompletionPercent.
// `isVerified` — backend UserProfile.is_face_verified (haqiqiy holat, fake emas).

struct ProfileSummaryCardsRow: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    let completionPercent: Int
    let isVerified: Bool

    var body: some View {
        HStack(spacing: 12) {
            completionCard
            verifiedCard
        }
    }

    private var completionCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(theme.primary.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(completionPercent) / 100)
                    .stroke(theme.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: completionPercent)
                Text("\(completionPercent)%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(lang[.profCompletionTitle])
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang[.profCompletionSubtitle])
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private var verifiedCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isVerified ? Color.green.opacity(0.12) : theme.textSecondary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: isVerified ? "checkmark.shield.fill" : "shield.slash.fill")
                    .font(.system(size: 19))
                    .foregroundColor(isVerified ? .green : theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isVerified ? lang[.profVerifiedTitle] : lang[.profNotVerifiedTitle])
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(isVerified ? lang[.profVerifiedSubtitle] : lang[.profNotVerifiedSubtitle])
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}
