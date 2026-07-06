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
    @State private var slideOffset: CGFloat  = 60
    @State private var contentOpacity: Double = 0

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
            CustomTextField(icon: "envelope", placeholder: lang[.emailPH],
                            text: $identifier, keyboardType: .emailAddress)
            PrimaryButton(title: lang[.sendOTP], isLoading: vm.isLoading) {
                vm.sendOTP(identifier: identifier) {
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
            HStack {
                Text(lang[.noCode]).font(.system(size: 14)).foregroundColor(theme.textSecondary)
                Button { vm.sendOTP(identifier: identifier) } label: {
                    Text(lang[.resend])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            PrimaryButton(title: lang[.confirm], isLoading: vm.isLoading) {
                if otp.count == 6 { withAnimation(.spring()) { step = .password } }
                else { vm.errorMessage = lang[.errOTP] }
            }
            .disabled(otp.count < 6)
            .opacity(otp.count < 6 ? 0.6 : 1)
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
                        label: lang[.agreeTerms], linkText: lang[.termsLink], linkAction: {})
            PrimaryButton(title: lang[.regBtn], isLoading: vm.isLoading) {
                guard password == confirmPassword else { vm.errorMessage = lang[.errPwdMatch]; return }
                guard password.count >= 6        else { vm.errorMessage = lang[.errMinPwd];   return }
                guard agreedToTerms              else { vm.errorMessage = lang[.errTerms];    return }
                vm.register(identifier: identifier, otp: otp, password: password)
            }
        }
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
}

#Preview {
    NavigationStack { RegisterView() }
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
