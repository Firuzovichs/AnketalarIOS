import SwiftUI
import Combine
/// Ilova bo'ylab BARCHA "Premium kerak" joylarini bitta umumiy Obuna
/// sahifasiga (`SubscriptionView`) yo'naltirish uchun ishlatiladigan umumiy
/// "darvoza". Eski har xil kichik popup/karta (masalan `VipPaywallCard`)
/// o'rniga endi har bir joyda shunchaki `paywallGate.present()` chaqiriladi.
///
/// `MainTabView` darajasida bitta nusxa yaratiladi va `.environmentObject()`
/// orqali butun autentifikatsiyadan o'tgan daraxtga uzatiladi (qarang
/// `MainTabView.swift`). Ko'pchilik joylar haqiqiy modal emas (DetailOverlay —
/// bir xil ekrandagi overlay), shuning uchun bitta `.fullScreenCover` yetarli;
/// faqat `ChatConversationView` (allaqachon o'zi boshqa fullScreenCover orqali
/// ko'rsatilgan) uchun alohida, ikkinchi `.fullScreenCover` qo'shiladi — bu
/// ikkisi bir xil `isPresented`ga bog'langani uchun ziddiyat yo'q (faqat
/// bittasi — ekranda qaysi daraxt faol bo'lsa, shu — chiqadi).
@MainActor
final class PaywallGate: ObservableObject {
    @Published var isPresented = false

    func present() {
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }
}
