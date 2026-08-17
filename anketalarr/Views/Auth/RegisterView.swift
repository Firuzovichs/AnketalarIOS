import SwiftUI

// MARK: - Register bosqichlari
enum RegisterStep: Int, CaseIterable {
    case identifier = 0
    case otp        = 1
    case password   = 2
}

struct RegisterView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @StateObject private var vm = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var step: RegisterStep = .identifier
    @State private var identifier       = ""
    @State private var otp              = ""
    @State private var password         = ""
    @State private var confirmPassword  = ""
    @State private var agreedToTerms    = false
    @State private var showTerms        = false
    @State private var openedTerms      = false
    @State private var acceptedTermsVersion = ""
    @State private var otpExpiresAt      = Date.distantPast
    @State private var slideOffset: CGFloat  = 60
    @State private var contentOpacity: Double = 0

    private var remainingOtpSeconds: Int {
        max(0, Int(otpExpiresAt.timeIntervalSince(Date()).rounded(.up)))
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar — faqat orqaga va progress dots
                HStack {
                    Button {
                        if step == .identifier { dismiss() }
                        else { withAnimation(.spring()) { step = RegisterStep(rawValue: step.rawValue - 1)! } }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(RegisterStep.allCases, id: \.self) { s in
                            Capsule()
                                .fill(s.rawValue <= step.rawValue ? theme.primary : theme.primary.opacity(0.2))
                                .frame(width: s == step ? 28 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: step)
                        }
                    }

                    Spacer()
                    // Placeholder: SettingsBar tugmalari ustiga tushadi
                    Color.clear.frame(width: 88, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)

                LogoImageView(size: 110).padding(.bottom, 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        stepContent
                            .offset(y: slideOffset)
                            .opacity(contentOpacity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }

            // Orqaga tugma bor — ikkala tugma o'ngga siljiydi
            SettingsBar(hasBackButton: true)
        }
        .navigationBarHidden(true)
        .toast($vm.errorMessage)
        .onAppear { animateIn() }
        .onChange(of: step) { _, _ in
            slideOffset = 60; contentOpacity = 0
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
                slideOffset = 0; contentOpacity = 1
            }
        }
        .fullScreenCover(isPresented: $showTerms) {
            NavigationStack {
                StaticPageView(slug: "terms", acceptAction: { version in
                    openedTerms = true
                    agreedToTerms = true
                    acceptedTermsVersion = version
                    showTerms = false
                })
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showTerms = false } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                    }
            }
            .environmentObject(theme)
            .environmentObject(lang)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .identifier: identifierStep
        case .otp:        otpStep
        case .password:   passwordStep
        }
    }

    // MARK: - 1. Identifier
    private var identifierStep: some View {
        VStack(spacing: 20) {
            stepHeader(title: lang[.regTitle], subtitle: lang[.regSub])
            StrictRegisterIdentifierField(
                text: $identifier,
                placeholder: lang[.emailPH],
                isPhone: isPhoneIdentifier
            )
            PrimaryButton(title: lang[.sendOTP], isLoading: vm.isLoading) {
                guard isIdentifierValid else {
                    vm.errorMessage = isPhoneIdentifier ? "Telefon raqamni to‘g‘ri formatda kiriting: +998 99 000 00 00" : lang[.errIdentifier]
                    return
                }
                vm.sendOTP(identifier: normalizedIdentifier) {
                    otp = ""
                    startOtpTimer()
                    withAnimation(.spring()) { step = .otp }
                }
            }
            infoText(lang[.otpInfo])
        }
    }

    // MARK: - 2. OTP
    private var otpStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: lang[.codeTitle],
                       subtitle: String(format: lang[.codeSub], identifier))
            OTPFieldView(otp: $otp).frame(height: 60)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = max(0, Int(otpExpiresAt.timeIntervalSince(context.date).rounded(.up)))
                HStack {
                    Label("\(lang[.otpTimeLeft]): \(String(format: "%02d:%02d", seconds / 60, seconds % 60))",
                           systemImage: "timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(seconds == 0 ? .red : theme.primary)
                }
            }
            HStack {
                Text(lang[.noCode]).font(.system(size: 14)).foregroundColor(theme.textSecondary)
                Button {
                    vm.sendOTP(identifier: normalizedIdentifier) {
                        startOtpTimer()
                    }
                } label: {
                    Text(lang[.resend])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            PrimaryButton(title: lang[.confirm], isLoading: vm.isLoading) {
                if otp.count != 6 { vm.errorMessage = lang[.errOTP]; return }
                if remainingOtpSeconds <= 0 { vm.errorMessage = lang[.errOtpExpired]; return }
                vm.verifyOTP(identifier: normalizedIdentifier, otp: otp) {
                    withAnimation(.spring()) { step = .password }
                }
            }
            .disabled(otp.count < 6 || remainingOtpSeconds <= 0)
            .opacity(otp.count < 6 || remainingOtpSeconds <= 0 ? 0.6 : 1)
        }
    }

    // MARK: - 3. Parol
    private var passwordStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: lang[.setPwdTitle], subtitle: lang[.setPwdSub])
            CustomSecureField(icon: "lock",        placeholder: lang[.passwordPH],    text: $password)
            CustomSecureField(icon: "lock.shield",  placeholder: lang[.confirmPwdPH], text: $confirmPassword)
            if !password.isEmpty { passwordStrengthView }
            CheckboxRow(isChecked: $agreedToTerms,
                        label: lang[.agreeTerms],
                        linkText: lang[.termsLink],
                        isInteractive: openedTerms,
                        onBlockedTap: { vm.errorMessage = lang[.errTerms] },
                        linkAction: {
                            showTerms = true
                        })
            if !openedTerms {
                Text("Shartlarni o‘qib chiqqaningizdan so‘ng belgilang")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            PrimaryButton(title: lang[.regBtn], isLoading: vm.isLoading) {
                guard password == confirmPassword else { vm.errorMessage = lang[.errPwdMatch]; return }
                guard password.count >= 6        else { vm.errorMessage = lang[.errMinPwd];   return }
                guard openedTerms                else { vm.errorMessage = lang[.errTerms];    return }
                guard agreedToTerms              else { vm.errorMessage = lang[.errTerms];    return }
                vm.register(
                    identifier: normalizedIdentifier,
                    otp: otp,
                    password: password,
                    termsVersion: acceptedTermsVersion
                )
            }
            .disabled(!canProceedWithTerms || vm.isLoading)
            .opacity(canProceedWithTerms ? 1 : 0.55)
        }
    }

    private var canProceedWithTerms: Bool {
        password.count >= 6 && password == confirmPassword && agreedToTerms && openedTerms && !acceptedTermsVersion.isEmpty
    }

    // MARK: - Parol kuchi
    private var passwordStrengthView: some View {
        let s = strengthInfo(password)
        return HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < s.level ? s.color : Color.gray.opacity(0.2))
                    .frame(height: 5)
            }
            Text(s.label).font(.system(size: 11)).foregroundColor(s.color)
        }
    }

    private struct StrengthInfo { let level: Int; let label: String; let color: Color }

    private func strengthInfo(_ p: String) -> StrengthInfo {
        var score = 0
        if p.count >= 8 { score += 1 }
        if p.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if p.rangeOfCharacter(from: .decimalDigits)    != nil { score += 1 }
        if p.rangeOfCharacter(from: .symbols) != nil ||
           p.rangeOfCharacter(from: .punctuationCharacters) != nil { score += 1 }
        switch score {
        case 0, 1: return StrengthInfo(level: 1, label: lang[.weak],   color: .red)
        case 2:    return StrengthInfo(level: 2, label: lang[.medium], color: .orange)
        case 3:    return StrengthInfo(level: 3, label: lang[.good],   color: .yellow)
        default:   return StrengthInfo(level: 4, label: lang[.strong], color: .green)
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
        .padding(.bottom, 4)
    }

    private func errorText(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundColor(.red.opacity(0.8))
            .multilineTextAlignment(.center)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func infoText(_ text: String) -> some View {
        Label(text, systemImage: "info.circle").font(.system(size: 13))
            .foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
            slideOffset = 0; contentOpacity = 1
        }
    }

    private var isPhoneIdentifier: Bool {
        identifier.hasPrefix("+998")
    }

    private var normalizedIdentifier: String {
        isPhoneIdentifier
            ? identifier.replacingOccurrences(of: " ", with: "")
            : identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isIdentifierValid: Bool {
        if isPhoneIdentifier {
            return identifier
                .filter(\.isNumber)
                .count == 12
        }
        return !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startOtpTimer() {
        otpExpiresAt = Date().addingTimeInterval(5 * 60)
    }

}

/// Ro‘yxatdan o‘tish uchun qat’iy identifier maydoni.
/// Telefon rejimida kursorni oxirida ushlab turadi va 12 ta raqamdan
/// (`998` + 9 ta mahalliy raqam) ortig‘ini qabul qilmaydi.
private struct StrictRegisterIdentifierField: View {
    @Binding var text: String
    let placeholder: String
    let isPhone: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isPhone ? "phone" : "envelope")
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 22)
            StrictRegisterIdentifierTextField(
                text: $text,
                placeholder: placeholder,
                isPhone: isPhone
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private struct StrictRegisterIdentifierTextField: UIViewRepresentable {
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
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = placeholder
        let keyboard: UIKeyboardType = isPhone ? .phonePad : .emailAddress
        if field.keyboardType != keyboard {
            field.keyboardType = keyboard
            field.reloadInputViews()
        }
        if field.text != text { field.text = text }
        if isPhone { context.coordinator.moveCursorToEnd(field) }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: StrictRegisterIdentifierTextField

        init(_ parent: StrictRegisterIdentifierTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textField(
            _ field: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
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
            guard "998".hasPrefix(digits) || digits.hasPrefix("998") else {
                return String(input.prefix(13))
            }
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
    NavigationStack { RegisterView() }
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
