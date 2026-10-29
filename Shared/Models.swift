import Foundation

struct Subscription: Codable, Equatable {
    var url: URL
    var title: String?
    var usage: Usage?
    var supportURL: URL?
    var webPageURL: URL?
    var announce: String?
    var updateIntervalHours: Int?
    var updatedAt: Date

    /// Заголовок `subscription-userinfo`. Байты; total = 0 — без лимита, expire = nil — бессрочно.
    struct Usage: Codable, Equatable {
        var upload: Int64
        var download: Int64
        var total: Int64
        var expire: Date?

        var used: Int64 { upload + download }
    }
}

struct Server: Codable, Identifiable, Equatable {
    /// Уникальный тег outbound в конфиге Xray (`proxy-N`).
    var id: String
    /// Имя из ссылки подписки, как его задал сервис.
    var name: String
    /// Outbound в формате Xray JSON.
    var outbound: Data
}

enum ServerSelection: Codable, Equatable {
    case auto
    case server(id: String)
}

struct AppState: Codable, Equatable {
    var subscription: Subscription?
    var servers: [Server] = []
    var selection: ServerSelection = .auto
    /// Российские сайты идут мимо VPN.
    var directDomestic = true
}

/// Состояние лежит файлом в общей папке: его читает и приложение, и расширение.
enum StateStore {
    static func load() -> AppState {
        guard let data = try? Data(contentsOf: AppGroup.stateURL),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            return AppState()
        }
        return state
    }

    static func save(_ state: AppState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: AppGroup.stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
