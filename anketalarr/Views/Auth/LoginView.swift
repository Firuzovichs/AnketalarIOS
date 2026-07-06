import SwiftUI

struct LoginView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @StateObject private var vm = AuthViewModel()

    @State private var identifier = ""
    @State private var password   = ""
    @State private var showRegister = false
    @State private var showForgot   = false
    @State private var formOpacity: Double  = 0
    @State private var formOffset:  CGFloat = 40

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 60)

                        LogoImageView(size: 120)
                            .padding(.bottom, 32)

                        VStack(spacing: 8) {
                            Text(lang[.welcome])
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                            Text(lang[.loginSub])
                                .font(.system(size: 15))
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.bottom, 36)

                        VStack(spacing: 14) {
                            CustomTextField(
                                icon: "envelope",
                                placeholder: lang[.emailPH],
                                text: $identifier,
                                keyboardType: .emailAddress
                            )
                            CustomSecureField(
                                icon: "lock",
                                placeholder: lang[.passwordPH],
                                text: $password
                            )

                            HStack {
                                Spacer()
                                Button { showForgot = true } label: {
                                    Text(lang[.forgotPwd])
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(theme.primary)
                                }
                            }

                            PrimaryButton(title: lang[.loginBtn], isLoading: vm.isLoading) {
                                vm.login(identifier: identifier, password: password)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 24)
                        .opacity(formOpacity)
                        .offset(y: formOffset)

                        Spacer().frame(height: 48)

                        HStack(spacing: 6) {
                            Text(lang[.noAccount])
                                .font(.system(size: 15))
                                .foregroundColor(theme.textSecondary)
                            Button { showRegister = true } label: {
                                Text(lang[.signUp])
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(theme.primary)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(.keyboard)

                SettingsBar()
            }
            .toast($vm.errorMessage)
            .navigationDestination(isPresented: $showRegister) { RegisterView() }
            .navigationDestination(isPresented: $showForgot)   { ForgotPasswordView() }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    formOpacity = 1; formOffset = 0
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
