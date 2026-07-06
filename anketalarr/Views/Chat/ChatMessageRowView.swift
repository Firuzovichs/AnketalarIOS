import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import AVKit
import UniformTypeIdentifiers
import CoreLocation
import MapKit
import Combine

/// Suhbat pufakchasi ichida ko'rsatiladigan bitta xabar qatori — rasm/video/
/// ovozli/lokatsiya/matn turlarini chizadi, hamda Telegram uslubidagi
/// yon tomonga tortib "javob berish"ni ishga tushiruvchi imo ishorasini o'z ichiga oladi.
struct MessageRowView: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager

    let msg: ChatMessage
    let mine: Bool
    let onReply: () -> Void
    let onDelete: () -> Void
    /// Faqat o'z matnli xabarini tahrirlash rejimini boshlash uchun chaqiriladi
    /// (parent — `startEditing(_:)`). Boshqa foydalanuvchining xabarida bu
    /// hech qachon chaqirilmaydi (contextMenu'da ko'rinmaydi ham).
    let onEdit: () -> Void
    let onTapMedia: () -> Void
    // O'chib ketadigan rasm uchun: countdown ekranda tugaganda mahalliy
    // ravishda darhol "muddati tugadi" ko'rinishini ko'rsatish uchun
    // (serverga qaytib tasdiqlashni kutmasdan) va shu rasmni ochish chaqirig'i.
    let isExpiredLocally: Bool
    let onTapDisappearing: () -> Void
    /// Qidiruv natijasiga sakralganda shu xabar qisqa muddat "yarq etib"
    /// ajratib ko'rsatiladi (Telegram uslubida) — parent tomonidan
    /// `highlightedMessageId == msg.id` bo'lganda `true` qilib beriladi.
    var isHighlighted: Bool = false

    @State private var dragX: CGFloat = 0
    @State private var triggeredHaptic = false

    private let maxDrag: CGFloat = 60
    private let triggerThreshold: CGFloat = 44

    var body: some View {
        if msg.message_type == "system" {
            systemMessageRow
        } else {
            normalRow
        }
    }

    /// "Skrinshot olindi" kabi tizim xabarlari — odatdagi chap/o'ng pufakcha
    /// emas, o'rtada kichik pill ko'rinishida (Telegram'dagi tizim xabarlariga o'xshash).
    private var systemMessageRow: some View {
        HStack {
            Spacer(minLength: 20)
            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 11))
                Text(mine ? lang[.chatSystemScreenshotSelf] : lang[.chatSystemScreenshotOther])
                    .font(.system(size: 12))
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            Spacer(minLength: 20)
        }
        .padding(.vertical, 2)
    }

    private var normalRow: some View {
        HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if let reply = msg.reply_to {
                    replyPreviewChip(reply)
                }
                bubbleContent
                    // Faqat pufakchaning o'ziga tegishli — shu sababli bosib-turishda
                    // chiqadigan tepa qoplama/yorqinlik HAM faqat pufakcha o'lchamida
                    // bo'ladi (oldin butun qator (Spacer bilan birga) bo'ylab cho'zilib,
                    // keyin yo'qolib qoladigan to'rtburchak miltillashiga sabab bo'lardi).
                    // Qidiruvdan sakralgan xabarni qisqa "yarq etib" ajratib
                    // ko'rsatish — shu yerda, chunki barcha xabar turlari uchun
                    // pufakcha rangi shu joyda RoundedRectangle bilan chizilgan.
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isHighlighted ? Color.yellow.opacity(0.35) : Color.clear)
                            .allowsHitTesting(false)
                    )
                    .animation(.easeInOut(duration: 0.35), value: isHighlighted)
                    .contextMenu {
                        // Nusxa olish — ikki tomon uchun ham, "teskari" (boshqa
                        // foydalanuvchi)ning xabarida FAQAT shu mavjud bo'ladi.
                        if !(msg.content ?? "").isEmpty && msg.is_deleted != true {
                            Button { UIPasteboard.general.string = msg.content } label: {
                                Label(lang[.chatCopy], systemImage: "doc.on.doc")
                            }
                        }
                        if mine && msg.message_type == "text" && msg.is_deleted != true {
                            Button { onEdit() } label: {
                                Label(lang[.chatEdit], systemImage: "pencil")
                            }
                        }
                        if mine && msg.is_deleted != true {
                            Button(role: .destructive) { onDelete() } label: {
                                Label(lang[.storyDelete], systemImage: "trash")
                            }
                        }
                    }
                HStack(spacing: 4) {
                    if msg.isEdited {
                        Text(lang[.chatEditedTag])
                            .font(.system(size: 10.5))
                            .foregroundColor(theme.textSecondary)
                    }
                    Text(msg.formattedTime)
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textSecondary)
                    if mine {
                        Image(systemName: msg.seen_by_other == true ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 11))
                            .foregroundColor(msg.seen_by_other == true ? theme.primary : theme.textSecondary)
                    }
                }
            }
            if !mine { Spacer(minLength: 40) }
        }
        .background(
            HStack {
                if !mine {
                    replyIcon.padding(.leading, 4)
                    Spacer()
                } else {
                    Spacer()
                    replyIcon.padding(.trailing, 4)
                }
            }
            .opacity(min(1, abs(dragX) / triggerThreshold))
        )
        .offset(x: dragX)
        .gesture(
            // minimumDistance: 16 — ScrollView'ning vertikal aylantirishi bilan
            // tasodifiy to'qnashmasligi uchun, faqat sezilarli tortishda ishga tushadi.
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    // Faqat asosan GORIZONTAL tortishlarda ishlaymiz (Telegram'dagi
                    // kabi) — aks holda ScrollView'ning vertikal scroll imo
                    // ishorasi bilan to'qnashib, suhbatni aylantirishni buzardi.
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                    let clamped = max(-maxDrag, min(maxDrag, value.translation.width))
                    dragX = clamped
                    let crossed = abs(clamped) >= triggerThreshold
                    if crossed && !triggeredHaptic {
                        triggeredHaptic = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else if !crossed {
                        triggeredHaptic = false
                    }
                }
                .onEnded { _ in
                    let crossed = abs(dragX) >= triggerThreshold
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragX = 0
                    }
                    triggeredHaptic = false
                    if crossed { onReply() }
                }
        )
    }

    private var replyIcon: some View {
        Image(systemName: "arrowshape.turn.up.left.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(theme.primary)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let bg: Color = mine ? theme.primary : Color(.systemGray6)
        let fg: Color = mine ? .white : theme.textPrimary

        if msg.is_deleted == true {
            Text(lang[.chatMsgDeleted])
                .italic()
                .font(.system(size: 14))
                .foregroundColor(fg.opacity(0.6))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(bg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if msg.message_type == "image", let url = msg.mediaURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(Color(.systemGray5)).overlay(ProgressView())
                }
            }
            .frame(width: 190, height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .onTapGesture { onTapMedia() }
        } else if msg.message_type == "video", let url = msg.mediaURL {
            VideoBubbleThumb(url: url)
                .frame(width: 190, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
                .onTapGesture { onTapMedia() }
        } else if msg.message_type == "voice", let url = msg.mediaURL {
            VoiceBubblePlayer(url: url, tint: fg, knownDuration: msg.duration)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if msg.message_type == "voice" {
            // media hali URL bo'lib kelmagan (masalan, offline keshlash holati) — zaxira ko'rinish.
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                Text(lang[.chatMsgVoice])
            }
            .font(.system(size: 14))
            .foregroundColor(fg)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if msg.message_type == "video" {
            // media hali URL bo'lib kelmagan — zaxira ko'rinish.
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                Text(lang[.chatMsgVideo])
            }
            .font(.system(size: 14))
            .foregroundColor(fg)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if msg.message_type == "location", let lat = msg.latitude, let lng = msg.longitude {
            LocationBubble(lat: lat, lng: lng)
                .frame(width: 190, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if msg.message_type == "disappearing_photo" {
            disappearingPhotoBubble(bg: bg, fg: fg)
        } else if msg.message_type == "story_reply" {
            storyReplyBubble(bg: bg, fg: fg)
        } else {
            Text(msg.content ?? "")
                .font(.system(size: 15))
                .foregroundColor(fg)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    /// O'chib ketadigan rasm pufakchasi — hali ochilmagan/muddati tugamagan
    /// bo'lsa "ko'rish uchun bosing", aks holda (server `disappear_expired`
    /// YOKI mahalliy countdown tugagan) "muddati tugadi" ko'rinishi chiqadi.
    /// Muddati tugagandan keyin `media` serverda allaqachon null qilingan
    /// bo'ladi, shu sababli bu holatda hech qachon rasmni qayta ko'rsatmaymiz.
    @ViewBuilder
    private func disappearingPhotoBubble(bg: Color, fg: Color) -> some View {
        let expired = (msg.disappear_expired == true) || isExpiredLocally
        VStack(spacing: 6) {
            Image(systemName: expired ? "eye.slash.fill" : "timer")
                .font(.system(size: 26))
            Text(expired ? lang[.chatDisappearingExpired] : lang[.chatDisappearingTapToView])
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(fg)
        .frame(width: 150, height: 150)
        .padding(.horizontal, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture { if !expired { onTapDisappearing() } }
    }

    /// Instagram uslubidagi "story javobi" pufakchasi — yuqorida kichik
    /// thumbnail (javob yozilgan storyning rasmi) + "Story javobi" yorlig'i,
    /// pastda esa foydalanuvchi yozgan haqiqiy matn (agar bo'lsa).
    @ViewBuilder
    private func storyReplyBubble(bg: Color, fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    if let url = msg.story?.mediaURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Rectangle().fill(Color(.systemGray5))
                            }
                        }
                    } else {
                        Rectangle().fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.textSecondary)
                            )
                    }
                }
                .frame(width: 34, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 7))

                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 10))
                    Text(lang[.chatMsgStoryReply])
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundColor(fg.opacity(0.75))
            }
            if let text = msg.content, !text.isEmpty {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(fg)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func replyPreviewChip(_ reply: ChatReplyPreview) -> some View {
        HStack(spacing: 6) {
            // replyBar'dagi bilan bir xil sabab — Rectangle() balandligini cheklab
            // qo'yamiz, aks holda xabar pufakchasi ichidagi reply chip ham
            // kattalashib ketadi.
            Rectangle().fill(theme.primary).frame(width: 2.5).frame(maxHeight: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(reply.sender?.displayName ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primary)
                Text(reply.previewText)
                    .font(.system(size: 11.5))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .background(Color(.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Ovozli xabar pufakchasi ichidagi play/pause kontrol — masofadagi
/// media URL'ni AVPlayer orqali stream qiladi (yuklab olishni kutmasdan).
struct VoiceBubblePlayer: View {
    let url: URL
    let tint: Color

    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: Double
    @State private var timeObserver: Any? = nil
    @State private var endObserver: NSObjectProtocol? = nil

    /// `knownDuration` — serverdan kelgan, yozish vaqtida o'lchangan haqiqiy
    /// uzunlik (Message.duration). Mavjud bo'lsa, buni boshida ko'rsatamiz —
    /// remote fayldan AVURLAsset orqali qaytadan hisoblashni KUTISH SHART
    /// EMAS (aynan shu kutish/ishonchsizlik "00:00" xatosining sababi edi).
    init(url: URL, tint: Color, knownDuration: Double?) {
        self.url = url
        self.tint = tint
        _duration = State(initialValue: (knownDuration?.isFinite == true ? knownDuration! : 0))
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { toggle() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13))
                    .foregroundColor(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.18))
                    .clipShape(Circle())
            }
            ProgressView(value: min(max(progress, 0), 1))
                .tint(tint)
                .frame(width: 86)
            Text(formatTime(duration > 0 ? duration : nil))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(tint.opacity(0.8))
        }
        .onAppear { loadDurationIfNeeded() }
        .onDisappear { cleanup() }
    }

    /// Davomiylikni pufakcha ko'ringan ZAHOTI yuklaymiz (play tugmasi
    /// bosilishini kutmaymiz) — aks holda foydalanuvchi hali bosmagan
    /// ovozli xabarlar doim "0:00" ko'rsatib turardi (asl xato shu yerda edi).
    private func loadDurationIfNeeded() {
        guard duration == 0 else { return }
        Task {
            let asset = AVURLAsset(url: url)
            if let loaded = try? await asset.load(.duration) {
                let secs = CMTimeGetSeconds(loaded)
                if secs.isFinite, secs > 0 { duration = secs }
            }
        }
    }

    private func toggle() {
        if player == nil { setup() }
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }

    private func setup() {
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        player = p

        loadDurationIfNeeded()

        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { time in
            guard duration > 0 else { return }
            progress = CMTimeGetSeconds(time) / duration
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in
            isPlaying = false
            progress = 0
            player?.seek(to: .zero)
        }
    }

    private func cleanup() {
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
        player?.pause()
    }

    private func formatTime(_ t: Double?) -> String {
        guard let t, t.isFinite, t > 0 else { return "0:00" }
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Video xabar pufakchasi ichidagi statik ko'rinish — videoning birinchi
/// kadridan hosil qilingan eskiz (thumbnail) + ustida play belgisi.
/// Bosilganda to'liq ekran galereyasi ochiladi (haqiqiy ijro shu yerda EMAS).
struct VideoBubbleThumb: View {
    let url: URL
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().scaledToFill()
            } else {
                Rectangle().fill(Color(.systemGray5))
                ProgressView()
            }
            Image(systemName: "play.circle.fill")
                .font(.system(size: 34))
                .foregroundColor(.white)
                .shadow(radius: 3)
        }
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let cgImage = try? await generator.image(at: .zero).image {
            thumbnail = UIImage(cgImage: cgImage)
        }
    }
}

/// Xabar ichidagi statik (interaktiv bo'lmagan) joylashuv ko'rinishi —
/// bosilganda to'liq Apple Maps ilovasida ochiladi.
struct LocationBubble: View {
    let lat: Double
    let lng: Double

    @State private var position: MapCameraPosition

    init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        _position = State(initialValue: .region(
            MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        ))
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            Marker("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                .tint(.red)
        }
        .allowsHitTesting(false)
        .overlay(
            Color.clear.contentShape(Rectangle())
        )
        .onTapGesture {
            if let url = URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)") {
                UIApplication.shared.open(url)
            }
        }
    }
}
