import SwiftUI

// MARK: - "Asosiy ma'lumotlar" kartasi
// 3 ustunli qator: Jins / Manzil / Yosh, yuqorida "Tahrirlash" link bilan.

struct ProfileBasicInfoCard: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    let genderGlyph: String
    let genderText: String
    let locationText: String
    let ageText: String
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(lang[.profBasicInfoTitle])
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(action: onEdit) {
                    Text(lang[.profEdit])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }

            HStack(spacing: 0) {
                column(glyph: genderGlyph, title: lang[.profGenderLabel], value: genderText)
                Divider().frame(height: 38)
                column(icon: "mappin.and.ellipse", title: lang[.profAddressLabel], value: locationText)
                Divider().frame(height: 38)
                column(icon: "calendar", title: lang[.profAgeLabel], value: ageText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private func column(glyph: String? = nil, icon: String? = nil, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            if let glyph {
                Text(glyph)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.primary)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(theme.primary)
            }
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}
