import Foundation

/// Загружает подписку панели (Remnawave / 3x-ui) и превращает её в список серверов.
struct SubscriptionClient {
    struct Device {
        var hwid: String
        var osVersion: String
        var model: String
    }

    enum FetchError: LocalizedError {
        case badStatus(Int)
        case notHTTP

        var errorDescription: String? {
            switch self {
            case .badStatus(404): return "Подписка не найдена — проверь ссылку"
            case .badStatus(let code): return "Сервер подписки ответил ошибкой \(code)"
            case .notHTTP: return "Ссылка подписки должна начинаться с https://"
            }
        }
    }

    var device: Device
    var userAgent: String

    func fetch(_ url: URL) async throws -> (Subscription, [Server]) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        // Заголовки устройства: по ним Remnawave считает лимит устройств на подписку.
        request.setValue(device.hwid, forHTTPHeaderField: "x-hwid")
        request.setValue("iOS", forHTTPHeaderField: "x-device-os")
        request.setValue(device.osVersion, forHTTPHeaderField: "x-ver-os")
        request.setValue(device.model, forHTTPHeaderField: "x-device-model")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.notHTTP }
        guard (200..<300).contains(http.statusCode) else { throw FetchError.badStatus(http.statusCode) }

        let servers = try Self.servers(from: String(decoding: data, as: UTF8.self))
        let subscription = Subscription(
            url: url,
            title: Self.header(http, "profile-title"),
            usage: Self.header(http, "subscription-userinfo").flatMap(Self.parseUsage),
            supportURL: Self.header(http, "support-url").flatMap(URL.init(string:)),
            webPageURL: Self.header(http, "profile-web-page-url").flatMap(URL.init(string:)),
            announce: Self.header(http, "announce"),
            updateIntervalHours: Self.header(http, "profile-update-interval").flatMap { Int($0) },
            updatedAt: Date()
        )
        return (subscription, servers)
    }

    /// Тело подписки: base64 со ссылками, ссылки построчно или массив полных Xray JSON (формат Remnawave для Happ).
    static func servers(from body: String) throws -> [Server] {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        var named: [(name: String, outbound: [String: Any])] = []

        if trimmed.hasPrefix("["),
           let configs = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [[String: Any]] {
            for (index, config) in configs.enumerated() {
                let outbounds = config["outbounds"] as? [[String: Any]] ?? []
                guard let proxy = outbounds.first(where: { $0["tag"] as? String == "proxy" })
                        ?? outbounds.first(where: { !["freedom", "blackhole", "dns"].contains($0["protocol"] as? String ?? "") })
                else { continue }
                named.append((config["remarks"] as? String ?? "Сервер \(index + 1)", proxy))
            }
        } else {
            for (index, outbound) in try Xray.outbounds(fromShareLinks: trimmed).enumerated() {
                named.append((outbound["tag"] as? String ?? "Сервер \(index + 1)", outbound))
            }
        }

        return try named.enumerated().map { index, item in
            var outbound = item.outbound
            let id = "proxy-\(index)"
            outbound["tag"] = id
            return Server(id: id, name: item.name, outbound: try JSONSerialization.data(withJSONObject: outbound))
        }
    }

    /// Значения вида `base64:...` панели кодируют, чтобы пропустить эмодзи и кириллицу в заголовке.
    private static func header(_ response: HTTPURLResponse, _ name: String) -> String? {
        guard let raw = response.value(forHTTPHeaderField: name)?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        guard raw.hasPrefix("base64:") else { return raw }
        let encoded = String(raw.dropFirst("base64:".count))
        guard let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `upload=123; download=456; total=789; expire=1700000000`
    static func parseUsage(_ value: String) -> Subscription.Usage? {
        var fields: [String: Int64] = [:]
        for part in value.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if pair.count == 2, let number = Int64(pair[1]) { fields[pair[0].lowercased()] = number }
        }
        guard !fields.isEmpty else { return nil }
        let expire = fields["expire"].flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
        return .init(upload: fields["upload"] ?? 0, download: fields["download"] ?? 0, total: fields["total"] ?? 0, expire: expire)
    }
}
