import SwiftUI

// MARK: - Bottom bar (viewer mode, i.e. not the story owner)

struct StoryViewerBottomBar: View {
    @EnvironmentObject var lang: LocalizationManager

    var viewsCount: Int?
    @Binding var selectedReaction: String?
    var showReplySent: Bool
    @Binding var replyText: String
    var isSendingReply: Bool
    var isReplyFocused: FocusState<Bool>.Binding
    var onReact: (_ emoji: String, _ sticker: String) -> Void
    var onSendReply: () -> Void

    private let reactionEmojis: [(emoji: String, sticker: String)] = [
        ("❤️", "heart"), ("😍", "love"), ("😂", "laugh"), ("🔥", "fire"), ("😮", "wow")
    ]

    var body: some View {
        VStack(spacing: 10) {
            // Emoji reaction row
            HStack(spacing: 20) {
                ForEach(reactionEmojis, id: \.emoji) { item in
                    Button {
                        onReact(item.emoji, item.sticker)
                    } label: {
                        Text(item.emoji)
                            .font(.system(size: 32))
                            .scaleEffect(selectedReaction == item.emoji ? 1.5 : 1)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: selectedReaction)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Color.black.opacity(0.3))
            .clipShape(Capsule())

            // View count row
            HStack {
                if let viewsCount {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                        Text("\(viewsCount)")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            if showReplySent {
                Text(lang[.storyReplySent])
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .transition(.opacity)
            }

            // Instagram-style "reply to story" matn maydoni — yozilgan matn
            // storyning egasiga CHATDA story-javob xabari bo'lib boradi.
            StoryReplyInputBar(
                replyText: $replyText,
                isSendingReply: isSendingReply,
                isFocused: isReplyFocused,
                onSend: onSendReply
            )
        }
        .padding(.bottom, 24)
    }
}
