import SwiftUI
import AVKit

// MARK: - Viewer
// `StoryGroup` modeli — `StoryGroup.swift`. Pastki panellar — `StoryViewerBottomBar.swift`
// (oddiy ko'ruvchi) va `StoryOwnerBottomBar.swift` (egasi uchun). Ko'ruvchilar ro'yxati —
// `StoryViewersSheet.swift`. Progress chizig'i — `StoryProgressBar.swift`.

struct StoryViewerView: View {
    let groups: [StoryGroup]
    let startGroupIndex: Int
    var isOwner: Bool = false
    var canSeeViewers: Bool = false   // only non-free plans can see viewer list
    var onDismiss: () -> Void
    var onDeleteStory: ((Int) -> Void)?

    @StateObject private var vm = StoryViewModel()
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    @State private var groupIndex: Int
    @State private var storyIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var paused = false
    @State private var dragOffset: CGFloat = 0
    @State private var showHeart = false
    @State private var videoPlayer: AVPlayer?

    // Owner mode
    @State private var viewers: [StoryViewer] = []
    @State private var showViewers = false
    @State private var isDeleting = false

    // Reactions
    @State private var selectedReaction: String? = nil
    @State private var floatingReaction: String? = nil

    // Story reply (Instagram-style "reply to story" — yoziladigan matn chatga boradi)
    @State private var replyText: String = ""
    @State private var isSendingReply = false
    @State private var showReplySent = false
    @FocusState private var replyFieldFocused: Bool

    private let storyDuration: Double = 5.0

    init(groups: [StoryGroup], startGroupIndex: Int, isOwner: Bool = false,
         canSeeViewers: Bool = false,
         onDismiss: @escaping () -> Void, onDeleteStory: ((Int) -> Void)?) {
        self.groups = groups
        self.startGroupIndex = startGroupIndex
        self.isOwner = isOwner
        self.canSeeViewers = canSeeViewers
        self.onDismiss = onDismiss
        self.onDeleteStory = onDeleteStory
        _groupIndex = State(initialValue: startGroupIndex)
    }

    private var currentGroup: StoryGroup? {
        groups.indices.contains(groupIndex) ? groups[groupIndex] : nil
    }
    private var currentStory: DashStory? { currentGroup?.stories[safe: storyIndex] }

    var body: some View {
        // Color.black fills full screen — everything else is an overlay on top
        Color.black
            .ignoresSafeArea()
            // ── Media ──────────────────────────────────────────────────
            .overlay {
                if let story = currentStory {
                    if story.media_type == "video", let url = story.mediaURL {
                        VideoPlayer(player: videoPlayer)
                            .id(story.id)
                            .onAppear { startVideo(url: url) }
                    } else if let url = story.mediaURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Color.clear
                            }
                        }
                        .id(story.id)
                    } else {
                        LinearGradient(colors: [.purple.opacity(0.6), .pink.opacity(0.4)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
            }
            .clipped()
            // ── Tap prev / next ────────────────────────────────────────
            .overlay {
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { prevStory() }
                    Color.clear.contentShape(Rectangle()).onTapGesture { nextStory() }
                }
            }
            // ── Long press pause ───────────────────────────────────────
            .overlay {
                Color.clear
                    .onLongPressGesture(minimumDuration: 0.15, maximumDistance: 50,
                        pressing: { pressing in
                            paused = pressing
                            if pressing { stopTimer() } else { resumeTimer() }
                        }, perform: {})
            }
            // ── Heart ──────────────────────────────────────────────────
            .overlay {
                if showHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80)).foregroundColor(.red)
                        .scaleEffect(showHeart ? 1 : 0.5)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            // ── Floating emoji reaction ────────────────────────────────
            .overlay {
                if let emoji = floatingReaction {
                    Text(emoji)
                        .font(.system(size: 80))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity),
                            removal: .scale(scale: 1.6).combined(with: .opacity)
                        ))
                        .allowsHitTesting(false)
                }
            }
            // ── Top controls ───────────────────────────────────────────
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach((currentGroup?.stories ?? []).indices, id: \.self) { i in
                            StoryProgressBar(progress: progressFor(index: i), color: .white)
                        }
                    }
                    .padding(.horizontal, 12)

                    HStack(spacing: 10) {
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white).shadow(radius: 3).padding(10)
                        }
                        if let user = currentGroup?.user {
                            avatarView(user: user)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(user.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                if let story = currentStory {
                                    Text(story.formattedTime)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.top, 8)
            }
            // ── Bottom controls ────────────────────────────────────────
            .overlay(alignment: .bottom) {
                if isOwner {
                    StoryOwnerBottomBar(
                        canSeeViewers: canSeeViewers,
                        viewersCount: viewers.count,
                        isDeleting: isDeleting,
                        onShowViewers: {
                            stopTimer()
                            showViewers = true
                        },
                        onDelete: {
                            guard let story = currentStory else { return }
                            isDeleting = true
                            Task {
                                let ok = await vm.deleteStory(id: story.id)
                                isDeleting = false
                                if ok { onDeleteStory?(story.id) }
                            }
                        }
                    )
                } else {
                    StoryViewerBottomBar(
                        viewsCount: currentStory.map { $0.views_count ?? 0 },
                        selectedReaction: $selectedReaction,
                        showReplySent: showReplySent,
                        replyText: $replyText,
                        isSendingReply: isSendingReply,
                        isReplyFocused: $replyFieldFocused,
                        onReact: { emoji, sticker in triggerReaction(emoji, sticker: sticker) },
                        onSendReply: { sendReply() }
                    )
                    .onChange(of: replyFieldFocused) { focused in
                        paused = focused
                        if focused { stopTimer() } else { resumeTimer() }
                    }
                }
            }
            // ── Viewers sheet ──────────────────────────────────────────
            .overlay {
                if showViewers {
                    StoryViewersSheet(viewers: viewers, onDismiss: {
                        showViewers = false
                        resumeTimer()
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35), value: showViewers)
                }
            }
            .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { v in
                    if v.translation.height > 0 { dragOffset = v.translation.height }
                }
                .onEnded { v in
                    if v.translation.height > 80 {
                        withAnimation(.easeOut(duration: 0.2)) { onDismiss() }
                    } else {
                        withAnimation(.spring()) { dragOffset = 0 }
                    }
                }
        )
        .onAppear {
            guard currentGroup != nil else { onDismiss(); return }
            startTimer()
            if isOwner { loadViewers() }
        }
        .onDisappear { stopTimer(); videoPlayer?.pause() }
    }

    // MARK: - Avatar

    private func avatarView(user: DashUser) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.3)).frame(width: 36, height: 36)
            if let url = user.photoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                            .frame(width: 36, height: 36).clipShape(Circle())
                    } else { personIcon }
                }
            } else { personIcon }
        }
    }

    private var personIcon: some View {
        Image(systemName: "person.fill").foregroundColor(.white).font(.system(size: 16))
    }

    // MARK: - Progress

    private func progressFor(index: Int) -> CGFloat {
        if index < storyIndex { return 1 }
        if index == storyIndex { return progress }
        return 0
    }

    // MARK: - Navigation

    private func nextStory() {
        stopTimer()
        progress = 0
        guard let group = currentGroup else { onDismiss(); return }
        if storyIndex < group.stories.count - 1 {
            storyIndex += 1
            markViewed()
            startTimer()
        } else if groupIndex < groups.count - 1 {
            groupIndex += 1
            storyIndex = 0
            markViewed()
            startTimer()
            if isOwner { loadViewers() }
        } else {
            onDismiss()
        }
    }

    private func prevStory() {
        stopTimer()
        progress = 0
        if storyIndex > 0 {
            storyIndex -= 1
        } else if groupIndex > 0 {
            groupIndex -= 1
            // currentGroup is now the previous group — use safe access
            storyIndex = max(0, (currentGroup?.stories.count ?? 1) - 1)
        }
        startTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        progress = 0
        let interval: Double = 0.05
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard !self.paused else { return }
            self.progress += CGFloat(interval / self.storyDuration)
            if self.progress >= 1 { self.nextStory() }
        }
        markViewed()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resumeTimer() {
        guard timer == nil else { return }
        let interval: Double = 0.05
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard !self.paused else { return }
            self.progress += CGFloat(interval / self.storyDuration)
            if self.progress >= 1 { self.nextStory() }
        }
    }

    // MARK: - Video

    private func startVideo(url: URL) {
        videoPlayer?.pause()
        videoPlayer = AVPlayer(url: url)
        videoPlayer?.play()
    }

    // MARK: - Actions

    private func reactHeart() {
        guard let story = currentStory else { return }
        withAnimation(.spring(response: 0.25)) { showHeart = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showHeart = false }
        }
        Task { await vm.react(storyId: story.id) }
    }

    private func triggerReaction(_ emoji: String, sticker: String) {
        guard let story = currentStory else { return }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { selectedReaction = emoji }
        withAnimation(.spring(response: 0.3)) { floatingReaction = emoji }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.2)) { selectedReaction = nil }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { floatingReaction = nil }
        }
        Task { await vm.react(storyId: story.id, reaction: sticker) }
    }

    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let story = currentStory, !isSendingReply else { return }
        isSendingReply = true
        Task {
            let result = await vm.sendReply(storyId: story.id, text: text)
            isSendingReply = false
            guard result != nil else { return }
            replyText = ""
            replyFieldFocused = false
            withAnimation { showReplySent = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showReplySent = false }
            }
        }
    }

    private func markViewed() {
        guard !isOwner, let story = currentStory else { return }
        Task { await vm.markViewed(storyId: story.id) }
    }

    private func loadViewers() {
        guard let story = currentStory else { return }
        Task { viewers = await vm.fetchViewers(storyId: story.id) }
    }
}
