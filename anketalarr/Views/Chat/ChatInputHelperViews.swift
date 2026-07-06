import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import AVKit
import UniformTypeIdentifiers
import CoreLocation
import MapKit
import Combine

/// `VideoRecorder.session`'dan jonli kamera oqimini kichik doirada
/// ko'rsatish uchun (yozish jarayonida foydalanuvchiga vizual tasdiq beradi —
/// Telegram/Instagramdagi instant video xabar UI'siga o'xshash).
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    final class PreviewContainerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// Ovoz yozilayotganini bildiruvchi pulsatsiyalanuvchi qizil nuqta.
struct PulsingDot: View {
    @State private var lit = true
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 9, height: 9)
            .opacity(lit ? 1 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    lit = false
                }
            }
    }
}

/// `PhotosPickerItem`'dan video faylini **fayl URL** ko'rinishida olish uchun
/// (xom `Data` sifatida yuklash katta video fayllar uchun samarasiz/beqaror —
/// Apple tavsiyasiga ko'ra `.movie` content type bilan `FileRepresentation`
/// ishlatiladi: https://developer.apple.com/documentation/coretransferable).
struct ChatPickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Tizim taqdim etgan fayl PhotosPicker tomonidan keyinroq tozalanishi
            // mumkin bo'lgan vaqtinchalik joyda turadi — shu sababli o'zimizning
            // vaqtinchalik papkamizga nusxalab olamiz (yuklash tugaguncha saqlanishi uchun).
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
