import SwiftUI

// MARK: - Bottom bar (owner mode — viewers count + delete)

struct StoryOwnerBottomBar: View {
    @EnvironmentObject var lang: LocalizationManager

    var canSeeViewers: Bool
    var viewersCount: Int
    var isDeleting: Bool
    var onShowViewers: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            // Left: viewers count — only for paid plans
            if canSeeViewers {
                Button {
                    onShowViewers()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("\(viewersCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        if viewersCount > 0 {
                            Text(lang[.storyViewedSuffix])
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                }
            } else {
                // Free plan — locked viewers
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                    Text(lang[.storyPremiumViewers])
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.black.opacity(0.3)).clipShape(Capsule())
            }

            Spacer()

            // Right: delete button
            Button {
                onDelete()
            } label: {
                HStack(spacing: 6) {
                    if isDeleting {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    Text(lang[.storyDelete])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.75))
                .clipShape(Capsule())
            }
            .disabled(isDeleting)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}
