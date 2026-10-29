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

enum XrayConfigBuilder {
    static let balancerTag = "auto"
    static let probeURL = "https://www.gstatic.com/generate_204"

    enum BuildError: LocalizedError {
        case noServers
        case badOutbound(String)

        var errorDescription: String? {
            switch self {
            case .noServers: return "В подписке нет серверов"
            case .badOutbound(let name): return "Не удалось прочитать сервер «\(name)»"
            }
        }
    }

    static func build(state: AppState, logLevel: String = "warning") throws -> String {
        guard !state.servers.isEmpty else { throw BuildError.noServers }

        var outbounds: [[String: Any]] = try state.servers.map { server in
            guard var outbound = try JSONSerialization.jsonObject(with: server.outbound) as? [String: Any] else {
                throw BuildError.badOutbound(server.name)
            }
            outbound["tag"] = server.id
            return outbound
        }
        outbounds += [
            ["tag": "direct", "protocol": "freedom", "settings": ["domainStrategy": "UseIPv4"]],
            ["tag": "dns-out", "protocol": "dns"],
            ["tag": "block", "protocol": "blackhole"],
        ]

        var config: [String: Any] = [
            "log": ["loglevel": logLevel, "access": "none", "error": AppGroup.tunnelLogURL.path],
            "inbounds": [[
                "tag": "tun",
                "protocol": "tun",
                "port": 0,
                "settings": ["mtu": TunnelInterface.mtu],
                "sniffing": ["enabled": true, "destOverride": ["http", "tls", "quic"], "routeOnly": true],
            ]],
            "outbounds": outbounds,
            "dns": dns(state: state),
            "routing": routing(state: state),
        ]
        if state.selection == .auto, state.servers.count > 1 {
            config["observatory"] = [
                "subjectSelector": ["proxy-"],
                "probeURL": probeURL,
                "probeInterval": "1m",
                "enableConcurrency": true,
            ]
        }

        let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// Дописывает fd интерфейса utun: он известен только внутри расширения в момент запуска.
    static func injectingTunFd(_ fd: Int32, into config: String) throws -> String {
        guard var object = try JSONSerialization.jsonObject(with: Data(config.utf8)) as? [String: Any] else {
            throw XrayError.badResponse
        }
        var env = object["env"] as? [String: String] ?? [:]
        env["xray.tun.fd"] = String(fd)
        object["env"] = env
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private static func dns(state: AppState) -> [String: Any] {
        var servers: [Any] = []
        if state.directDomestic {
            servers.append([
                "address": DomesticRules.dnsServer,
                "domains": DomesticRules.domains,
                "skipFallback": true,
                "tag": "dns-direct",
            ])
        }
        servers += ["1.1.1.1", "8.8.8.8"]
        // Только IPv4: серверы подписки обычно без IPv6, а IPv6-трафик в обход туннеля — утечка.
        return ["tag": "dns-internal", "queryStrategy": "UseIPv4", "servers": servers]
    }

    private static func routing(state: AppState) -> [String: Any] {
        var rules: [[String: Any]] = [
            ["type": "field", "inboundTag": ["tun"], "port": "53", "outboundTag": "dns-out"],
            ["type": "field", "ip": DomesticRules.privateCIDRs, "outboundTag": "direct"],
        ]
        if state.directDomestic {
            rules.append(["type": "field", "inboundTag": ["dns-direct"], "outboundTag": "direct"])
            rules.append(["type": "field", "domain": DomesticRules.domains, "outboundTag": "direct"])
        }

        var routing: [String: Any] = ["domainStrategy": "AsIs"]
        switch state.selection {
        case .server(let id) where state.servers.contains(where: { $0.id == id }):
            rules.append(["type": "field", "network": "tcp,udp", "outboundTag": id])
        case _ where state.servers.count == 1:
            rules.append(["type": "field", "network": "tcp,udp", "outboundTag": state.servers[0].id])
        default:
            rules.append(["type": "field", "network": "tcp,udp", "balancerTag": balancerTag])
            routing["balancers"] = [[
                "tag": balancerTag,
                "selector": ["proxy-"],
                "strategy": ["type": "leastPing"],
                "fallbackTag": state.servers[0].id,
            ]]
        }
        routing["rules"] = rules
        return routing
    }
}
