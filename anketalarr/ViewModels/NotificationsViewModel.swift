import Foundation
import SwiftUI
import Combine

// MARK: - Model

struct AppNotification: Identifiable, Decodable {
    let id: Int
    let notification_type: String?
    let title: String?
    let message: String?
    let is_read: Bool?
    let created_at: String?
    let actor_name: String?
    let actor_photo: String?

    var actorPhotoURL: URL? { actor_photo.flatMap { URL(string: $0) } }

    var formattedDate: String {
        guard let raw = created_at else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: raw)
        }()
        guard let d = date else { return String(raw.prefix(10)) }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f.string(from: d)
    }

    var icon: String {
        switch notification_type {
        case "like":             return "heart.fill"
        case "match":            return "bolt.heart.fill"
        case "message":          return "message.fill"
        case "visit":            return "eye.fill"
        case "super_like":       return "star.fill"
        case "new_story":        return "camera.fill"
        case "story_reaction":   return "face.smiling"
        default:                 return "bell.fill"
        }
    }

    var iconColor: Color {
        switch notification_type {
        case "like":             return .red
        case "match":            return .pink
        case "message":          return .blue
        case "visit":            return .purple
        case "super_like":       return .orange
        case "new_story":        return .teal
        case "story_reaction":   return Color.orange
        default:                 return .gray
        }
    }
}

struct NotificationPage: Decodable {
    let count: Int?
    let results: [AppNotification]
}

// MARK: - ViewModel

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    @Published var errorMsg: String? = nil
    func load() {
        Task {
            isLoading = true
            await fetchNotifications()
            isLoading = false
        }
    }

    func markAllRead() {
        Task {
            await postMarkAllRead()
            await fetchNotifications()
        }
    }

    func markRead(_ id: Int) {
        Task {
            await postMarkRead(id)
            if let i = notifications.firstIndex(where: { $0.id == id }) {
                // optimistic update
                notifications[i] = AppNotification(
                    id: notifications[i].id,
                    notification_type: notifications[i].notification_type,
                    title: notifications[i].title,
                    message: notifications[i].message,
                    is_read: true,
                    created_at: notifications[i].created_at,
                    actor_name: notifications[i].actor_name,
                    actor_photo: notifications[i].actor_photo
                )
            }
        }
    }

    // MARK: - API

    private func fetchNotifications() async {
        guard let data = await get("\(APIConfig.base)/notifications/") else { return }
        if let page = try? JSONDecoder().decode(NotificationPage.self, from: data) {
            notifications = page.results
        } else if let list = try? JSONDecoder().decode([AppNotification].self, from: data) {
            notifications = list
        }
    }

    private func postMarkAllRead() async {
        await post("\(APIConfig.base)/notifications/mark-all-read/")
    }

    private func postMarkRead(_ id: Int) async {
        await post("\(APIConfig.base)/notifications/\(id)/mark-read/")
    }

    private func get(_ urlStr: String) async -> Data? {
        return await APIClient.shared.getData(urlStr)
    }

    @discardableResult
    private func post(_ urlStr: String) async -> Data? {
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        let (data, _) = await APIClient.shared.send(req)
        return data
    }
}
