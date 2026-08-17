import SwiftUI
import AVKit

/// Backend'dan keladigan statik sahifa — Biz haqimizda / Foydalanish shartlari /
/// Maxfiylik siyosati. Sozlamalar ekranidan alohida sahifa sifatida ochiladi
/// (NavigationStack push), kontent admin paneldan tahrirlanadi.
struct StaticPageView: View {
    let slug: String
    var acceptAction: ((String) -> Void)? = nil

    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang:  LocalizationManager
    @StateObject private var vm = StaticPageViewModel()
    @State private var selectedVideo: VideoPresentation?

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if vm.isLoading {
                ProgressView()
                    .tint(theme.primary)
            } else if let err = vm.errorMsg {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(theme.textSecondary.opacity(0.6))
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            } else {
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(theme.primary)
                                Text("Iltimos, shartlarni diqqat bilan o‘qib chiqing")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(theme.primaryLight)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        Text(vm.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(theme.textPrimary)

                        Text(linkifiedContent)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textSecondary)
                            .tint(theme.primary)
                            .lineSpacing(5)

                        if slug == "terms",
                           let banner = vm.termsBanner,
                           banner.isCurrentVersionAccepted {
                            acceptedCard(banner)
                                .padding(.top, 8)
                        }
                        }
                        .padding(20)
                    }

                    if let acceptAction {
                        PrimaryButton(title: "Tasdiqlayman") {
                            acceptAction(vm.version)
                        }
                            .disabled(vm.version.isEmpty)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.96))
                    } else if slug == "terms",
                              let banner = vm.termsBanner,
                              !banner.isCurrentVersionAccepted {
                        PrimaryButton(title: "Shartlarni qabul qilish", isLoading: vm.isAccepting) {
                            Task { await vm.acceptCurrentTerms() }
                        }
                        .disabled(vm.isAccepting)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.96))
                    }
                }
            }
        }
        .navigationTitle(vm.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(slug: slug) }
        .sheet(item: $selectedVideo) { video in
            ProofVideoPlayerSheet(url: video.url)
                .environmentObject(theme)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var linkifiedContent: AttributedString {
        let attributed = NSMutableAttributedString(string: vm.content)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let fullRange = NSRange(location: 0, length: (vm.content as NSString).length)
            detector.enumerateMatches(in: vm.content, options: [], range: fullRange) { match, _, _ in
                guard let range = match?.range, let url = match?.url else { return }
                attributed.addAttributes([
                    .link: url,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ], range: range)
            }
        }
        return AttributedString(attributed)
    }

    @ViewBuilder
    private func acceptedCard(_ banner: StaticPageViewModel.TermsBanner) -> some View {
        let rawMediaURL = banner.proofMedia?.url ?? ""
        let isVideoProof = banner.proofMedia?.type?.lowercased() == "video"
            || rawMediaURL.lowercased().contains(".mp4")
            || rawMediaURL.lowercased().contains(".mov")
        HStack(spacing: 14) {
            if let rawURL = banner.proofMedia?.url,
               let url = resolvedMediaURL(rawURL) {
                let thumbnailURL = resolvedMediaURL(
                    banner.proofMedia?.thumbnailURL
                ) ?? url
                AsyncImage(url: thumbnailURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        facePlaceholder
                    }
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.primary, lineWidth: 2))
                .overlay(alignment: .center) {
                    if isVideoProof {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                }
                .onTapGesture {
                    if isVideoProof {
                        selectedVideo = VideoPresentation(url: url)
                    }
                }
            } else {
                facePlaceholder
                    .frame(width: 52, height: 52)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Shartlar qabul qilingan")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                Text(acceptanceDetails(banner))
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)

                if banner.proofMedia?.isFaceVerified == true {
                    Text("Shaxs face-scan orqali tasdiqlangan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(theme.primary.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.primary.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
    }

    private func resolvedMediaURL(_ raw: String?) -> URL? {
        guard var src = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !src.isEmpty else {
            return nil
        }

        src = src.replacingOccurrences(of: " ", with: "%20")
        let apiHost = APIConfig.base.components(separatedBy: "/api").first ?? APIConfig.base
        let shouldRewriteLocalHost = { (u: URLComponents) in
            guard let host = u.host?.lowercased() else { return false }
            return host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0"
        }

        if src.hasPrefix("http://") || src.hasPrefix("https://") {
            if var components = URLComponents(string: src),
               shouldRewriteLocalHost(components),
               let base = URLComponents(string: apiHost) {
                components.scheme = base.scheme
                components.host = base.host
                components.port = base.port
                return components.url
            }
            return URL(string: src)
        }

        let host = APIConfig.base.components(separatedBy: "/api").first ?? ""
        if host.isEmpty {
            return nil
        }
        if src.hasPrefix("/") {
            return URL(string: "\(host)\(src)")
        }
        return URL(string: "\(host)/\(src)")
    }

    private var facePlaceholder: some View {
        ZStack {
            Circle().fill(theme.primary)
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func acceptanceDetails(_ banner: StaticPageViewModel.TermsBanner) -> String {
        var details: [String] = []
        if let version = banner.acceptedVersion, !version.isEmpty {
            details.append("Versiya: \(version)")
        }
        if let acceptedAt = banner.acceptedAt, !acceptedAt.isEmpty {
            if let acceptedWithTime = formattedAcceptedAt(acceptedAt) {
                details.append("Sana: \(acceptedWithTime)")
            }
        }
        return details.joined(separator: "  •  ")
    }

    private func formattedAcceptedAt(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.timeZone = .current
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let fullWithFraction = ISO8601DateFormatter()
        fullWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fullWithFraction.date(from: trimmed) {
            return displayFormatter.string(from: date)
        }

        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime]
        if let date = full.date(from: trimmed) {
            return displayFormatter.string(from: date)
        }

        let normalized = trimmed.replacingOccurrences(of: "T", with: " ").replacingOccurrences(of: "Z", with: "")
        if normalized.count >= 16 {
            return String(normalized.prefix(16))
        }
        return normalized
    }
}

private struct VideoPresentation: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ProofVideoPlayerSheet: View {
    let url: URL

    @EnvironmentObject private var theme: AppTheme
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasPlaybackStarted = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.primary.opacity(0.16), theme.background, theme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(theme.primary.opacity(0.14))
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(theme.primary)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tasdiqlash videosi")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                        Text("Face-scan orqali tasdiqlangan")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.78), in: Circle())
                    }
                }

                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.black)

                        if let player {
                            VideoPlayer(player: player)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .onAppear {
                                    if hasPlaybackStarted { return }
                                    player.play()
                                    hasPlaybackStarted = true
                                }
                        } else {
                            ProgressView()
                                .tint(.white)
                        }

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.15)
                    }

                    if let errorMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(theme.primary)
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 18, y: 8)

                Text("Video faqat tasdiqlash ma’lumotini ko‘rish uchun ko‘rsatilmoqda.")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
            }
            .padding(20)
        }
        .onAppear {
            isLoading = true
            errorMessage = nil
            hasPlaybackStarted = false

            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.automaticallyWaitsToMinimizeStalling = false
            player = newPlayer
            newPlayer.play()

            Task {
                for _ in 0..<140 {
                    if let status = newPlayer.currentItem?.status {
                        switch status {
                        case .readyToPlay:
                            isLoading = false
                            return
                        case .failed:
                            isLoading = false
                            errorMessage = "Videoni yuklab bo‘lmadi"
                            return
                        default:
                            break
                        }
                    }
                    if let error = newPlayer.currentItem?.error {
                        isLoading = false
                        errorMessage = error.localizedDescription
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                isLoading = false
                errorMessage = "Video yuklanishi juda uzoq davom etdi"
            }
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }
}

#Preview {
    NavigationStack {
        StaticPageView(slug: "about")
            .environmentObject(AppTheme())
            .environmentObject(LocalizationManager())
    }
}
