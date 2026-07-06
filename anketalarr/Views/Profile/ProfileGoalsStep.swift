import SwiftUI

// MARK: ─── 4. Maqsadlar ─────────────────────────────────────────
struct ProfileGoalsStep: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @ObservedObject var vm: AuthViewModel

    @Binding var selectedGoalIds: Set<Int>
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProfileStepHeader(title: lang[.psStep4], subtitle: lang[.psSelectGoals])

            if vm.goals.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().tint(theme.primary).scaleEffect(1.3)
                    Text(lang[.psLoading]).font(.system(size: 14)).foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ChipGrid(
                    items: vm.goals.map { ($0.id, $0.displayName(lang: lang.language.rawValue), $0.icon) },
                    selected: $selectedGoalIds
                )
            }

            PrimaryButton(title: lang[.psContinue], isLoading: vm.isLoading) { onContinue() }
            ProfileSkipButton(action: onSkip)
        }
    }
}
