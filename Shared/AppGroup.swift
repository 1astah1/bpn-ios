import Foundation

/// Общая папка приложения и VPN-расширения.
enum AppGroup {
    static let identifier: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String, !id.isEmpty else {
            preconditionFailure("AppGroupID не задан в Info.plist")
        }
        return id
    }()

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            preconditionFailure("Нет доступа к App Group \(identifier) — проверь entitlements")
        }
        return url
    }

    /// Готовый конфиг Xray: собирает приложение, запускает расширение.
    static var tunnelConfigURL: URL { containerURL.appendingPathComponent("tunnel-config.json") }

    /// Лог ядра — только предупреждения и ошибки, для диагностики.
    static var tunnelLogURL: URL { containerURL.appendingPathComponent("tunnel.log") }

    /// Состояние приложения: подписка, серверы, выбор.
    static var stateURL: URL { containerURL.appendingPathComponent("state.json") }
}
