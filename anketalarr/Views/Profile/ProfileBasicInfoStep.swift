import SwiftUI

// MARK: ─── 1. Shaxsiy ma'lumot ───────────────────────────────────
struct ProfileBasicInfoStep: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @ObservedObject var vm: AuthViewModel

    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var patronymic: String
    @Binding var birthDate: Date
    @Binding var gender: String
    @Binding var showDateSheet: Bool
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProfileStepHeader(title: lang[.psStep1])

            CustomTextField(icon: "person",      placeholder: lang[.psFirstName],  text: $firstName)
            CustomTextField(icon: "person",      placeholder: lang[.psLastName],   text: $lastName)
            CustomTextField(icon: "person.fill", placeholder: "\(lang[.psPatronymic]) (\(lang[.psOptional]))",
                            text: $patronymic)

            // Tug'ilgan sana — creative card
            VStack(alignment: .leading, spacing: 6) {
                Label(lang[.psBirthDate], systemImage: "calendar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                Button { showDateSheet = true } label: {
                    HStack {
                        Text(formatDateDisplay(birthDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: theme.primary.opacity(0.12), radius: 8, x: 0, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.primary.opacity(0.25), lineWidth: 1)
                    )
                }
            }

            // Jins
            VStack(alignment: .leading, spacing: 8) {
                Label(lang[.psGender], systemImage: "person.2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                HStack(spacing: 12) {
                    genderButton("M", label: lang[.psMale],   icon: "♂")
                    genderButton("F", label: lang[.psFemale], icon: "♀")
                }
            }

            PrimaryButton(title: lang[.psContinue]) {
                guard !firstName.isEmpty, !lastName.isEmpty, !gender.isEmpty else {
                    vm.errorMessage = lang[.errFillRequired]; return
                }
                vm.errorMessage = nil
                onContinue()
            }
        }
    }

    private func genderButton(_ value: String, label: String, icon: String) -> some View {
        let sel = gender == value
        return Button { withAnimation(.spring(response: 0.25)) { gender = value } } label: {
            VStack(spacing: 6) {
                Text(icon).font(.system(size: 28))
                Text(label)
                    .font(.system(size: 14, weight: sel ? .semibold : .regular))
                    .foregroundColor(sel ? .white : theme.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(sel ? theme.primary : theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(sel ? theme.primary : theme.primary.opacity(0.3), lineWidth: 1.5)
            )
            .scaleEffect(sel ? 1.02 : 1)
        }
    }

    private func formatDateDisplay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: lang.language == .ru ? "ru_RU" : lang.language == .en ? "en_US" : "uz_UZ")
        return f.string(from: date)
    }
}
