import Foundation

/// Параметры виртуального интерфейса — общие для настроек iOS и конфига ядра.
enum TunnelInterface {
    static let mtu = 1500
    static let ipv4Address = "172.19.0.1"
    static let ipv4Mask = "255.255.255.252"
    static let ipv6Address = "fdfe:dcba:9876::1"
    static let ipv6PrefixLength = 126
    /// DNS, который видит система. Запросы к нему ядро перехватывает и решает само.
    static let dnsServer = "1.1.1.1"
}

/// Превращает конфиг профиля (рассчитанный панелью на socks/http-вход, как у Happ) в конфиг для VPN-расширения.
enum TunnelConfig {
    static let probeURL = "https://www.gstatic.com/generate_204"

    enum ConfigError: LocalizedError {
        case unreadable

        var errorDescription: String? { "Не удалось прочитать конфигурацию профиля" }
    }

    /// Готовит конфиг в приложении: свой вход tun, перехват DNS, лог; всё, что панель задала для маршрутов, — как есть.
    static func adapt(_ profileConfig: Data, logLevel: String) throws -> String {
        guard var config = try JSONSerialization.jsonObject(with: profileConfig) as? [String: Any] else {
            throw ConfigError.unreadable
        }

        // Входы панели (socks/http на localhost) не нужны: трафик приходит с интерфейса.
        config["inbounds"] = [[
            "tag": "tun",
            "protocol": "tun",
            "port": 0,
            "settings": ["mtu": TunnelInterface.mtu],
            "sniffing": ["enabled": true, "destOverride": ["http", "tls", "quic"], "routeOnly": true],
        ]]
        // Без слушающих сокетов и меток для клиентов вроде Happ.
        for key in ["api", "metrics", "remarks"] { config.removeValue(forKey: key) }

        var outbounds = config["outbounds"] as? [[String: Any]] ?? []
        if !outbounds.contains(where: { $0["tag"] as? String == "dns-out" }) {
            outbounds.append(["tag": "dns-out", "protocol": "dns"])
        }
        config["outbounds"] = outbounds

        var routing = config["routing"] as? [String: Any] ?? [:]
        let panelRules = (routing["rules"] as? [[String: Any]] ?? []).compactMap(GeoData.filterRule)
        let hijackDNS: [String: Any] = ["type": "field", "inboundTag": ["tun"], "port": "53", "outboundTag": "dns-out"]
        routing["rules"] = [hijackDNS] + panelRules
        config["routing"] = routing

        var dns = config["dns"] as? [String: Any] ?? ["servers": ["https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"]]
        dns["servers"] = (dns["servers"] as? [Any] ?? []).compactMap(GeoData.filterDNSServer)
        // Только IPv4: серверы подписки обычно без IPv6, а IPv6 в обход туннеля — утечка.
        dns["queryStrategy"] = "UseIPv4"
        config["dns"] = dns

        config["log"] = ["loglevel": logLevel, "access": "none", "error": AppGroup.tunnelLogURL.path, "dnsLog": false]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// Дописывает то, что известно только внутри расширения в момент запуска: fd интерфейса utun и папку с geo-файлами.
    static func runtime(_ config: String, tunFd: Int32, assetDirectory: String) throws -> String {
        guard var object = try JSONSerialization.jsonObject(with: Data(config.utf8)) as? [String: Any] else {
            throw ConfigError.unreadable
        }
        var env = object["env"] as? [String: String] ?? [:]
        env["xray.tun.fd"] = String(tunFd)
        env["xray.location.asset"] = assetDirectory
        object["env"] = env
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
}
