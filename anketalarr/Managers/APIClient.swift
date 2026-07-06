import Foundation

// MARK: - Singleton HTTP client
// Barcha authenticated so'rovlar shu orqali o'tadi.
// 401 kelsa → refresh token bilan yangi access token oladi va so'rovni qayta bajaradi.
// Refresh ham muvaffaqiyatsiz bo'lsa → tokenlarni o'chiradi (RootView login sahifasiga o'tadi).

actor APIClient {
    static let shared = APIClient()
    private init() {}
    /// Concurrent refresh uchun bitta task — ikkinchi 401 refresh bo'lishini kutadi
    private var refreshTask: Task<Bool, Never>? = nil

    // MARK: - GET

    func getData(_ urlStr: String) async -> Data? {
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 10
        let (data, _) = await sendWithAuth(req)
        return data
    }

    // MARK: - Generic authenticated request
    // URLRequest ni Authorization headerisiz yuboring — bu metod o'zi qo'shadi.
    // Returns: (responseData?, httpStatusCode)

    func send(_ req: URLRequest) async -> (Data?, Int) {
        return await sendWithAuth(req)
    }

    // MARK: - Core

    private func sendWithAuth(_ req: URLRequest) async -> (Data?, Int) {
        var authReq = req
        authReq.setValue("Bearer \(currentAccessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: authReq),
              let http = response as? HTTPURLResponse else { return (nil, 0) }

        // Muvaffaqiyatli yoki boshqa xato — qaytaramiz
        guard http.statusCode == 401 else { return (data, http.statusCode) }

        // 401 → refresh urinib ko'ramiz
        let refreshed = await ensureRefresh()

        guard refreshed else {
            // Refresh token yo'q yoki muddati tugagan — logout
            triggerLogout()
            return (nil, 401)
        }

        // Yangi token bilan qayta urinamiz
        var retried = req
        retried.setValue("Bearer \(currentAccessToken)", forHTTPHeaderField: "Authorization")

        guard let (data2, response2) = try? await URLSession.shared.data(for: retried),
              let http2 = response2 as? HTTPURLResponse else { return (nil, 0) }

        if http2.statusCode == 401 {
            // Yangi token bilan ham 401 — sessiya muddati tugagan, logout
            triggerLogout()
            return (nil, 401)
        }

        return (data2, http2.statusCode)
    }

    // MARK: - Refresh coordination
    // Bir vaqtda bir nechta 401 kelsa — birinchisi refresh qiladi, qolganlar kutadi

    private func ensureRefresh() async -> Bool {
        if let existing = refreshTask {
            return await existing.value
        }
        let task = Task<Bool, Never> {
            let result = await self.performRefresh()
            await self.clearRefreshTask()
            return result
        }
        refreshTask = task
        return await task.value
    }

    private func clearRefreshTask() {
        refreshTask = nil
    }

    private func performRefresh() async -> Bool {
        let rt = UserDefaults.standard.string(forKey: "refresh_token") ?? ""
        guard !rt.isEmpty else { return false }

        guard let url = URL(string: "\(APIConfig.authBase)/token/refresh/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh": rt])
        req.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccess = json["access"] as? String
        else { return false }

        UserDefaults.standard.set(newAccess, forKey: "access_token")
        if let newRefresh = json["refresh"] as? String {
            UserDefaults.standard.set(newRefresh, forKey: "refresh_token")
        }
        return true
    }

    // MARK: - Helpers

    private var currentAccessToken: String {
        UserDefaults.standard.string(forKey: "access_token") ?? ""
    }

    /// Tokenlarni o'chiradi → @AppStorage("access_token") kuzatib turgan RootView
    /// avtomatik LoginView ga o'tadi
    private func triggerLogout() {
        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: "access_token")
            UserDefaults.standard.removeObject(forKey: "refresh_token")
        }
    }
}
