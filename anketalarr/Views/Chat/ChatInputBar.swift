import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import AVKit
import UniformTypeIdentifiers
import CoreLocation
import MapKit
import Combine

/// Yozish/yuborish tugmasi joriy qaysi moddada turgani — ovozli yoki video
/// xabar (Telegram/Instagram uslubidagi dual-mode tugma uchun). Bu holat
/// FAQAT shu komponent ichida ishlatiladi — parent bilan ulashilmaydi.
private enum RecordMode {
    case voice, video
}

/// Suhbat oynasining pastki kiritish paneli — matn yozish, rasm/video
/// biriktirish, lokatsiya yuborish va bosib-turib ovozli/video xabar
/// yozib yuborish.
///
/// Yozish jarayonining ichki holati (`recordMode`, bosib-turish gesture
/// boshqaruvi — `pressTask`/`didBeginRecording`) butunlay shu komponentga
/// TEGISHLI: `ChatConversationView` bu holatdan umuman xabardor emas, faqat
/// tugallangan natija `vm.sendVoice`/`vm.sendVideo` orqali ViewModel'ga
/// (demak — serverga) chiqib ketadi.
struct ChatInputBar: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var lang: LocalizationManager
    @EnvironmentObject var paywallGate: PaywallGate
    @ObservedObject var vm: ChatRoomViewModel
    @ObservedObject var recorder: VoiceRecorder
    @ObservedObject var videoRecorder: VideoRecorder
    @ObservedObject var locationManager: LocationManager

    @Binding var draft: String
    @Binding var editingMessage: ChatMessage?
    @Binding var galleryItem: PhotosPickerItem?
    var isLoadingVideo: Bool
    @Binding var awaitingLocationSend: Bool
    var inputFocused: FocusState<Bool>.Binding

    @State private var recordMode: RecordMode = .voice
    @State private var pressTask: Task<Void, Never>? = nil
    @State private var didBeginRecording = false

    var body: some View {
        VStack(spacing: 0) {
            if let err = vm.voiceError {
                voiceErrorBanner(err)
            }
            mainInputRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .padding(.bottom, 4)
        .background(Color(.systemBackground))
    }

    private var isRecordingAny: Bool { recorder.isRecording || videoRecorder.isRecording }

    private func voiceErrorBanner(_ text: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
            Text(text).font(.system(size: 12.5)).foregroundColor(theme.textSecondary)
            Spacer()
            // Ovozli/video xabar Premium/VIP talab qilgani uchun rad etilganda
            // (qarang ChatRoomViewModel+Send.swift — mediaGated) shu yerdan
            // to'g'ridan-to'g'ri Obuna sahifasiga o'tish imkonini beramiz.
            Button { paywallGate.present() } label: {
                Text(lang[.vipReqBtn])
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.primary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    /// Rasm va video endi bitta tugma — bosilganda to'g'ridan-to'g'ri galereya
    /// ochiladi (submenyusiz), tanlangan elementning turiga qarab avtomatik
    /// rasm yoki video sifatida yuboriladi (parentdagi onChange(of: galleryItem)).
    private var galleryButton: some View {
        PhotosPicker(selection: $galleryItem, matching: .any(of: [.images, .videos])) {
            if isLoadingVideo {
                ProgressView().frame(width: 23, height: 23)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 22))
                    .foregroundColor(theme.primary)
            }
        }
        .disabled(isLoadingVideo)
    }

    /// Lokatsiya yuborish tugmasi — bosilganda joriy GPS koordinata xabar
    /// sifatida yuboriladi (haqiqiy yuborish — parentdagi onReceive(location)).
    private var locationButton: some View {
        Button {
            awaitingLocationSend = true
            locationManager.requestLocation()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundColor(theme.primary)
        }
        .frame(width: 30, height: 30)
    }

    /// Asosiy kiritish qatori — chap tomoni holatga qarab almashadi ("+"
    /// biriktirish/matn maydoni ↔ bekor qilish/yozilayotgani haqida ma'lumot),
    /// LEKIN eng o'ng tomondagi yozish/yuborish tugmasi DOIM bir xil joyda,
    /// uzilmasdan qoladi (bosib-turish gesture'i daraxtdan olib tashlanmasligi
    /// uchun — aks holda SwiftUI gesture'ni bekor qiladi).
    private var mainInputRow: some View {
        HStack(spacing: 10) {
            if isRecordingAny {
                Button { cancelActiveRecording() } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(theme.textSecondary)
                }
                recordingInfoRow
            } else if editingMessage != nil {
                textField
            } else {
                galleryButton
                textField
                locationButton
            }
            recordOrSendButton
        }
    }

    private var textField: some View {
        TextField(lang[.chatInputPlaceholder], text: $draft, axis: .vertical)
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .focused(inputFocused)
            .lineLimit(1...4)
            .onChange(of: draft) { _, _ in vm.userIsTyping() }
    }

    /// Eng o'ngdagi tugma: tahrirlash rejimida — saqlash (✓); matn yozilgan
    /// bo'lsa — matn yuborish o'qi; aks holda — mikrofon/video bosib-turib-
    /// yozish tugmasi (`recordToggleButton`).
    @ViewBuilder
    private var recordOrSendButton: some View {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editing = editingMessage {
            // Tahrirlash rejimida o'q o'rniga "saqlash" (✓) tugmasi — bosilganda
            // shu Message qatorining matni serverda yangilanadi (yangi xabar
            // YARATILMAYDI, eskisi ham o'chirilmaydi).
            Button {
                let id = editing.id
                let text = draft
                editingMessage = nil
                draft = ""
                Task { await vm.editMessage(id, content: text) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(theme.primary)
            }
            .disabled(trimmed.isEmpty)
        } else if !isRecordingAny && !trimmed.isEmpty {
            Button {
                let text = draft
                draft = ""
                Task { await vm.sendText(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(theme.primary)
            }
            .disabled(vm.isSending)
        } else {
            recordToggleButton
        }
    }

    /// Telegram/Instagram uslubidagi dual-mode tugma: bitta (qisqa) bosish
    /// mikrofon ↔ video o'rtasida almashtiradi; bosib turish joriy moddada
    /// yozishni boshlaydi, qo'yib yuborilganda esa yozilganini yuboradi.
    /// `Button` EMAS — chunki o'zining standart bosish ishorasi maxsus
    /// bosib-turish/tez-bosish farqlash mantig'imiz bilan to'qnashardi.
    private var recordToggleButton: some View {
        Image(systemName: recordMode == .voice ? "mic.fill" : "video.fill")
            .font(.system(size: 21))
            .foregroundColor(theme.primary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .opacity(vm.isSending ? 0.4 : 1)
            .scaleEffect(isRecordingAny ? 1.15 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isRecordingAny)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !vm.isSending, pressTask == nil, !didBeginRecording else { return }
                        // Qisqa bosishni ("mode almashtirish") yozishni
                        // boshlashdan ("bosib turish") ajratish uchun — 0.15
                        // soniyadan kam bosishlar yozishni umuman boshlamaydi.
                        pressTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            guard !Task.isCancelled else { return }
                            didBeginRecording = true
                            beginRecording()
                        }
                    }
                    .onEnded { _ in
                        pressTask?.cancel()
                        pressTask = nil
                        if didBeginRecording {
                            didBeginRecording = false
                            finishAndSendRecording()
                        } else {
                            toggleRecordMode()
                        }
                    }
            )
    }

    /// Yozilayotgan paytdagi ma'lumot qatori — ovoz uchun pulsatsiyalanuvchi
    /// nuqta, video uchun esa jonli kamera ko'rinishi (kichik doirada) + ikkisi
    /// uchun ham umumiy davomiylik hisoblagichi.
    @ViewBuilder
    private var recordingInfoRow: some View {
        HStack(spacing: 8) {
            if recordMode == .video {
                CameraPreviewView(session: videoRecorder.session)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                PulsingDot()
            }
            Text(recordMode == .voice ? lang[.chatVoiceRecording] : lang[.chatVideoRecording])
                .font(.system(size: 13))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(formatDuration(recordMode == .voice ? recorder.duration : videoRecorder.duration))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func beginRecording() {
        switch recordMode {
        case .voice: recorder.start()
        case .video: videoRecorder.start()
        }
    }

    private func finishAndSendRecording() {
        switch recordMode {
        case .voice:
            // To'xtatishdan OLDIN o'qib olamiz — `stopAndFinish()` ichida
            // qiymat o'zgartirilmaydi, lekin kelajakda ham ishonchli bo'lishi
            // uchun aynan to'xtatilayotgan zahotidagi haqiqiy uzunlikni olamiz.
            let dur = recorder.duration
            if let data = recorder.stopAndFinish() {
                Task { await vm.sendVoice(data, duration: dur) }
            }
        case .video:
            Task {
                if let data = await videoRecorder.stopAndFinish() {
                    await vm.sendVideoNote(data)
                }
            }
        }
    }

    private func cancelActiveRecording() {
        recorder.cancel()
        videoRecorder.cancel()
    }

    private func toggleRecordMode() {
        recordMode = (recordMode == .voice) ? .video : .voice
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
