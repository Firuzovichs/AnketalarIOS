import Foundation
import AVFoundation
import Combine
/// Telegram/Instagram uslubidagi "instant video xabar" yozish uchun yordamchi —
/// `VoiceRecorder`'ga o'xshash API (`start()` / `stopAndFinish()` / `cancel()`),
/// lekin past darajadagi `AVCaptureSession` orqali ishlaydi (oldindan tayyor
/// `UIImagePickerController(sourceType: .camera)` ATAYLAB ishlatilmadi — u alohida
/// to'liq ekran tizim kamera UI'sini ochib, o'zining alohida "bosish" tugmasini
/// talab qiladi, bu esa so'ralgan "tugmani bosib turib yozish" tajribasiga to'g'ri
/// kelmaydi). `session` xususiyati orqali jonli kamera ko'rinishini (preview)
/// chiqarish mumkin (pastga, `CameraPreviewView`'ga qarang).
@MainActor
final class VideoRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var permissionDenied = false

    let session = AVCaptureSession()

    private let movieOutput = AVCaptureMovieFileOutput()
    private var timer: Timer?
    private var fileURL: URL?
    private var sessionConfigured = false
    private var finishContinuation: CheckedContinuation<URL?, Never>?

    /// Kamera + mikrofon ruxsatlarini so'raydi va ruxsat berilsa yozishni boshlaydi.
    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                Task { @MainActor in
                    guard let self else { return }
                    guard videoGranted, audioGranted else {
                        self.permissionDenied = true
                        return
                    }
                    self.beginRecording()
                }
            }
        }
    }

    private func configureSessionIfNeeded() -> Bool {
        guard !sessionConfigured else { return true }
        session.beginConfiguration()
        session.sessionPreset = .medium

        // Old kamera — Telegram/Instagramning "instant video xabar"i kabi
        // odatda foydalanuvchi o'zini suratga oladi.
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video),
              let cameraInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(cameraInput) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(cameraInput)

        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        guard session.canAddOutput(movieOutput) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(movieOutput)
        if let connection = movieOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90 // portret — telefon tik turganda to'g'ri ko'rinish
        }
        session.commitConfiguration()
        sessionConfigured = true
        return true
    }

    private func beginRecording() {
        guard configureSessionIfNeeded() else { return }

        if !session.isRunning {
            Task.detached(priority: .userInitiated) { [session] in
                session.startRunning()
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        fileURL = url
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        duration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.duration += 0.1
            }
        }
    }

    /// Yozishni to'xtatadi va yozilgan video Data'sini qaytaradi. Juda qisqa
    /// (1 soniyadan kam) bo'lsa — bu ehtimol tasodifiy bosish, nil qaytariladi.
    func stopAndFinish() async -> Data? {
        guard isRecording else { return nil }
        timer?.invalidate()
        timer = nil
        isRecording = false

        let finishedURL: URL? = await withCheckedContinuation { continuation in
            self.finishContinuation = continuation
            self.movieOutput.stopRecording()
        }
        stopSession()

        guard let finishedURL, duration >= 1.0 else {
            if let finishedURL { try? FileManager.default.removeItem(at: finishedURL) }
            fileURL = nil
            return nil
        }
        let data = try? Data(contentsOf: finishedURL)
        try? FileManager.default.removeItem(at: finishedURL)
        fileURL = nil
        return data
    }

    /// Yozishni bekor qiladi — vaqtinchalik fayl o'chiriladi, hech narsa yuborilmaydi.
    func cancel() {
        guard isRecording else { return }
        timer?.invalidate()
        timer = nil
        isRecording = false
        movieOutput.stopRecording()
        stopSession()
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
        duration = 0
    }

    private func stopSession() {
        guard session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
        }
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.finishContinuation?.resume(returning: error == nil ? outputFileURL : nil)
            self.finishContinuation = nil
        }
    }
}
