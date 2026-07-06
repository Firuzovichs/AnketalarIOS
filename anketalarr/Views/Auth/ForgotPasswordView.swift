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
            CustomTextField(icon: "envelope", placeholder: lang[.emailPH],
                            text: $identifier, keyboardType: .emailAddress)
            PrimaryButton(title: lang[.sendOTP], isLoading: vm.isLoading) {
                vm.requestPasswordReset(identifier: identifier) {
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
            HStack {
                Text(lang[.noCode]).font(.system(size: 14)).foregroundColor(theme.textSecondary)
                Button { vm.requestPasswordReset(identifier: identifier) {} } label: {
                    Text(lang[.resend])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            PrimaryButton(title: lang[.confirm], isLoading: vm.isLoading) {
                guard otp.count == 6 else { vm.errorMessage = lang[.errOTP]; return }
                withAnimation(.spring()) { step = .newPassword }
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
                guard newPassword.count >= 6  else { vm.errorMessage = lang[.errMinPwd];  return }
                guard newPassword == confirmPassword else { vm.errorMessage = lang[.errPwdMatch]; return }
                vm.confirmPasswordReset(identifier: identifier, otp: otp, newPassword: newPassword) {
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
}

#Preview {
    NavigationStack { ForgotPasswordView() }
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
