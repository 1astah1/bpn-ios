import Darwin
import Foundation

/// Сети только с IPv6 (NAT64/DNS64) — так App Review проверяет приложения. IPv4-адрес сервера, записанный
/// в подписке цифрами, там недостижим: Go-ядро само адрес не синтезирует. Система умеет — через getaddrinfo,
/// поэтому до запуска ядра заменяем такие адреса синтезированными IPv6. В обычной сети ничего не меняется.
enum NAT64 {
    static func rewrite(_ config: String) -> String {
        guard var object = try? JSONSerialization.jsonObject(with: Data(config.utf8)) as? [String: Any],
              var outbounds = object["outbounds"] as? [[String: Any]] else { return config }

        var changed = false
        for index in outbounds.indices {
            guard var settings = outbounds[index]["settings"] as? [String: Any] else { continue }
            if let address = settings["address"] as? String, let synthesized = synthesize(address) {
                settings["address"] = synthesized
                changed = true
            }
            for key in ["vnext", "servers"] {
                guard var servers = settings[key] as? [[String: Any]] else { continue }
                for server in servers.indices {
                    if let address = servers[server]["address"] as? String, let synthesized = synthesize(address) {
                        servers[server]["address"] = synthesized
                        changed = true
                    }
                }
                settings[key] = servers
            }
            outbounds[index]["settings"] = settings
        }
        guard changed else { return config }
        object["outbounds"] = outbounds
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return config }
        return String(decoding: data, as: UTF8.self)
    }

    /// IPv6 для IPv4-литерала, если в сети нет IPv4. nil — адрес не IPv4 или IPv4 доступен как есть.
    static func synthesize(_ address: String) -> String? {
        var ipv4 = in_addr()
        guard inet_pton(AF_INET, address, &ipv4) == 1 else { return nil }

        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_DEFAULT
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(address, "443", &hints, &result) == 0 else { return nil }
        defer { freeaddrinfo(result) }

        var hasIPv4 = false
        var ipv6: String?
        var cursor = result
        while let info = cursor?.pointee {
            if info.ai_family == AF_INET {
                hasIPv4 = true
            } else if info.ai_family == AF_INET6, ipv6 == nil, let sockaddr = info.ai_addr {
                ipv6 = sockaddr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                    var raw = pointer.pointee.sin6_addr
                    var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    guard inet_ntop(AF_INET6, &raw, &buffer, socklen_t(buffer.count)) != nil else { return nil }
                    return String(cString: buffer)
                }
            }
            cursor = info.ai_next
        }
        return hasIPv4 ? nil : ipv6
    }
}
