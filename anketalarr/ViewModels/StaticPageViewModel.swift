import Foundation
import SwiftUI
import Combine
/// Backend'dan kelgan statik sahifa (Biz haqimizda / Foydalanish shartlari /
/// Maxfiylik siyosati) — kontent to'liq admin paneldan tahrirlanadi.
@MainActor
class StaticPageViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var version: String = ""
    @Published var content: String = ""
    @Published var links: [String] = []
    @Published var termsBanner: TermsBanner? = nil
    @Published var isLoading = false
    @Published var isAccepting = false
    @Published var errorMsg: String? = nil
    struct TermsProofMedia: Decodable {
        let type: String?
        let url: String?
        let thumbnailURL: String?
        let isFaceVerified: Bool?

        enum CodingKeys: String, CodingKey {
            case type, url
            case thumbnailURL = "thumbnail_url"
            case isFaceVerified = "is_face_verified"
        }
    }

    struct TermsBanner: Decodable {
        let isCurrentVersionAccepted: Bool
        let acceptedAt: String?
        let acceptedVersion: String?
        let proofMedia: TermsProofMedia?

        enum CodingKeys: String, CodingKey {
            case isCurrentVersionAccepted = "is_current_version_accepted"
            case acceptedAt = "accepted_at"
            case acceptedVersion = "accepted_version"
            case proofMedia = "proof_media"
        }
    }

    private struct StaticPageResponse: Decodable {
        let slug: String
        let title: String
        let version: String
        let content: String
        let links: [String]?
        let termsBanner: TermsBanner?

        enum CodingKeys: String, CodingKey {
            case slug, title, version, content, links
            case termsBanner = "terms_banner"
        }
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
        version = resp.version
        content = resp.content
        links = resp.links ?? []
        termsBanner = resp.termsBanner
        isLoading = false
    }

    func acceptCurrentTerms() async {
        guard !version.isEmpty,
              let url = URL(string: "\(APIConfig.authBase)/terms-accept/") else { return }
        isAccepting = true
        errorMsg = nil
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["terms_version": version])
        let (_, status) = await APIClient.shared.send(request)
        isAccepting = false
        if (200..<300).contains(status) {
            await load(slug: "terms")
        } else {
            errorMsg = "Shartlarni tasdiqlab bo‘lmadi"
        }
    }
}
