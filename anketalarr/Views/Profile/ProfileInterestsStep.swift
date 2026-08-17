import SwiftUI

// MARK: ─── 3. Qiziqishlar ───────────────────────────────────────
struct ProfileInterestsStep: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @ObservedObject var vm: AuthViewModel

    @Binding var selectedInterestIds: Set<Int>
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProfileStepHeader(title: lang[.psStep3], subtitle: lang[.psSelectInterests])

            if vm.interests.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().tint(theme.primary).scaleEffect(1.3)
                    Text(lang[.psLoading])
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ChipGrid(
                    items: vm.interests.map { ($0.id, $0.displayName(lang: lang.language.rawValue), $0.icon) },
                    selected: $selectedInterestIds
                )
            }

            PrimaryButton(title: lang[.psContinue]) { onContinue() }
        }
    }
}
