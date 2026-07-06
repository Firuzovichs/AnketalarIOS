import Foundation
import StoreKit

/// Apple StoreKit2 bilan bevosita ishlaydigan qatlam. MUHIM: bu klass HECH
/// QACHON xaridni o'zi "tasdiqlangan" deb hisoblamaydi — u faqat Apple
/// imzolagan tranzaksiyani (`jwsRepresentation`, ya'ni "signed transaction")
/// backendga uzatadi; haqiqiy tekshirish to'liq server-tomonda bo'ladi
/// (qarang backend/apps/subscriptions/apple_verify.py — Apple'ning rasmiy
/// `app-store-server-library` kutubxonasi orqali).
@MainActor
final class SubscriptionManager {
    enum PurchaseOutcome {
        case success(jws: String)
        case userCancelled
        case pending
    }

    enum SubscriptionError: Error {
        case unverified
    }

    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    /// Foydalanuvchi ilova ichida emas (masalan boshqa qurilmada uzaytirgan
    /// yoki Family Sharing orqali kelgan) tranzaksiyalarni orqa fonda
    /// kuzatib, backendga avtomatik yuboradi.
    func startTransactionListener(onUpdate: @escaping @Sendable (String) async -> Void) {
        updatesTask?.cancel()
        updatesTask = Task.detached {
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await onUpdate(update.jwsRepresentation)
                await transaction.finish()
            }
        }
    }

    /// Berilgan mahsulot identifikatorlari bo'yicha App Store'dan mahsulot
    /// ma'lumotini (narx, nom) yuklaydi. Hali Connectda yaratilmagan
    /// (bo'sh `apple_product_id`) tariflar chaqiruvchi tomonidan oldindan
    /// filtrlanadi — bu metod faqat haqiqiy ID'larni qabul qiladi.
    func loadProducts(ids: [String]) async -> [Product] {
        guard !ids.isEmpty else { return [] }
        do {
            return try await Product.products(for: ids)
        } catch {
            return []
        }
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                let jws = verification.jwsRepresentation
                await transaction.finish()
                return .success(jws: jws)
            case .unverified:
                throw SubscriptionError.unverified
            }
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    /// Foydalanuvchining hozirgi faol tranzaksiyalarini App Store bilan
    /// sinxronlab (masalan ilovani o'chirib-qayta o'rnatgandan keyin),
    /// ularning JWS satrlarini backendga qayta yuborish uchun to'playdi.
    func restorePurchases() async throws -> [String] {
        try await AppStore.sync()
        var jwsList: [String] = []
        for await result in Transaction.currentEntitlements {
            if case .verified = result {
                jwsList.append(result.jwsRepresentation)
            }
        }
        return jwsList
    }
}
