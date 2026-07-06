import Foundation
import SwiftUI
import Combine

// MARK: - Upload result

struct StoryUploadResult: Decodable {
    let id: Int
    let media: String?
    let media_type: String?
}

// MARK: - Viewer model

struct StoryViewer: Identifiable, Decodable {
    let id: Int
    let viewer: DashUser?
    let viewed_at: String?
    let reaction: String?

    var formattedTime: String {
        guard let raw = viewed_at else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: raw) ?? {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
            return f.date(from: raw)
        }() else { return "" }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 3600 { return "\(diff / 60) \(LocalizationManager.get(.storyMinutes))" }
        if diff < 86400 { return "\(diff / 3600) \(LocalizationManager.get(.storyHours))" }
        return "\(diff / 86400) \(LocalizationManager.get(.storyDays))"
    }
}

// MARK: - ViewModel

@MainActor
class StoryViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var uploadError: String? = nil
    @Published var uploadSuccess = false
    // Upload photo story
    func uploadPhoto(_ image: UIImage, visibility: String = "liked_only") async {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        isUploading = true
        uploadError = nil

        let result = await multipart(
            url: "\(APIConfig.base)/stories/",
            fileData: data,
            fileName: "story.jpg",
            mimeType: "image/jpeg",
            fields: ["media_type": "image", "caption": ""]
        )
        isUploading = false
        if let result {
            // 400 bo'lsa ham result keladi — JSON decode orqali tekshiramiz
            if let json = try? JSONSerialization.jsonObject(with: result) as? [String: Any],
               json["id"] != nil {
                uploadSuccess = false
                uploadSuccess = true
            } else {
                let body = String(data: result, encoding: .utf8) ?? "unknown"
                uploadError = "Server xatosi: \(body)"
            }
        } else {
            uploadError = "Server bilan aloqa yo'q"
        }
    }

    // Upload video story
    func uploadVideo(url: URL, visibility: String = "liked_only") async {
        guard let data = try? Data(contentsOf: url) else {
            uploadError = "Video fayl o'qilmadi"; return
        }
        isUploading = true
        uploadError = nil

        let result = await multipart(
            url: "\(APIConfig.base)/stories/",
            fileData: data,
            fileName: "story.mov",
            mimeType: "video/quicktime",
            fields: ["media_type": "video", "caption": ""]
        )
        isUploading = false
        if result != nil {
            uploadSuccess = false
            uploadSuccess = true
        } else {
            uploadError = "Yuklashda xatolik. Backend'ni tekshiring."
        }
    }

    // React to story
    func react(storyId: Int, reaction: String = "heart") async {
        guard let reqURL = URL(string: "\(APIConfig.base)/stories/\(storyId)/react/") else { return }
        var req = URLRequest(url: reqURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["sticker": reaction])
        _ = await APIClient.shared.send(req)
    }

    // Storyga javob yozish — bu chatga "story_reply" turidagi maxsus xabar
    // bo'lib boradi (Instagram'dagi "reply to story" kabi). Server yaratgan
    // Message'ni to'liq qaytaradi — shu orqali chat ro'yxati/oynasi kerak
    // bo'lsa darhol yangilanishi mumkin.
    func sendReply(storyId: Int, text: String) async -> ChatMessage? {
        guard let reqURL = URL(string: "\(APIConfig.base)/stories/\(storyId)/reply/") else { return nil }
        var req = URLRequest(url: reqURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])
        let (data, status) = await APIClient.shared.send(req)
        guard status == 201, let data else { return nil }
        return try? JSONDecoder().decode(ChatMessage.self, from: data)
    }

    // Mark story as viewed
    func markViewed(storyId: Int) async {
        guard let reqURL = URL(string: "\(APIConfig.base)/stories/\(storyId)/view/") else { return }
        var req = URLRequest(url: reqURL)
        req.httpMethod = "POST"
        _ = await APIClient.shared.send(req)
    }

    // Fetch story viewers (only story owner can call)
    func fetchViewers(storyId: Int) async -> [StoryViewer] {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/stories/\(storyId)/viewers/") else {
            return []
        }
        struct Page: Decodable { let results: [StoryViewer] }
        if let page = try? JSONDecoder().decode(Page.self, from: data) {
            return page.results
        }
        if let list = try? JSONDecoder().decode([StoryViewer].self, from: data) {
            return list
        }
        return []
    }

    // Soft delete story (DELETE endpoint now does is_deleted=True on backend)
    func deleteStory(id: Int) async -> Bool {
        guard let reqURL = URL(string: "\(APIConfig.base)/stories/\(id)/") else { return false }
        var req = URLRequest(url: reqURL)
        req.httpMethod = "DELETE"
        let (_, code) = await APIClient.shared.send(req)
        return code == 204
    }

    // MARK: - Multipart helper

    private func multipart(url: String, fileData: Data, fileName: String,
                           mimeType: String, fields: [String: String]) async -> Data? {
        guard let reqURL = URL(string: url) else { return nil }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: reqURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

        var body = Data()
        let crlf = "\r\n"

        for (key, value) in fields {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)")
            body.append("\(value)\(crlf)")
        }
        body.append("--\(boundary)\(crlf)")
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(fileName)\"\(crlf)")
        body.append("Content-Type: \(mimeType)\(crlf)\(crlf)")
        body.append(fileData)
        body.append("\(crlf)--\(boundary)--\(crlf)")

        req.httpBody = body
        let (data, _) = await APIClient.shared.send(req)
        return data
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
