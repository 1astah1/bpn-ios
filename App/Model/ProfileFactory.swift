import Foundation

/// Тело подписки → профили.
/// Remnawave отдаёт массив полных конфигов Xray (с «Авто» и «Обход LTE»), 3x-ui и прочие — ссылки vless://.
enum ProfileFactory {
    enum ParseError: LocalizedError {
        case empty
        /// Панель вместо серверов прислала заглушки (например, «Приложение не поддерживается»).
        case placeholder(String)

        var errorDescription: String? {
            switch self {
            case .empty: return "В подписке нет серверов"
            case .placeholder(let message): return message
            }
        }
    }

    private static let serviceProtocols: Set<String> = ["freedom", "blackhole", "dns", "loopback"]
    /// Адреса, которые панели ставят в заглушки вместо настоящих серверов.
    private static let placeholderHosts: Set<String> = ["0.0.0.0", "127.0.0.1", "localhost", "virt.host", "locale.host"]

    static func profiles(from body: String) throws -> [Profile] {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["),
           let configs = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [[String: Any]] {
            return try fromFullConfigs(configs)
        }
        return try fromShareLinks(trimmed)
    }

    static func isJSON(_ body: String) -> Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[")
    }

    // MARK: Полные конфиги

    private static func fromFullConfigs(_ configs: [[String: Any]]) throws -> [Profile] {
        var profiles: [Profile] = []
        var placeholders: [String] = []
        for (index, config) in configs.enumerated() {
            let name = config["remarks"] as? String ?? "Профиль \(index + 1)"
            let proxies = (config["outbounds"] as? [[String: Any]] ?? []).filter(isProxy)
            if proxies.isEmpty { continue }
            if proxies.allSatisfy(isPlaceholder) {
                placeholders.append(name)
                continue
            }
            profiles.append(Profile(
                id: uniqueID(name, in: profiles),
                name: name,
                config: try JSONSerialization.data(withJSONObject: config),
                pingOutbound: proxies.count == 1 ? try JSONSerialization.data(withJSONObject: proxies[0]) : nil,
                serverCount: proxies.count
            ))
        }
        return try nonEmpty(profiles, placeholders: placeholders)
    }

    // MARK: Ссылки

    private static func fromShareLinks(_ text: String) throws -> [Profile] {
        var servers: [(name: String, outbound: [String: Any])] = []
        var placeholders: [String] = []
        for (index, outbound) in try Xray.outbounds(fromShareLinks: text).enumerated() {
            let name = outbound["tag"] as? String ?? "Сервер \(index + 1)"
            if isPlaceholder(outbound) {
                placeholders.append(name)
            } else {
                servers.append((name, outbound))
            }
        }

        var profiles: [Profile] = []
        if servers.count > 1 {
            let tagged = servers.enumerated().map { index, server in
                server.outbound.merging(["tag": "proxy-\(index)"]) { $1 }
            }
            profiles.append(Profile(
                id: "auto",
                name: "Автовыбор",
                config: try JSONSerialization.data(withJSONObject: config(proxies: tagged, balance: true)),
                pingOutbound: nil,
                serverCount: servers.count
            ))
        }
        for server in servers {
            let proxy = server.outbound.merging(["tag": "proxy"]) { $1 }
            profiles.append(Profile(
                id: uniqueID(server.name, in: profiles),
                name: server.name,
                config: try JSONSerialization.data(withJSONObject: config(proxies: [proxy], balance: false)),
                pingOutbound: try JSONSerialization.data(withJSONObject: proxy),
                serverCount: 1
            ))
        }
        return try nonEmpty(profiles, placeholders: placeholders)
    }

    /// Конфиг в формате панели (как у Remnawave): прокси первым — он же маршрут по умолчанию.
    private static func config(proxies: [[String: Any]], balance: Bool) -> [String: Any] {
        var rules: [[String: Any]] = [
            ["type": "field", "domain": DomesticRules.domains, "outboundTag": "direct"],
            ["type": "field", "ip": DomesticRules.ips, "outboundTag": "direct"],
        ]
        var routing: [String: Any] = ["domainStrategy": "AsIs"]
        var config: [String: Any] = [
            "outbounds": proxies + [
                ["tag": "direct", "protocol": "freedom", "settings": ["domainStrategy": "UseIPv4"]],
                ["tag": "block", "protocol": "blackhole"],
            ],
        ]
        if balance {
            rules.append(["type": "field", "network": "tcp,udp", "balancerTag": "auto"])
            routing["balancers"] = [[
                "tag": "auto",
                "selector": ["proxy-"],
                "strategy": ["type": "leastPing"],
                "fallbackTag": "proxy-0",
            ]]
            config["observatory"] = [
                "subjectSelector": ["proxy-"],
                "probeURL": TunnelConfig.probeURL,
                "probeInterval": "1m",
                "enableConcurrency": true,
            ]
        }
        routing["rules"] = rules
        config["routing"] = routing
        return config
    }

    // MARK: Вспомогательное

    private static func isProxy(_ outbound: [String: Any]) -> Bool {
        !serviceProtocols.contains(outbound["protocol"] as? String ?? "")
    }

    private static func isPlaceholder(_ outbound: [String: Any]) -> Bool {
        guard let host = serverAddress(outbound)?.lowercased() else { return false }
        return placeholderHosts.contains(host)
    }

    /// Адрес сервера в любом из форматов outbound: vnext / servers / плоские settings.
    private static func serverAddress(_ outbound: [String: Any]) -> String? {
        let settings = outbound["settings"] as? [String: Any] ?? [:]
        if let address = settings["address"] as? String { return address }
        for key in ["vnext", "servers"] {
            if let first = (settings[key] as? [[String: Any]])?.first, let address = first["address"] as? String {
                return address
            }
        }
        return nil
    }

    private static func uniqueID(_ name: String, in profiles: [Profile]) -> String {
        var id = name
        var counter = 2
        while profiles.contains(where: { $0.id == id }) {
            id = "\(name) (\(counter))"
            counter += 1
        }
        return id
    }

    private static func nonEmpty(_ profiles: [Profile], placeholders: [String]) throws -> [Profile] {
        if !profiles.isEmpty { return profiles }
        if !placeholders.isEmpty { throw ParseError.placeholder(placeholders.joined(separator: ". ")) }
        throw ParseError.empty
    }
}
