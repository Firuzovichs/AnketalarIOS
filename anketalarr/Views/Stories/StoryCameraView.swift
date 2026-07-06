import SwiftUI
import AVFoundation
import PhotosUI
import Combine

// MARK: - Media container (Identifiable for fullScreenCover(item:))

struct StoryMediaItem: Identifiable {
    let id = UUID()
    let image: UIImage?
    let videoURL: URL?
}

// MARK: - Camera Session

final class StoryCameraSession: NSObject, ObservableObject,
                                 AVCapturePhotoCaptureDelegate,
                                 AVCaptureFileOutputRecordingDelegate {

    let session = AVCaptureSession()
    private let photoOutput  = AVCapturePhotoOutput()
    private let videoOutput  = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "cam.session")

    @Published var isReady   = false
    @Published var flashOn   = false
    private var currentPosition: AVCaptureDevice.Position = .back

    private var photoCallback: ((UIImage?) -> Void)?
    private var videoCallback: ((URL?) -> Void)?

    // MARK: Start / Stop

    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func start() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async { self.isReady = true }
        return
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.sessionQueue.async { self.configureSession() } }
            }
        default: break
        }
    }

    func stop() {
        sessionQueue.async { self.session.stopRunning() }
    }

    // MARK: Configure

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Video
        guard addVideoDevice(position: .back) else {
            session.commitConfiguration(); return
        }

        // Audio
        if let audioDev = AVCaptureDevice.default(for: .audio),
           let audioIn  = try? AVCaptureDeviceInput(device: audioDev),
           session.canAddInput(audioIn) {
            session.addInput(audioIn)
        }

        // Outputs
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async { self.isReady = true }
    }

    @discardableResult
    private func addVideoDevice(position: AVCaptureDevice.Position) -> Bool {
        let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
               ?? AVCaptureDevice.default(for: .video)
        guard let dev,
              let input = try? AVCaptureDeviceInput(device: dev),
              session.canAddInput(input) else { return false }
        session.addInput(input)
        currentPosition = position
        return true
    }

    // MARK: Flip camera

    func flipCamera() {
        sessionQueue.async {
            self.session.beginConfiguration()
            // Remove only video inputs
            self.session.inputs
                .compactMap { $0 as? AVCaptureDeviceInput }
                .filter { $0.device.hasMediaType(.video) }
                .forEach { self.session.removeInput($0) }

            let next: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            self.addVideoDevice(position: next)
            self.session.commitConfiguration()
        }
    }

    func toggleFlash() {
        DispatchQueue.main.async { self.flashOn.toggle() }
    }

    // MARK: Capture photo

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard session.isRunning else { completion(nil); return }
        guard let connection = photoOutput.connection(with: .video),
              connection.isActive, connection.isEnabled else {
            completion(nil); return
        }
        photoCallback = completion
        var settings = AVCapturePhotoSettings()
        if flashOn, photoOutput.supportedFlashModes.contains(.on) {
            settings.flashMode = .on
        }
        sessionQueue.async {
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: Record video

    func startRecording(completion: @escaping (URL?) -> Void) {
        guard session.isRunning, !videoOutput.isRecording else { return }
        videoCallback = completion
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("story_\(Int(Date().timeIntervalSince1970)).mov")
        sessionQueue.async {
            self.videoOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        guard videoOutput.isRecording else { return }
        sessionQueue.async { self.videoOutput.stopRecording() }
    }

    // MARK: Delegates

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(),
              let img = UIImage(data: data) else {
            DispatchQueue.main.async { self.photoCallback?(nil) }
            return
        }
        // Mirror front camera
        let final: UIImage
        if currentPosition == .front,
           let cgImg = img.cgImage {
            final = UIImage(cgImage: cgImg, scale: img.scale, orientation: .leftMirrored)
        } else {
            final = img
        }
        DispatchQueue.main.async { self.photoCallback?(final) }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo url: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        let result: URL? = error == nil ? url : nil
        DispatchQueue.main.async { self.videoCallback?(result) }
    }
}

// MARK: - Preview Layer

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Camera View

struct StoryCameraView: View {
    var onDismiss: () -> Void

    @StateObject private var cam = StoryCameraSession()

    @State private var isRecording    = false
    @State private var recordProgress: CGFloat = 0
    @State private var recordTimer: Timer?
    @State private var elapsed: Double = 0

    @State private var previewMedia: StoryMediaItem?   // replaces capturedImage/videoURL/showPreview
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cam.isSimulator {
                // Simulator placeholder
                LinearGradient(colors: [.purple.opacity(0.7), .blue.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 52))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Simulator'da kamera\nishlamaydi")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Text("Haqiqiy iPhone'da sinab ko'ring")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                CameraPreviewLayer(session: cam.session)
                    .ignoresSafeArea()
                if !cam.isReady {
                    ProgressView().tint(.white)
                }
            }

            VStack(spacing: 0) {
                // ── Top controls ─────────────────────────────────────────
                HStack {
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white).shadow(radius: 4).padding(18)
                    }
                    Spacer()
                    Button { cam.toggleFlash() } label: {
                        Image(systemName: cam.flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white).shadow(radius: 4).padding(18)
                    }
                    Button { cam.flipCamera() } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white).shadow(radius: 4).padding(18)
                    }
                }

                // ── Recording progress ────────────────────────────────────
                if isRecording {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.25)).frame(height: 3)
                            Rectangle().fill(Color.red)
                                .frame(width: g.size.width * recordProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }

                Spacer()

                // Hint
                if !isRecording {
                    VStack(spacing: 3) {
                        Text("Bosing → rasm").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                        Text("Bosib turing → video (max 1 daqiqa)").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 10)
                } else {
                    Text(String(format: "%.0f / 60 s", elapsed))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(.bottom, 10)
                }

                // ── Bottom controls ──────────────────────────────────────
                HStack(alignment: .center, spacing: 0) {
                    // Gallery
                    PhotosPicker(selection: $pickerItem,
                                 matching: .any(of: [.images, .videos])) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 22)).foregroundColor(.white))
                    }

                    Spacer()

                    // Shutter
                    shutterButton

                    Spacer()

                    Color.clear.frame(width: 52, height: 52)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 52)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task { await loadPickerItem(item) }
        }
        .fullScreenCover(item: $previewMedia) { media in
            StoryPreviewView(
                image: media.image,
                videoURL: media.videoURL,
                onDismiss: { previewMedia = nil },
                onPosted:  { onDismiss() }
            )
        }
        .onAppear  { cam.start() }
        .onDisappear { cam.stop() }
    }

    // MARK: - Shutter button

    private var shutterButton: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 4)
                .frame(width: 84, height: 84)
            Circle()
                .fill(isRecording ? Color.red : Color.white)
                .frame(width: isRecording ? 36 : 68,
                       height: isRecording ? 36 : 68)
                .animation(.spring(response: 0.2), value: isRecording)
        }
        .gesture(
            // Long press → video
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isRecording { startVideo() }
                }
                .onEnded { _ in
                    if isRecording { stopVideo() }
                }
        )
        .simultaneousGesture(
            // Tap → photo (only if not recording)
            TapGesture().onEnded {
                guard !isRecording, cam.isReady else { return }
                takePhoto()
            }
        )
    }

    // MARK: - Actions

    private func takePhoto() {
        cam.capturePhoto { img in
            guard let img else { return }
            previewMedia = StoryMediaItem(image: img, videoURL: nil)
        }
    }

    private func startVideo() {
        guard cam.isReady, !isRecording else { return }
        isRecording     = true
        elapsed         = 0
        recordProgress  = 0
        cam.startRecording { url in
            isRecording = false
            recordTimer?.invalidate()
            recordTimer = nil
            if let url {
                previewMedia = StoryMediaItem(image: nil, videoURL: url)
            }
        }
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.elapsed += 0.1
                self.recordProgress = CGFloat(self.elapsed / 60.0)
                if self.elapsed >= 60 { self.stopVideo() }
            }
        }
    }

    private func stopVideo() {
        guard isRecording else { return }
        recordTimer?.invalidate()
        recordTimer = nil
        cam.stopRecording()
        // isRecording = false is set in the recording callback
    }

    private func loadPickerItem(_ item: PhotosPickerItem) async {
        let isVideo = item.supportedContentTypes.contains {
            $0.conforms(to: .audiovisualContent) || $0.conforms(to: .movie)
        }

        if isVideo {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("picked_\(Int(Date().timeIntervalSince1970)).mov")
                try? data.write(to: url)
                await MainActor.run {
                    previewMedia = StoryMediaItem(image: nil, videoURL: url)
                }
            }
        } else {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                return
            }

            // CGImageSource path
            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                if let cgImg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    let uiImg = UIImage(cgImage: cgImg)
                    await MainActor.run {
                        previewMedia = StoryMediaItem(image: uiImg, videoURL: nil)
                    }
                }
            } else if let img = UIImage(data: data) {
                await MainActor.run {
                    previewMedia = StoryMediaItem(image: img, videoURL: nil)
                }
            }
        }
    }
}
