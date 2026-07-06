import Foundation

#if canImport(YandexMapsMobile)
import YandexMapsMobile

/// Yandex MapKit Mobile SDK sozlamalari.
///
/// API KEY OLISH (bir martalik, qo'lda qilinadi):
/// 1. https://developer.tech.yandex.ru ga kiring (Yandex hisobingiz bilan).
/// 2. "Подключить API" / "API ulash" tugmasini bosing.
/// 3. "MapKit Mobile SDK" ni tanlang, loyiha nomini kiriting.
/// 4. Tariflardan birini tanlang (bepul "Free" tarif kichik loyihalar uchun yetarli).
/// 5. Kalit "API Interfaces" bo'limida paydo bo'ladi (faollashishi ~15 daqiqa vaqt oladi).
/// 6. Quyidagi `apiKey` qiymatini olingan kalit bilan almashtiring.
enum YandexMapConfig {
    static let apiKey = "e3da590f-6acc-4b5a-89c8-a029579af162"

    private static var didSetup = false

    /// Ilova ishga tushganda bir marta chaqiriladi (AnketalarApp.init ichida).
    static func setupIfNeeded() {
        guard !didSetup else { return }
        didSetup = true
        YMKMapKit.setApiKey(apiKey)
        _ = YMKMapKit.sharedInstance()
    }
}
#endif
