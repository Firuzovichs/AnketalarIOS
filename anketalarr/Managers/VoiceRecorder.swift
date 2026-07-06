import Foundation
import AVFoundation
import Combine
/// Ovozli xabar yozish uchun yordamchi: yozishni boshlash, to'xtatish (yuborish
/// uchun Data qaytaradi) va bekor qilish (faylni o'chirib, hech narsa yubormaydi).
/// AAC/.m4a formatida vaqtinchalik faylga yozadi — backend buni `message_type=voice`
/// sifatida qabul qiladi (apps/chat/views.py SendMessageView).
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?

    /// Mikrofon ruxsatini so'raydi va ruxsat berilsa yozishni boshlaydi.
    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.permissionDenied = true
                    return
                }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.delegate = self
            rec.record()
            recorder = rec
            fileURL = url
            isRecording = true
            duration = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let r = self.recorder else { return }
                    self.duration = r.currentTime
                }
            }
        } catch {
            fileURL = nil
        }
    }

    /// Yozishni to'xtatadi va yozilgan audio Data'sini qaytaradi. Juda qisqa
    /// (1 soniyadan kam) bo'lsa — bu ehtimol tasodifiy bosish, nil qaytariladi.
    func stopAndFinish() -> Data? {
        guard isRecording else { return nil }
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)

        guard let url = fileURL, duration >= 1.0 else {
            if let url = fileURL { try? FileManager.default.removeItem(at: url) }
            fileURL = nil
            return nil
        }
        let data = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        fileURL = nil
        return data
    }

    /// Yozishni bekor qiladi — vaqtinchalik fayl o'chiriladi, hech narsa yuborilmaydi.
    func cancel() {
        guard isRecording else { return }
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
        duration = 0
    }
}

extension VoiceRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {}
}
