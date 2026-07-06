import SwiftUI
import UIKit

/// Galereyadan rasm tanlangandan keyin chiqadigan tasdiqlash ekrani.
///
/// Ikki yo'l bilan yuborish mumkin:
/// 1. Pastdagi yuborish tugmasi — ODDIY rasm xabari sifatida darhol yuboradi.
/// 2. O'ng yuqori burchakdagi taymer tugmasi — ko'rinish davomiyligini
///    (3/5/10s) tanlash menyusini ochadi; davomiylik TANLANGAN ZAHOTI
///    (qo'shimcha tasdiqlash kerak emas) "o'chib ketadigan rasm" sifatida
///    yuboriladi.
///
/// Bekor qilish (X tugmasi) hech narsa yubormaydi — rasm faqat shu ekranda
/// vaqtincha (xotirada) turadi, biror joyga saqlanmaydi.
struct ImageSendPreviewView: View {
    let image: UIImage
    var onCancel: () -> Void
    var onSendNormal: () -> Void
    var onSendDisappearing: (Int) -> Void

    @State private var showDurationPicker = false
    @State private var isSending = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 4)

            VStack {
                HStack {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    Spacer()
                    // Taymer tugmasi — bosilganda davomiylik tanlash menyusi ochiladi,
                    // tanlangan zahoti o'chib ketadigan rasm sifatida yuboriladi.
                    Button { showDurationPicker = true } label: {
                        Image(systemName: "timer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .disabled(isSending)
                }
                .padding(.top, 54)
                .padding(.horizontal, 16)

                Spacer()

                HStack {
                    Spacer()
                    Button {
                        guard !isSending else { return }
                        isSending = true
                        onSendNormal()
                    } label: {
                        if isSending {
                            ProgressView().tint(.white)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Color.blue))
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Color.blue))
                        }
                    }
                    .disabled(isSending)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
            }
        }
        .statusBarHidden()
        .confirmationDialog(
            LocalizationManager.get(.chatDisappearingPickerTitle),
            isPresented: $showDurationPicker,
            titleVisibility: .visible
        ) {
            Button(LocalizationManager.get(.chatDisappearing3s)) { sendDisappearing(3) }
            Button(LocalizationManager.get(.chatDisappearing5s)) { sendDisappearing(5) }
            Button(LocalizationManager.get(.chatDisappearing10s)) { sendDisappearing(10) }
            Button(LocalizationManager.get(.cancel), role: .cancel) {}
        }
    }

    private func sendDisappearing(_ seconds: Int) {
        guard !isSending else { return }
        isSending = true
        onSendDisappearing(seconds)
    }
}

/// Galereyadan tanlangan, hali yuborilmagan rasm — `ImageSendPreviewView`ni
/// `fullScreenCover(item:)` orqali ko'rsatish uchun (Identifiable talab qilinadi).
struct PendingPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let image: UIImage
}
