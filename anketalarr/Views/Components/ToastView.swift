import SwiftUI

// MARK: - Toast View
struct ToastView: View {
    let message: String
    var isError: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill((isError ? Color.red : Color.green).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isError ? Color(red: 0.82, green: 0.20, blue: 0.30) : .green)
            }

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isError ? Color(red: 1.0, green: 0.96, blue: 0.97) : Color(red: 0.94, green: 1.0, blue: 0.96))
                .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isError ? Color.red.opacity(0.18) : Color.green.opacity(0.18),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var isError: Bool = true

    func body(content: Content) -> some View {
        ZStack {
            content

            if let msg = message {
                VStack {
                    ToastView(message: msg, isError: isError)
                        .padding(.horizontal, 16)
                        .padding(.top, 56)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .opacity
                            )
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { message = nil }
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                withAnimation(.spring(response: 0.4)) { message = nil }
                            }
                        }
                    Spacer()
                }
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: message != nil)
    }
}

// MARK: - View extension
extension View {
    func toast(_ message: Binding<String?>, isError: Bool = true) -> some View {
        modifier(ToastModifier(message: message, isError: isError))
    }
}
