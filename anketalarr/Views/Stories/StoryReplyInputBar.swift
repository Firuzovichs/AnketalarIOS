import SwiftUI

// MARK: - Story reply (Instagram-style "reply to story" — yoziladigan matn chatga boradi)

struct StoryReplyInputBar: View {
    @EnvironmentObject var lang: LocalizationManager

    @Binding var replyText: String
    var isSendingReply: Bool
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("", text: $replyText,
                      prompt: Text(lang[.storyReplyPlaceholder]).foregroundColor(.white.opacity(0.6)))
                .focused(isFocused)
                .foregroundColor(.white)
                .submitLabel(.send)
                .onSubmit { onSend() }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))

            if !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { onSend() } label: {
                    if isSendingReply {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isSendingReply)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25), value: replyText.isEmpty)
        .padding(.horizontal, 16)
    }
}
