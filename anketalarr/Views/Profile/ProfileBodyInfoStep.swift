import SwiftUI

// MARK: ─── 2. Bo'y va vazn ──────────────────────────────────────
struct ProfileBodyInfoStep: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    @Binding var heightVal: Int
    @Binding var weightVal: Int
    @Binding var showHeightSheet: Bool
    @Binding var showWeightSheet: Bool
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProfileStepHeader(title: lang[.psStep2],
                               subtitle: "(\(lang[.psOptional]))")

            // Bo'y
            VStack(alignment: .leading, spacing: 6) {
                Label(lang[.psHeight], systemImage: "arrow.up.and.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                Button { showHeightSheet = true } label: {
                    metricCard(value: heightVal, unit: "sm", color: theme.primary)
                }
            }

            // Vazn
            VStack(alignment: .leading, spacing: 6) {
                Label(lang[.psWeight], systemImage: "scalemass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                Button { showWeightSheet = true } label: {
                    metricCard(value: weightVal, unit: "kg", color: theme.primary.opacity(0.8))
                }
            }

            PrimaryButton(title: lang[.psContinue]) { onContinue() }

        }
    }

    private func metricCard(value: Int, unit: String, color: Color) -> some View {
        HStack {
            Text("\(value)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color.opacity(0.7))
                .padding(.top, 8)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(theme.primary.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: color.opacity(0.12), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}
