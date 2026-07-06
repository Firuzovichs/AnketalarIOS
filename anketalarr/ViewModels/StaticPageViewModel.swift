import Foundation
import SwiftUI
import Combine
/// Backend'dan kelgan statik sahifa (Biz haqimizda / Foydalanish shartlari /
/// Maxfiylik siyosati) — kontent to'liq admin paneldan tahrirlanadi.
@MainActor
class StaticPageViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var isLoading = false
    @Published var errorMsg: String? = nil
    private struct StaticPageResponse: Decodable {
        let slug: String
        let title: String
        let content: String
    }

    func load(slug: String) async {
        isLoading = true
        errorMsg = nil

        guard let data = await APIClient.shared.getData("\(APIConfig.base)/home/pages/\(slug)/"),
              let resp = try? JSONDecoder().decode(StaticPageResponse.self, from: data) else {
            isLoading = false
            errorMsg = LocalizationManager.get(.staticPageLoadError)
            return
        }

        title = resp.title
        content = resp.content
        isLoading = false
    }
}
