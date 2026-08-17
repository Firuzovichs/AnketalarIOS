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
    var isInteractive: Bool = true
    var onBlockedTap: (() -> Void)? = nil
    var linkAction: (() -> Void)? = nil
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                if isInteractive {
                    withAnimation(.spring(response: 0.2)) { isChecked.toggle() }
                } else {
                    onBlockedTap?()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isChecked ? theme.primary.opacity(0.10) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isChecked ? theme.primary : Color.gray.opacity(0.4), lineWidth: 1.4)
                        )
                        .frame(width: 22, height: 22)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.primary)
                    } else if !isInteractive {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.textSecondary.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textPrimary.opacity(0.85))
                    .multilineTextAlignment(.leading)

                if let link = linkText {
                    Button(action: { linkAction?() }) {
                        Text(link)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)
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
    @State private var selectedIndex = 0

    var body: some View {
        ZStack {
            OTPTextFieldBridge(otp: $otp, selectedIndex: $selectedIndex, length: length)
                .frame(width: 1, height: 1)
                .opacity(0.01)

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
                                        i == selectedIndex ? theme.primary : Color.gray.opacity(0.2),
                                        lineWidth: i == selectedIndex ? 2 : 1
                                    )
                            )
                        Text(char)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedIndex = min(i, otp.count)
                    }
                }
            }
        }
    }
}

private struct OTPTextFieldBridge: UIViewRepresentable {
    @Binding var otp: String
    @Binding var selectedIndex: Int
    let length: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.textColor = .clear
        field.tintColor = .clear
        field.delegate = context.coordinator
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != otp { field.text = otp }
        context.coordinator.applySelection(to: field)
        if !field.isFirstResponder { DispatchQueue.main.async { field.becomeFirstResponder() } }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OTPTextFieldBridge
        init(_ parent: OTPTextFieldBridge) { self.parent = parent }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = field.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            let candidate = current.replacingCharacters(in: swiftRange, with: string)
            let normalized = String(candidate.filter(\.isNumber).prefix(parent.length))
            field.text = normalized
            parent.otp = normalized
            parent.selectedIndex = min(range.location + string.filter(\.isNumber).count, normalized.count)
            applySelection(to: field)
            return false
        }

        func applySelection(to field: UITextField) {
            let count = (field.text ?? "").count
            let startOffset = min(parent.selectedIndex, count)
            guard let start = field.position(from: field.beginningOfDocument, offset: startOffset) else { return }
            let endOffset = startOffset < count ? startOffset + 1 : startOffset
            guard let end = field.position(from: field.beginningOfDocument, offset: endOffset) else { return }
            field.selectedTextRange = field.textRange(from: start, to: end)
        }
    }
}
