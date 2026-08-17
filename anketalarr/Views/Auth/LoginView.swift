import SwiftUI

struct LoginView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @StateObject private var vm = AuthViewModel()

    @State private var identifier = ""
    @State private var password   = ""
    @State private var showRegister = false
    @State private var showForgot   = false
    @State private var passwordVisible = false
    @State private var formOpacity: Double  = 0
    @State private var formOffset:  CGFloat = 40
    @FocusState private var focusedField: LoginField?

    private enum LoginField { case identifier, password }

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
                            identifierField
                            passwordField

                            HStack {
                                Spacer()
                                Button { showForgot = true } label: {
                                    Text(lang[.forgotPwd])
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(theme.primary)
                                }
                            }

                            PrimaryButton(title: lang[.loginBtn], isLoading: vm.isLoading) {
                                vm.login(identifier: normalizedIdentifier, password: password)
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

    private var identifierField: some View {
        HStack(spacing: 14) {
            Image(systemName: isPhoneIdentifier ? "phone" : "envelope")
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 22)

            TextField(lang[.emailPH], text: Binding(
                get: { identifier },
                set: { newValue in
                    let wasComplete = isPhoneComplete
                    identifier = Self.formatIdentifier(newValue)
                    if isPhoneComplete && !wasComplete {
                        DispatchQueue.main.async { focusedField = .password }
                    }
                }
            ))
            .keyboardType(isPhoneIdentifier ? .phonePad : .emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(isPhoneIdentifier ? .telephoneNumber : .username)
            .submitLabel(.next)
            .focused($focusedField, equals: .identifier)
            .onSubmit { focusedField = .password }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var passwordField: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock")
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 22)

            Group {
                if passwordVisible {
                    TextField(lang[.passwordPH], text: $password)
                } else {
                    SecureField(lang[.passwordPH], text: $password)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(.password)
            .submitLabel(.done)
            .focused($focusedField, equals: .password)
            .onSubmit {
                focusedField = nil
                vm.login(identifier: normalizedIdentifier, password: password)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { passwordVisible.toggle() }
            } label: {
                Image(systemName: passwordVisible ? "eye.slash" : "eye")
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var isPhoneIdentifier: Bool {
        identifier.hasPrefix("+998")
    }

    private var isPhoneComplete: Bool {
        isPhoneIdentifier && identifier.filter(\.isNumber).count == 12
    }

    private var normalizedIdentifier: String {
        isPhoneIdentifier ? identifier.replacingOccurrences(of: " ", with: "") : identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatIdentifier(_ input: String) -> String {
        guard input.hasPrefix("+") else { return input }
        let digits = String(input.filter(\.isNumber).prefix(12))
        guard !digits.isEmpty else { return "+" }
        guard "998".hasPrefix(digits) || digits.hasPrefix("998") else { return input }
        guard digits.count > 3 else { return "+\(digits)" }

        let local = String(digits.dropFirst(3))
        let groupSizes = [2, 3, 2, 2]
        var result = "+998"
        var index = local.startIndex
        for size in groupSizes where index < local.endIndex {
            let end = local.index(index, offsetBy: size, limitedBy: local.endIndex) ?? local.endIndex
            result += " " + String(local[index..<end])
            index = end
        }
        return result
    }
}

#Preview {
    LoginView()
        .environmentObject(AppTheme())
        .environmentObject(LocalizationManager())
}
