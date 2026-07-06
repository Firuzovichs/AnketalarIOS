import Foundation
import SwiftUI
import Combine

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var isLiked: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMsg: String? = nil
    /// Xatolik bo'lmagan (muvaffaqiyat) toast xabarlari uchun — errorMsg dan alohida,
    /// chunki errorMsg har doim qizil (isError: true) stilda ko'rsatiladi.
    @Published var infoMsg: String? = nil

    // Like-status / match / chat
    @Published var isMatched: Bool = false
    @Published var chatRoomId: Int? = nil
    @Published var isCheckingStatus: Bool = false
    @Published var myId: Int? = nil
    @Published var openRoom: ChatRoomModel? = nil
    @Published var isOpeningChat: Bool = false

    // Block
    @Published var isBlocking: Bool = false
    @Published var isBlocked: Bool = false

    func like(userId: Int) async {
        guard !isLiked else { return }
        isLoading = true
        errorMsg = nil

        guard let url = URL(string: "\(APIConfig.base)/matches/like/") else {
            isLoading = false; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "to_user_id": userId,
            "like_type": "like"
        ])

        let (data, status) = await APIClient.shared.send(req)
        isLoading = false

        if status == 201 {
            isLiked = true
        } else if status == 400 {
            // Already liked — treat as success
            isLiked = true
        } else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Error \(status)"
            errorMsg = body
        }
    }

    /// Joriy foydalanuvchi bu odamni avval like bosganmi va ular match bo'lganmi —
    /// shu holatga qarab Like tugmasi yoki Bloklash/Chatga o'tish ko'rsatiladi.
    func checkLikeStatus(userId: Int) async {
        isCheckingStatus = true
        defer { isCheckingStatus = false }
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/matches/like-status/\(userId)/") else { return }
        struct LikeStatus: Decodable { let liked: Bool; let matched: Bool; let chat_room_id: Int? }
        if let decoded = try? JSONDecoder().decode(LikeStatus.self, from: data) {
            isLiked = decoded.liked
            isMatched = decoded.matched
            chatRoomId = decoded.chat_room_id
        }
    }

    func fetchMyId() async {
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/auth/me/") else { return }
        if let me = try? JSONDecoder().decode(DashMe.self, from: data) {
            myId = me.id
        }
    }

    /// Mavjud chat xonasini id orqali yuklab, "Chatga o'tish" uchun tayyorlaydi.
    func openChat() async {
        guard let roomId = chatRoomId else { return }
        isOpeningChat = true
        defer { isOpeningChat = false }
        guard let data = await APIClient.shared.getData("\(APIConfig.base)/chat/rooms/\(roomId)/") else { return }
        if let room = try? JSONDecoder().decode(ChatRoomModel.self, from: data) {
            openRoom = room
        }
    }

    /// Soft — faqat Block/Report yozuvi yaratiladi, hech narsa bazadan o'chmaydi.
    func block(userId: Int, reason: String) async -> Bool {
        isBlocking = true
        defer { isBlocking = false }
        guard let url = URL(string: "\(APIConfig.base)/auth/block/\(userId)/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["reason": reason])
        let (_, status) = await APIClient.shared.send(req)
        guard status == 200 else { return false }
        isBlocked = true
        return true
    }
}
