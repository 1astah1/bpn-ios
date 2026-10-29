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

/// Профиль из подписки: «Авто», отдельная страна, «Обход LTE» — у каждого свой полный конфиг Xray
/// с маршрутизацией, которую задаёт панель.
struct Profile: Codable, Identifiable, Equatable {
    /// Имя из подписки (с номером при повторе) — переживает обновление подписки, на нём держится выбор.
    var id: String
    var name: String
    /// Полный конфиг Xray как его отдала панель (или собрали мы из ссылок).
    var config: Data
    /// Единственный прокси профиля — его можно пинговать. У «Авто» и «Обход LTE» серверов несколько.
    var pingOutbound: Data?
}

struct AppState: Codable, Equatable {
    var subscription: Subscription?
    var profiles: [Profile] = []
    var selectedProfileID: String?

    var selectedProfile: Profile? {
        profiles.first { $0.id == selectedProfileID } ?? profiles.first
    }
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
