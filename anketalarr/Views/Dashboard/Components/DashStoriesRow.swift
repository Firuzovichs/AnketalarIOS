import SwiftUI

// Item passed to fullScreenCover — carries all owner-mode data reliably
struct OwnStoryPresentation: Identifiable {
    let id = UUID()
    let group: StoryGroup
    let isPaid: Bool
}

// Feed viewer — groups + startIndex bitta item'da, race condition yo'q
struct FeedStoryPresentation: Identifiable {
    let id = UUID()
    let groups: [StoryGroup]
    let startIndex: Int
}

struct DashStoriesRow: View {
    let me: DashMe?
    let stories: [DashStory]
    let myStory: DashStory?
    var onStoryPosted: (() -> Void)? = nil
    var onStoryDeleted: (() -> Void)? = nil
    var onViewerClosed: (() -> Void)? = nil   // viewer yopilganda storiesni yangilash uchun

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager

    @AppStorage("viewed_own_story_id") private var viewedOwnStoryId: Int = -1
    @State private var currentOwnStoryId: Int = -1

    @State private var showCamera = false
    @State private var feedStoryItem: FeedStoryPresentation? = nil
    @State private var ownStoryItem: OwnStoryPresentation? = nil

    // Group feed stories by user
    private var feedGroups: [StoryGroup] {
        var seen: [Int: [DashStory]] = [:]
        var order: [Int] = []
        for story in stories {
            let uid = story.user?.id ?? 0
            if seen[uid] == nil { order.append(uid) }
            seen[uid, default: []].append(story)
        }
        return order.map { uid in
            let s = seen[uid]!
            return StoryGroup(id: uid, user: s.first?.user, stories: s)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                myStoryBubble

                if stories.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in placeholderBubble }
                } else {
                    ForEach(feedGroups.indices, id: \.self) { i in
                        let g = feedGroups[i]
                        Button {
                            feedStoryItem = FeedStoryPresentation(
                                groups: feedGroups,
                                startIndex: i
                            )
                        } label: {
                            storyBubble(group: g)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        // Camera
        .fullScreenCover(isPresented: $showCamera) {
            StoryCameraView {
                showCamera = false
                onStoryPosted?()
            }
            .environmentObject(theme)
            .environmentObject(lang)
        }
        // Feed viewer — item: pattern: groups to'g'ridan-to'g'ri item'da, race condition yo'q
        .fullScreenCover(item: $feedStoryItem, onDismiss: { onViewerClosed?() }) { item in
            StoryViewerView(
                groups: item.groups,
                startGroupIndex: item.startIndex,
                isOwner: false,
                canSeeViewers: false,
                onDismiss: { feedStoryItem = nil },
                onDeleteStory: nil
            )
            .environmentObject(theme)
            .environmentObject(lang)
        }
        // Own story viewer — item: variant passes data reliably
        .fullScreenCover(item: $ownStoryItem, onDismiss: {
            viewedOwnStoryId = currentOwnStoryId
            onViewerClosed?()
        }) { item in
            StoryViewerView(
                groups: [item.group],
                startGroupIndex: 0,
                isOwner: true,
                canSeeViewers: item.isPaid,
                onDismiss: { ownStoryItem = nil },
                onDeleteStory: { _ in
                    ownStoryItem = nil
                    onStoryDeleted?()
                }
            )
            .environmentObject(theme)
            .environmentObject(lang)
        }
    }

    // MARK: - My story bubble

    private var myStoryBubble: some View {
        Button {
            if let story = myStory {
                let myId = me?.id ?? 0
                let myUser = DashUser(
                    id: myId,
                    profile: me?.profile,
                    main_photo: me?.main_photo,
                    photos: nil,
                    subscription_type: me?.subscription_type,
                    is_online: me?.is_online,
                    last_seen: nil
                )
                let isPaid = me?.subscription_type == "premium" || me?.subscription_type == "vip"
                currentOwnStoryId = story.id
                ownStoryItem = OwnStoryPresentation(
                    group: StoryGroup(id: myId, user: myUser, stories: [story]),
                    isPaid: isPaid
                )
            } else {
                showCamera = true
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    storyRing(
                        url: me?.main_photo?.image.flatMap { URL(string: $0) },
                        hasNewStory: myStory != nil && myStory?.id != viewedOwnStoryId
                    )
                    if myStory == nil {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 22, height: 22)
                            .overlay(Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white))
                            .offset(x: 2, y: 2)
                    }
                }
                Text(lang[.dbMyStory])
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1).frame(width: 64)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feed story

    private func storyBubble(group: StoryGroup) -> some View {
        let allViewed = group.stories.allSatisfy { $0.is_viewed == true }
        return VStack(spacing: 6) {
            storyRing(
                url: group.user?.main_photo?.image.flatMap { URL(string: $0) },
                hasNewStory: !allViewed
            )
            Text(group.user?.profile?.first_name ?? "···")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1).frame(width: 64)
        }
    }

    // MARK: - Placeholder

    private var placeholderBubble: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(theme.primaryLight)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(theme.primary.opacity(0.25), lineWidth: 2.5))
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.primaryLight)
                .frame(width: 40, height: 10)
        }
    }

    // MARK: - Ring helper

    private func storyRing(url: URL?, hasNewStory: Bool) -> some View {
        ZStack {
            Circle().fill(theme.primaryLight).frame(width: 64, height: 64)
            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                            .frame(width: 64, height: 64).clipShape(Circle())
                    } else { personIcon }
                }
            } else { personIcon }
        }
        .overlay(
            Circle().stroke(
                hasNewStory
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.red, theme.primary, Color.orange],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.gray.opacity(0.3)),
                lineWidth: hasNewStory ? 2.5 : 1.5
            ).padding(-3)
        )
        .frame(width: 70, height: 70)
    }

    private var personIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 26))
            .foregroundColor(theme.primary.opacity(0.4))
    }
}
