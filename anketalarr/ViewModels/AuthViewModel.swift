import Foundation
import Combine
import SwiftUI

// MARK: - API modellari
struct InterestItem: Identifiable, Codable {
    let id: Int
    let name: String
    let name_uz: String
    let name_ru: String
    let icon: String

    func displayName(lang: String) -> String {
        switch lang {
        case "ru": return name_ru.isEmpty ? name_uz : name_ru
        case "en": return name
        default:   return name_uz
        }
    }
}

struct GoalItem: Identifiable, Codable {
    let id: Int
    let name: String
    let name_uz: String
    let name_ru: String
    let icon: String

    func displayName(lang: String) -> String {
        switch lang {
        case "ru": return name_ru.isEmpty ? name_uz : name_ru
        case "en": return name
        default:   return name_uz
        }
    }
}

// MARK: - ViewModel
class AuthViewModel: ObservableObject {
    @Published var isLoading    = false
    @Published var errorMessage: String?

    // Profile setup uchun
    @Published var interests: [InterestItem] = []
    @Published var goals:     [GoalItem]     = []

    @AppStorage("access_token")  var accessToken  = ""
    @AppStorage("refresh_token") var refreshToken = ""
    // MARK: - OTP
    func sendOTP(identifier: String, completion: (() -> Void)? = nil) {
        guard !identifier.isEmpty else {
            errorMessage = LocalizationManager.get(.errIdentifier); return
        }
        errorMessage = nil; isLoading = true
        post(path: "/send-otp/", body: ["identifier": identifier], auth: false) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:        completion?()
                case .failure(let e): self?.errorMessage = e.localizedDescription
                }
            }
        }
    }

    // MARK: - Ro'yxatdan o'tish
    func register(identifier: String, otp: String, password: String) {
        errorMessage = nil; isLoading = true
        post(path: "/register/", body: ["identifier": identifier, "otp": otp, "password": password],
             auth: false) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let data):
                    // Yangi foydalanuvchi uchun profil setup ni qayta boshlash
                    UserDefaults.standard.set(false, forKey: "profile_setup_done")
                    self?.handleAuthResponse(data)
                case .failure(let e):
                    self?.errorMessage = e.localizedDescription
                }
            }
        }
    }

    // MARK: - Kirish
    func login(identifier: String, password: String) {
        guard !identifier.isEmpty, !password.isEmpty else {
            errorMessage = LocalizationManager.get(.errFillAll); return
        }
        errorMessage = nil; isLoading = true
        post(path: "/login/", body: ["identifier": identifier, "password": password],
             auth: false) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let data):
                    // Login = profil avval to'ldirilgan, setup o'tkazib yuboriladi
                    UserDefaults.standard.set(true, forKey: "profile_setup_done")
                    self?.handleAuthResponse(data)
                case .failure(let e):
                    self?.errorMessage = e.localizedDescription
                }
            }
        }
    }

    // MARK: - Parolni tiklash
    func requestPasswordReset(identifier: String, completion: @escaping () -> Void) {
        errorMessage = nil; isLoading = true
        post(path: "/password-reset/", body: ["identifier": identifier], auth: false) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:        completion()
                case .failure(let e): self?.errorMessage = e.localizedDescription
                }
            }
        }
    }

    func confirmPasswordReset(identifier: String, otp: String, newPassword: String,
                               completion: @escaping () -> Void) {
        errorMessage = nil; isLoading = true
        post(path: "/password-reset/confirm/",
             body: ["identifier": identifier, "otp": otp, "new_password": newPassword],
             auth: false) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:        completion()
                case .failure(let e): self?.errorMessage = e.localizedDescription
                }
            }
        }
    }

    // MARK: - Qiziqishlar va maqsadlarni yuklash
    func fetchInterests() {
        get(path: "/interests/") { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let arr) = result, !arr.isEmpty {
                    self?.interests = arr.compactMap { item -> InterestItem? in
                        guard let id = item["id"] as? Int,
                              let name = item["name"] as? String else { return nil }
                        return InterestItem(
                            id: id, name: name,
                            name_uz: item["name_uz"] as? String ?? name,
                            name_ru: item["name_ru"] as? String ?? name,
                            icon: item["icon"] as? String ?? ""
                        )
                    }
                } else {
                    // Fallback: backend bo'sh yoki ishlamaydi
                    self?.interests = Self.fallbackInterests
                }
            }
        }
    }

    func fetchGoals() {
        get(path: "/goals/") { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let arr) = result, !arr.isEmpty {
                    self?.goals = arr.compactMap { item -> GoalItem? in
                        guard let id = item["id"] as? Int,
                              let name = item["name"] as? String else { return nil }
                        return GoalItem(
                            id: id, name: name,
                            name_uz: item["name_uz"] as? String ?? name,
                            name_ru: item["name_ru"] as? String ?? name,
                            icon: item["icon"] as? String ?? ""
                        )
                    }
                } else {
                    self?.goals = Self.fallbackGoals
                }
            }
        }
    }

    // MARK: - Fallback data
    private static let fallbackInterests: [InterestItem] = [
        .init(id:1,  name:"Music",       name_uz:"Musiqa",        name_ru:"Музыка",       icon:"🎵"),
        .init(id:2,  name:"Sport",       name_uz:"Sport",         name_ru:"Спорт",        icon:"⚽"),
        .init(id:3,  name:"Travel",      name_uz:"Sayohat",       name_ru:"Путешествия",  icon:"✈️"),
        .init(id:4,  name:"Art",         name_uz:"San'at",        name_ru:"Искусство",    icon:"🎨"),
        .init(id:5,  name:"Gaming",      name_uz:"O'yinlar",      name_ru:"Игры",         icon:"🎮"),
        .init(id:6,  name:"Cooking",     name_uz:"Oshpazlik",     name_ru:"Кулинария",    icon:"🍳"),
        .init(id:7,  name:"Reading",     name_uz:"Kitob",         name_ru:"Чтение",       icon:"📚"),
        .init(id:8,  name:"Photography", name_uz:"Fotografiya",   name_ru:"Фотография",   icon:"📸"),
        .init(id:9,  name:"Fitness",     name_uz:"Fitness",       name_ru:"Фитнес",       icon:"💪"),
        .init(id:10, name:"Movies",      name_uz:"Kino",          name_ru:"Кино",         icon:"🎬"),
        .init(id:11, name:"Nature",      name_uz:"Tabiat",        name_ru:"Природа",      icon:"🌿"),
        .init(id:12, name:"Dance",       name_uz:"Raqslar",       name_ru:"Танцы",        icon:"💃"),
    ]

    private static let fallbackGoals: [GoalItem] = [
        .init(id:1, name:"Serious relationship", name_uz:"Jiddiy munosabat",   name_ru:"Серьёзные отношения", icon:"💍"),
        .init(id:2, name:"Romantic partner",     name_uz:"Sevgili topish",      name_ru:"Найти партнёра",      icon:"💑"),
        .init(id:3, name:"New friends",          name_uz:"Yangi do'stlar",      name_ru:"Новые друзья",        icon:"👫"),
        .init(id:4, name:"Casual chat",          name_uz:"Suhbatdosh kerak",    name_ru:"Общение",             icon:"💬"),
        .init(id:5, name:"Hang out",             name_uz:"Birga vaqt o'tkazish",name_ru:"Вместе проводить время",icon:"🎭"),
    ]

    // MARK: - Profilni sozlash
    func setupProfile(
        firstName: String, lastName: String, patronymic: String,
        birthDate: String, gender: String,
        height: Int?, weight: Int?,
        latitude: Double?, longitude: Double?,
        interestIds: [Int], goalIds: [Int],
        completion: @escaping (Bool) -> Void
    ) {
        errorMessage = nil; isLoading = true

        var body: [String: Any] = [
            "first_name": firstName,
            "last_name":  lastName,
            "birth_date": birthDate,
            "gender":     gender,
        ]
        if !patronymic.isEmpty    { body["patronymic"]  = patronymic }
        if let h = height         { body["height"]       = h }
        if let w = weight         { body["weight"]       = w }
        if let lat = latitude     { body["latitude"]     = lat }
        if let lon = longitude    { body["longitude"]    = lon }
        if !interestIds.isEmpty   { body["interest_ids"] = interestIds }
        if !goalIds.isEmpty       { body["goal_ids"]     = goalIds }

        post(path: "/profile/setup/", body: body, auth: true) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:        completion(true)
                case .failure(let e): self?.errorMessage = e.localizedDescription; completion(false)
                }
            }
        }
    }

    // MARK: - Yuz skanerlash
    func uploadFaceScan(imageData: Data, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: APIConfig.authBase + "/profile/face-scan/") else { return }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        var body = Data()
        let nl = "\r\n"
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"face_scan\"; filename=\"face.jpg\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(nl)\(nl)".data(using: .utf8)!)
        body.append(imageData)
        body.append("\(nl)--\(boundary)--\(nl)".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error = error { self?.errorMessage = error.localizedDescription; completion(false); return }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion((200..<300).contains(status))
            }
        }.resume()
    }

    // MARK: - Rasm yuklash
    func uploadPhoto(imageData: Data, isMain: Bool, order: Int,
                     completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: APIConfig.authBase + "/photos/") else { return }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        var body = Data()
        let nl = "\r\n"

        // image field
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(nl)\(nl)".data(using: .utf8)!)
        body.append(imageData)
        body.append(nl.data(using: .utf8)!)

        // is_main field
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"is_main\"\(nl)\(nl)".data(using: .utf8)!)
        body.append("\(isMain)\(nl)".data(using: .utf8)!)

        // order field
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"order\"\(nl)\(nl)".data(using: .utf8)!)
        body.append("\(order)\(nl)".data(using: .utf8)!)

        body.append("--\(boundary)--\(nl)".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error { self?.errorMessage = error.localizedDescription; completion(false); return }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion((200..<300).contains(status))
            }
        }.resume()
    }

    // MARK: - Token saqlash
    func handleAuthResponse(_ data: [String: Any]) {
        if let access = data["access"] as? String {
            accessToken  = access
            refreshToken = (data["refresh"] as? String) ?? ""
        } else if let tokens = data["tokens"] as? [String: Any],
                  let access = tokens["access"] as? String {
            accessToken  = access
            refreshToken = (tokens["refresh"] as? String) ?? ""
        } else {
            errorMessage = LocalizationManager.get(.errBadResp)
        }
    }

    // MARK: - HTTP: POST (JSON)
    private func post(
        path: String, body: [String: Any], auth: Bool,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: APIConfig.authBase + path) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth { req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 15
        execute(req, completion: completion)
    }

    // MARK: - HTTP: GET (list)
    private func get(
        path: String,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        guard let url = URL(string: APIConfig.authBase + path) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else {
                completion(.failure(NSError(domain: "", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: LocalizationManager.get(.errParse)])))
                return
            }
            completion(.success(arr))
        }.resume()
    }

    private func execute(
        _ req: URLRequest,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                completion(.failure(NSError(domain: "", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: LocalizationManager.get(.errParse)])))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) {
                completion(.success(json))
            } else {
                let code = json["code"] as? String
                let limit = json["limit"] as? Int
                let detail = (json["detail"] as? String)
                    ?? json.values.compactMap {
                        if let s = $0 as? String { return s }
                        if let a = $0 as? [String] { return a.first }
                        return nil
                    }.first
                let msg = LocalizationManager.errorText(code: code, detail: detail, limit: limit)
                completion(.failure(NSError(domain: "", code: status,
                    userInfo: [NSLocalizedDescriptionKey: msg])))
            }
        }.resume()
    }
}

// MARK: - Token Manager
class TokenManager {
    static let shared = TokenManager()
    private init() {}

    var accessToken:  String? { UserDefaults.standard.string(forKey: "access_token") }
    var refreshToken: String? { UserDefaults.standard.string(forKey: "refresh_token") }
    var isLoggedIn:   Bool    { !(accessToken?.isEmpty ?? true) }

    func clear() {
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }
}
