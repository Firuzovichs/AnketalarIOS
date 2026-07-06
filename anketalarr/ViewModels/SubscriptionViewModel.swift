import Foundation
import StoreKit
import Combine
// MARK: - Models
// Backend: apps/subscriptions/serializers.py — PlanSerializer/UserSubscriptionSerializer.
// MUHIM: `price_monthly` backendda DecimalField — DRF buni JSON STRING sifatida
// qaytaradi (raqam emas), shuning uchun bu yerda String sifatida o'qiladi.

struct SubPlan: Identifiable, Decodable, Equatable {
    let id: Int
    let plan_type: String
    let name: String
    let price_monthly: String
    let likes_per_day: Int
    let super_likes_per_day: Int
    let can_see_who_liked: Bool
    let can_use_radius_filter: Bool
    let can_send_voice: Bool
    let can_send_video_msg: Bool
    let can_boost_profile: Bool
    let can_see_story_analytics: Bool
    let stories_per_day: Int
    let ad_free: Bool
    let chat_duration_days: Int
    let apple_product_id: String

    var isFree: Bool { plan_type == "free" }

    /// Apple App Store Connect'da hali yaratilmagan (admin panelda
    /// `apple_product_id` bo'sh qoldirilgan) tarif — hozircha xarid qilib
    /// bo'lmaydi, faqat "Tez kunda" deb ko'rsatiladi. Mahsulot keyinroq
    /// Connectda yaratilib shu maydon to'ldirilganda, kodga tegmasdan
    /// avtomatik sotiladigan bo'lib qoladi.
    var isPurchasable: Bool { !isFree && !apple_product_id.isEmpty }
}

struct MySubscription: Decodable {
    let plan: SubPlan
    let started_at: String?
    let expires_at: String?
    let is_active: Bool
}

private struct VerifyErrorBody: Decodable {
    let code: String?
    let detail: String?
}

// MARK: - ViewModel

@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var plans: [SubPlan] = []
    @Published var mySubscription: MySubscription?
    @Published var storeProducts: [String: Product] = [:]   // apple_product_id -> Product
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var errorText: String?
    @Published var purchaseSucceeded = false

    private let store = SubscriptionManager()
    private var listenerStarted = false

    var currentPlanType: String { mySubscription?.plan.plan_type ?? "free" }

    /// `MainTabView` ochilganda bir marta chaqiriladi — orqa fonda Apple'dan
    /// kelgan (masalan boshqa qurilmada yangilangan) tranzaksiyalarni
    /// tinglashni boshlaydi va boshlang'ich ma'lumotlarni yuklaydi.
    func start() {
        if !listenerStarted {
            listenerStarted = true
            store.startTransactionListener { [weak self] jws in
                await self?.verify(jws: jws, silent: true)
            }
        }
        Task { await loadAll() }
    }

    func loadAll() async {
        isLoading = true
        async let plansLoaded: () = fetchPlans()
        async let mineLoaded: () = fetchMine()
        _ = await (plansLoaded, mineLoaded)
        await loadStoreProducts()
        isLoading = false
    }

    private func fetchPlans() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/subscriptions/plans/") else { return }
        if let decoded = try? JSONDecoder().decode([SubPlan].self, from: data) {
            plans = decoded
        }
    }

    func fetchMine() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/subscriptions/mine/") else { return }
        if let decoded = try? JSONDecoder().decode(MySubscription.self, from: data) {
            mySubscription = decoded
        }
    }

    private func loadStoreProducts() async {
        let ids = plans.map(\.apple_product_id).filter { !$0.isEmpty }
        guard !ids.isEmpty else { return }
        let loaded = await store.loadProducts(ids: ids)
        for product in loaded {
            storeProducts[product.id] = product
        }
    }

    /// Foydalanuvchiga ko'rsatiladigan narx matni — Apple mahsuloti mavjud
    /// bo'lsa App Store'ning o'zi bergan (mahalliy valyutadagi) narxi
    /// ko'rsatiladi; hali yaratilmagan bo'lsa "Tez kunda" deyiladi.
    func priceText(for plan: SubPlan) -> String {
        if let product = storeProducts[plan.apple_product_id] {
            return product.displayPrice
        }
        return LocalizationManager.get(.subComingSoon)
    }

    func isCurrentPlan(_ plan: SubPlan) -> Bool {
        plan.plan_type == currentPlanType
    }

    func subscribe(to plan: SubPlan) async {
        guard plan.isPurchasable, let product = storeProducts[plan.apple_product_id] else { return }
        errorText = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let outcome = try await store.purchase(product)
            switch outcome {
            case .success(let jws):
                await verify(jws: jws, silent: false)
            case .userCancelled, .pending:
                break
            }
        } catch {
            errorText = LocalizationManager.get(.subPurchaseFailedTitle)
        }
    }

    func restore() async {
        errorText = nil
        isRestoring = true
        defer { isRestoring = false }
        do {
            let jwsList = try await store.restorePurchases()
            guard !jwsList.isEmpty else {
                errorText = LocalizationManager.get(.subRestoreNoneTitle)
                return
            }
            var anySucceeded = false
            for jws in jwsList {
                if await verify(jws: jws, silent: true) { anySucceeded = true }
            }
            if !anySucceeded {
                errorText = LocalizationManager.get(.subRestoreNoneTitle)
            } else {
                purchaseSucceeded = true
            }
        } catch {
            errorText = LocalizationManager.get(.subPurchaseFailedTitle)
        }
    }

    /// `signed_transaction`ni backendga yuborib, Apple'ning rasmiy server
    /// kutubxonasi orqali TO'LIQ server-tomonda tekshirilishini kutadi.
    /// `silent`: true bo'lsa (orqa fon listeneri/restore) — xato bo'lsa ham
    /// foydalanuvchiga alert ko'rsatilmaydi, faqat jim qaytariladi.
    @discardableResult
    private func verify(jws: String, silent: Bool) async -> Bool {
        guard let url = URL(string: "\(APIConfig.base)/subscriptions/verify-purchase/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["signed_transaction": jws])

        let (data, status) = await APIClient.shared.send(req)
        guard (200..<300).contains(status) else {
            if !silent, let data {
                let body = try? JSONDecoder().decode(VerifyErrorBody.self, from: data)
                errorText = LocalizationManager.errorText(code: body?.code, detail: body?.detail)
            }
            return false
        }
        if let data, let decoded = try? JSONDecoder().decode(MySubscription.self, from: data) {
            mySubscription = decoded
            if !silent { purchaseSucceeded = true }
            return true
        }
        // Backend `{detail: "OK"}` qaytargan kamdan-kam holat (subscription
        // hali yaratilmagan) — joriy holatni qayta so'raymiz.
        await fetchMine()
        return true
    }
}
