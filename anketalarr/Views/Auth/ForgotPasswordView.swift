import SwiftUI

enum ForgotStep { case phone, otp, newPassword, done }

struct ForgotPasswordView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AuthViewModel()

    @State private var step:            ForgotStep = .phone
    @State private var identifier       = ""
    @State private var otp              = ""
    @State private var newPassword      = ""
    @State private var confirmPassword  = ""
    @State private var slideOffset: CGFloat  = 50
    @State private var contentOpacity: Double = 0
    @State private var otpExpiresAt: Date = .distantPast

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            SettingsBar(hasBackButton: true)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    if step != .done {
                        Button {
                            withAnimation(.spring()) {
                                switch step {
                                case .phone:       dismiss()
                                case .otp:         step = .phone
                                case .newPassword: step = .otp
                                case .done:        break
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                    }
                    Spacer()
                    Text(lang[.resetTitle])
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Color.clear.frame(width: 88, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        stepContent
                            .offset(y: slideOffset)
                            .opacity(contentOpacity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .toast($vm.errorMessage)
        .onAppear { animateIn() }
        .onChange(of: step) { _, _ in
            slideOffset = 50; contentOpacity = 0
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
                slideOffset = 0; contentOpacity = 1
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .phone:       phoneStep
        case .otp:         otpStep
        case .newPassword: newPasswordStep
        case .done:        doneStep
        }
    }

    // MARK: - 1. Telefon
    private var phoneStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(theme.primaryLight).frame(width: 80, height: 80)
                Image(systemName: "lock.rotation").font(.system(size: 36)).foregroundColor(theme.primary)
            }
            stepHeader(title: lang[.resetTitle], subtitle: lang[.resetSub])
            StrictForgotIdentifierField(text: $identifier, placeholder: lang[.emailPH], isPhone: isPhoneIdentifier)
            PrimaryButton(title: lang[.sendOTP], isLoading: vm.isLoading) {
                vm.requestPasswordReset(identifier: normalizedIdentifier) {
                    startOtpTimer()
                    withAnimation(.spring()) { step = .otp }
                }
            }
        }
    }

    // MARK: - 2. OTP
    private var otpStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: lang[.codeTitle],
                       subtitle: String(format: lang[.codeSub], identifier))
            OTPFieldView(otp: $otp).frame(height: 60)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = remainingOtpSeconds(at: context.date)
                HStack(spacing: 7) {
                    Image(systemName: "timer")
                    Text("\(lang[.otpTimeLeft]): \(String(format: "%02d:%02d", seconds / 60, seconds % 60))")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(seconds == 0 ? .red : theme.primary)
            }
            HStack {
                Text(lang[.noCode]).font(.system(size: 14)).foregroundColor(theme.textSecondary)
                Button {
                    vm.requestPasswordReset(identifier: normalizedIdentifier) {
                        otp = ""
                        startOtpTimer()
                    }
                } label: {
                    Text(lang[.resend])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            PrimaryButton(title: lang[.confirm], isLoading: vm.isLoading) {
                guard otp.count == 6 else { vm.errorMessage = lang[.errOTP]; return }
                guard Date() < otpExpiresAt else { vm.errorMessage = lang[.errOtpExpired]; return }
                vm.verifyOTP(identifier: normalizedIdentifier, otp: otp) {
                    withAnimation(.spring()) { step = .newPassword }
                }
            }
            .disabled(otp.count < 6)
            .opacity(otp.count < 6 ? 0.6 : 1)
        }
    }

    // MARK: - 3. Yangi parol
    private var newPasswordStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: lang[.newPwdTitle], subtitle: lang[.newPwdSub])
            CustomSecureField(icon: "lock",        placeholder: lang[.newPwdPH],       text: $newPassword)
            CustomSecureField(icon: "lock.shield",  placeholder: lang[.confirmPwdPH],  text: $confirmPassword)
            PrimaryButton(title: lang[.save], isLoading: vm.isLoading) {
                guard Date() < otpExpiresAt else { vm.errorMessage = lang[.errOtpExpired]; return }
                guard newPassword.count >= 6  else { vm.errorMessage = lang[.errMinPwd];  return }
                guard newPassword == confirmPassword else { vm.errorMessage = lang[.errPwdMatch]; return }
                vm.confirmPasswordReset(identifier: normalizedIdentifier, otp: otp, newPassword: newPassword) {
                    withAnimation(.spring()) { step = .done }
                }
            }
        }
    }

    // MARK: - 4. Muvaffaqiyat
    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 24)
            ZStack {
                Circle().fill(Color.green.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56)).foregroundColor(.green)
            }
            Text(lang[.resetDone])
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(lang[.resetDoneSub])
                .font(.system(size: 15))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: lang[.goLogin]) { dismiss() }
        }
    }

    // MARK: - Helpers
    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 26, weight: .bold))
                .foregroundColor(theme.textPrimary).multilineTextAlignment(.center)
            Text(subtitle).font(.system(size: 15))
                .foregroundColor(theme.textSecondary).multilineTextAlignment(.center).lineSpacing(3)
        }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
            slideOffset = 0; contentOpacity = 1
        }
    }

    private func startOtpTimer() {
        otpExpiresAt = Date().addingTimeInterval(5 * 60)
    }

    private func remainingOtpSeconds(at date: Date) -> Int {
        max(0, Int(ceil(otpExpiresAt.timeIntervalSince(date))))
    }

    private var isPhoneIdentifier: Bool {
        identifier.hasPrefix("+998")
    }

    private var normalizedIdentifier: String {
        isPhoneIdentifier
            ? identifier.replacingOccurrences(of: " ", with: "")
            : identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

private struct StrictForgotIdentifierField: View {
    @Binding var text: String
    let placeholder: String
    let isPhone: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isPhone ? "phone" : "envelope")
                .foregroundColor(.gray.opacity(0.6)).frame(width: 22)
            StrictForgotIdentifierTextField(text: $text, placeholder: placeholder, isPhone: isPhone)
        }
        .padding(.horizontal, 18).padding(.vertical, 18)
        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private struct StrictForgotIdentifierTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isPhone: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16)
        field.textColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1)
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = placeholder
        let keyboard: UIKeyboardType = isPhone ? .phonePad : .emailAddress
        if field.keyboardType != keyboard { field.keyboardType = keyboard; field.reloadInputViews() }
        if field.text != text { field.text = text }
        if isPhone { context.coordinator.moveCursorToEnd(field) }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: StrictForgotIdentifierTextField
        init(_ parent: StrictForgotIdentifierTextField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) { parent.text = field.text ?? "" }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = field.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            let candidate = current.replacingCharacters(in: swiftRange, with: string)
            guard candidate.hasPrefix("+") else { return true }
            let formatted = Self.formatUzPhone(candidate)
            field.text = formatted
            parent.text = formatted
            moveCursorToEnd(field)
            return false
        }

        func moveCursorToEnd(_ field: UITextField) {
            let end = field.endOfDocument
            field.selectedTextRange = field.textRange(from: end, to: end)
        }

        private static func formatUzPhone(_ input: String) -> String {
            let digits = String(input.filter(\.isNumber).prefix(12))
            guard !digits.isEmpty else { return "+" }
            guard "998".hasPrefix(digits) || digits.hasPrefix("998") else { return input }
            guard digits.count > 3 else { return "+\(digits)" }
            let local = String(digits.dropFirst(3))
            var result = "+998"
            var index = local.startIndex
            for size in [2, 3, 2, 2] where index < local.endIndex {
                let end = local.index(index, offsetBy: size, limitedBy: local.endIndex) ?? local.endIndex
                result += " " + String(local[index..<end])
                index = end
            }
            return result
        }
    }
}

#Preview {
    NavigationStack { ForgotPasswordView() }
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
