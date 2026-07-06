import SwiftUI

// MARK: - Custom TextField
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .none

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 22)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(
                    autocapitalization == .none ? .never : .words
                )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Secure TextField
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 22)

            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isVisible.toggle() }
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(theme.buttonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: theme.primary.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .disabled(isLoading)
    }
}

// MARK: - Checkbox Row
struct CheckboxRow: View {
    @Binding var isChecked: Bool
    let label: String
    var linkText: String? = nil
    var linkAction: (() -> Void)? = nil
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.2)) { isChecked.toggle() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isChecked ? theme.primary : Color.gray.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.primary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.8))

                if let link = linkText {
                    Button(action: { linkAction?() }) {
                        Text(link)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.primary)
                    }
                }
            }
        }
    }
}

// MARK: - OTP Field
struct OTPFieldView: View {
    @Binding var otp: String
    let length: Int = 6
    @EnvironmentObject var theme: AppTheme
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 1)
                .onChange(of: otp) { _, new in
                    if new.count > length { otp = String(new.prefix(length)) }
                    otp = new.filter { $0.isNumber }
                }

            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { i in
                    let char = i < otp.count ? String(otp[otp.index(otp.startIndex, offsetBy: i)]) : ""
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .frame(width: 46, height: 56)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        i == otp.count ? theme.primary : Color.gray.opacity(0.2),
                                        lineWidth: i == otp.count ? 2 : 1
                                    )
                            )
                        Text(char)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }
            .onTapGesture { isFocused = true }
        }
        .onAppear { isFocused = true }
    }
}
