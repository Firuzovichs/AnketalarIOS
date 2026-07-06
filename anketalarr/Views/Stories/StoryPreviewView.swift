import SwiftUI
import AVKit

struct StoryPreviewView: View {
    let image: UIImage?
    let videoURL: URL?
    var onDismiss: () -> Void
    var onPosted: () -> Void

    @StateObject private var vm = StoryViewModel()
    @State private var player: AVPlayer?
    @State private var showError = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ── Media preview ─────────────────────────────────────────────
            if let img = image {
                GeometryReader { geo in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else if let url = videoURL {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .task {
                        let p = AVPlayer(url: url)
                        player = p
                        p.play()
                    }
            }

            // ── Gradients ─────────────────────────────────────────────────
            VStack {
                LinearGradient(colors: [.black.opacity(0.5), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 180)
            }
            .ignoresSafeArea()

            // ── Controls ──────────────────────────────────────────────────
            VStack {
                HStack {
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                            .padding(18)
                    }
                    Spacer()
                }

                Spacer()

                VStack(spacing: 16) {
                    // Visibility badge
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.pink)
                        Text("Faqat yoqtirganlar ko'ra oladi")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())

                    // Error message
                    if let err = vm.uploadError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Post button
                    Button {
                        vm.uploadError = nil
                        Task {
                            if let img = image {
                                await vm.uploadPhoto(img)
                            } else if let url = videoURL {
                                await vm.uploadVideo(url: url)
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if vm.isUploading {
                                ProgressView().tint(.white).scaleEffect(0.9)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                            }
                            Text(vm.isUploading ? "Yuklanmoqda..." : "Istoriyaga qo'yish")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E53")],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .opacity(vm.isUploading ? 0.6 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .disabled(vm.isUploading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)
                }
            }
        }
        // iOS 17+ onChange signature
        .onChange(of: vm.uploadSuccess) { _, success in
            if success { onPosted() }
        }
    }
}
