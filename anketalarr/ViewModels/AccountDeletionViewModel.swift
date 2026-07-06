import Foundation
import SwiftUI
import Combine
/// Hisobni o'chirish so'rovi. MUHIM: bu faqat backendga so'rov yuboradi —
/// hisob mahalliy yoki serverda hech qachon shu yerdan o'chirilmaydi.
/// Admin panelda tasdiqlangach, backend `user.is_active=False` qiladi va
/// foydalanuvchi shunchaki login qila olmaydi (LoginView allaqachon shu
/// maydonni tekshiradi).
@MainActor
class AccountDeletionViewModel: ObservableObject {
    @Published var status: String? = nil   // nil | "pending" | "approved" | "rejected"
    @Published var isLoading = false
    @Published var errorMsg: String? = nil
    private struct StatusResponse: Decodable { let status: String? }

    var isPending: Bool { status == "pending" }

    func fetchStatus() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.authBase)/account/delete-request/"),
              let resp = try? JSONDecoder().decode(StatusResponse.self, from: data) else { return }
        status = resp.status
    }

    func sendRequest() async {
        guard !isLoading else { return }
        isLoading = true
        errorMsg = nil

        guard let url = URL(string: "\(APIConfig.authBase)/account/delete-request/") else {
            isLoading = false
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [String: String]())

        let (data, code) = await APIClient.shared.send(req)
        isLoading = false

        guard (200..<300).contains(code), let data,
              let resp = try? JSONDecoder().decode(StatusResponse.self, from: data) else {
            errorMsg = LocalizationManager.get(.errOccurred)
            return
        }
        status = resp.status ?? "pending"
    }
}
