import Foundation
import os

/// Общая папка приложения и VPN-расширения.
enum AppGroup {
    static let identifier: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String, !id.isEmpty else {
            preconditionFailure("AppGroupID не задан в Info.plist")
        }
        return id
    }()

    /// Без entitlement (неподписанная сборка) общей папки нет. Тогда работаем в своей папке приложения:
    /// интерфейс живёт, а VPN-расширение конфиг не увидит — об этом пишем в лог, а не падаем на старте.
    static let containerURL: URL = {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "app-group")
            .error("Нет доступа к App Group \(identifier, privacy: .public) — проверь подпись и entitlements")
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }()

    /// Готовый конфиг Xray: собирает приложение, запускает расширение.
    static var tunnelConfigURL: URL { containerURL.appendingPathComponent("tunnel-config.json") }

    /// Лог ядра — только предупреждения и ошибки, для диагностики.
    static var tunnelLogURL: URL { containerURL.appendingPathComponent("tunnel.log") }

    /// Состояние приложения: подписка, серверы, выбор.
    static var stateURL: URL { containerURL.appendingPathComponent("state.json") }
}
