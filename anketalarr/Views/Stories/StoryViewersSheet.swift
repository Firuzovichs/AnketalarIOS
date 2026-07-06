import SwiftUI

// MARK: - Viewers sheet

struct StoryViewersSheet: View {
    @EnvironmentObject var lang: LocalizationManager

    var viewers: [StoryViewer]
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                Text("\(lang[.storyViewers]) (\(viewers.count))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 12)

                if viewers.isEmpty {
                    Text(lang[.storyNoViewers])
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewers) { v in
                                viewerRow(v)
                                Divider().background(Color.white.opacity(0.12))
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.12))
            )
            .padding(.horizontal, 0)
        }
        .ignoresSafeArea()
    }

    private func viewerRow(_ v: StoryViewer) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 40, height: 40)
                if let url = v.viewer?.photoURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(width: 40, height: 40).clipShape(Circle())
                        } else { personIcon }
                    }
                } else { personIcon }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(v.viewer?.displayName ?? lang[.dbUser])
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                if !v.formattedTime.isEmpty {
                    Text(v.formattedTime + lang[.storyAgo])
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer()
            if let sticker = v.reaction {
                Text(stickerEmoji(sticker))
                    .font(.system(size: 22))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func stickerEmoji(_ sticker: String) -> String {
        let map: [String: String] = [
            "heart": "❤️", "love": "😍", "laugh": "😂", "fire": "🔥", "wow": "😮"
        ]
        return map[sticker] ?? sticker
    }

    private var personIcon: some View {
        Image(systemName: "person.fill").foregroundColor(.white).font(.system(size: 16))
    }
}
