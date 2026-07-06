import SwiftUI
import UIKit

/// Bitta o'chib ketadigan rasmni to'liq ekranda ko'rsatish.
///
/// Ko'rinish davomiyligi (`disappear_seconds`) faqat QABUL QILUVCHI uchun
/// sanaladi — countdown nolga yetganda `onExpire()` chaqirilib (mahalliy
/// "tugadi" bayrog'i o'rnatiladi) va ekran avtomatik yopiladi. Jo'natuvchi
/// uchun countdown ishlamaydi, lekin bu faqat qabul qiluvchi HALI ko'rib
/// ulgurmagan paytgacha amal qiladi — `disappear_expired` server tomonida
/// xabar darajasida (foydalanuvchiga bog'liq emas) hisoblanganligi sababli,
/// qabul qiluvchining countdown'i tugagach, rasm ikki tomon uchun ham yopiladi.
///
/// MUHIM: skrinshotning O'ZINI texnik jihatdan to'sib bo'lmaydi — iOS bunga
/// ruxsat bermaydi. Shu sababli `UIApplication.userDidTakeScreenshotNotification`
/// orqali skrinshot URINISHI aniqlanadi va `onScreenshotDetected()` chaqirilib,
/// suhbatdoshga "skrinshot olindi" degan tizim xabari yuboriladi.
struct DisappearingPhotoViewerView: View {
    let message: ChatMessage
    let mine: Bool
    var onExpire: () -> Void
    var onScreenshotDetected: () -> Void
    var onClose: () -> Void

    @State private var remaining: Int
    @State private var timer: Timer? = nil
    @State private var didStartCountdown = false

    init(message: ChatMessage, mine: Bool, onExpire: @escaping () -> Void,
         onScreenshotDetected: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.message = message
        self.mine = mine
        self.onExpire = onExpire
        self.onScreenshotDetected = onScreenshotDetected
        self.onClose = onClose
        _remaining = State(initialValue: message.disappear_seconds ?? 5)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // MUHIM: AsyncImage'ni to'g'ridan-to'g'ri ZStack ichiga qo'ysak,
            // `.scaledToFit()` aniq o'lcham (frame) ololmay, rasm markazda
            // emas, yuqoriga "yopishib" yoki noto'g'ri o'lchamda chiqib
            // qolardi ("rasmni yaxshi chiqarmayapti" xatosining sababi shu
            // edi). `ChatMediaViewerView.ZoomableImagePage`dagi kabi —
            // GeometryReader orqali aniq o'lcham berib, shu o'lcham ICHIDA
            // markazlashtiramiz.
            GeometryReader { geo in
                if let url = message.mediaURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
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
            .ignoresSafeArea()

            HStack {
                Button { stopAndClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                Spacer()
                if !mine {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                        Text("\(remaining)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                }
            }
            .padding(.top, 54)
            .padding(.horizontal, 16)
        }
        .statusBarHidden()
        .onAppear { startCountdownIfNeeded() }
        .onDisappear { timer?.invalidate() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            onScreenshotDetected()
        }
    }

    private func startCountdownIfNeeded() {
        guard !mine, !didStartCountdown else { return }
        didStartCountdown = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if remaining <= 1 {
                    timer?.invalidate()
                    onExpire()
                    onClose()
                } else {
                    remaining -= 1
                }
            }
        }
    }

    private func stopAndClose() {
        timer?.invalidate()
        onClose()
    }
}
