import Foundation

// MARK: - Helpers
extension ChatRoomViewModel {

    /// Fetch/Send/Actions/WebSocket fayllarining barchasidan foydalaniladi —
    /// shu sababli `private` emas.
    func makeRequest(path: String, method: String) -> URLRequest {
        var req = URLRequest(url: URL(string: "\(APIConfig.base)\(path)")!)
        req.httpMethod = method
        req.timeoutInterval = 15
        return req
    }
}
