import SwiftUI
import AVKit

/// Rasm/video xabarlarini to'liq ekranda ko'rish — Telegram uslubida:
/// pinch-to-zoom (faqat rasmlarda), ikki marta bosib kattalashtirish, va
/// chap/o'ng tomonga tortib oldingi/keyingi media'ga o'tish (galereya).
struct ChatMediaViewerView: View {
    let items: [ChatMessage]
    let startIndex: Int
    var onClose: () -> Void

    @State private var currentIndex: Int

    init(items: [ChatMessage], startIndex: Int, onClose: @escaping () -> Void) {
        self.items = items
        self.startIndex = startIndex
        self.onClose = onClose
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, msg in
                    mediaPage(msg).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding(.top, 54)
            .padding(.trailing, 16)
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private func mediaPage(_ msg: ChatMessage) -> some View {
        if msg.message_type == "video", let url = msg.mediaURL {
            VideoPagerPage(url: url)
        } else if let url = msg.mediaURL {
            ZoomableImagePage(url: url)
        } else {
            Color.black
        }
    }
}

/// Bitta rasm sahifasi — pinch-to-zoom (1...4x) va, kattalashtirilgan
/// holatda, pan (surish) qilish bilan. Kattalashtirilmagan holatda drag
/// hech narsa qilmaydi — shu orqali TabView'ning o'zaro sahifalar bo'ylab
/// tortish (swipe) imo ishorasi bilan to'qnashmaydi.
private struct ZoomableImagePage: View {
    let url: URL

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnification.simultaneously(with: pan))
                        .onTapGesture(count: 2) { toggleZoom() }
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                        Text("—")
                    }
                    .foregroundColor(.white.opacity(0.7))
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(4, max(1, lastScale * value))
            }
            .onEnded { _ in
                lastScale = scale
                if scale == 1 {
                    withAnimation { offset = .zero }
                    lastOffset = .zero
                }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation {
            if scale > 1 {
                scale = 1; lastScale = 1
                offset = .zero; lastOffset = .zero
            } else {
                scale = 2.5; lastScale = 2.5
            }
        }
    }
}

/// Bitta video sahifasi — ko'rinib turganda avtomatik ijro etiladi, sahifadan
/// chiqib ketganda (boshqa media'ga o'tilganda yoki yopilganda) to'xtaydi
/// (tarmoq/xotirani tejash uchun).
private struct VideoPagerPage: View {
    let url: URL
    @State private var player: AVPlayer? = nil

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            let p = AVPlayer(url: url)
            player = p
            p.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
