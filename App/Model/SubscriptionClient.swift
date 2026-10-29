import Foundation

/// Загружает подписку панели (Remnawave / 3x-ui) и превращает её в профили.
struct SubscriptionClient {
    struct Device {
        var hwid: String
        var osVersion: String
        var model: String
    }

    enum FetchError: LocalizedError {
        case badStatus(Int)
        case notHTTP
        case deviceLimit

        var errorDescription: String? {
            switch self {
            case .badStatus(404): return "Подписка не найдена — проверь ссылку"
            case .badStatus(let code): return "Сервер подписки ответил ошибкой \(code)"
            case .notHTTP: return "Ссылка подписки должна начинаться с https://"
            case .deviceLimit: return "На подписке уже максимум устройств. Отвяжите старое устройство в боте и попробуйте снова."
            }
        }
    }

    var device: Device
    var userAgent: String

    func fetch(_ url: URL) async throws -> (Subscription, [Profile]) {
        let (data, response) = try await get(url)
        if response.value(forHTTPHeaderField: "x-hwid-max-devices-reached") == "true" {
            throw FetchError.deviceLimit
        }

        var body = String(decoding: data, as: UTF8.self)
        // Remnawave по ссылке подписки отдаёт незнакомым клиентам base64, где «Авто» и «Обход LTE» — заглушки.
        // Полные конфиги лежат по тому же адресу с /json. У других панелей такого пути нет — тогда остаёмся на ссылках.
        if !ProfileFactory.isJSON(body), let jsonURL = Self.jsonVariant(of: url),
           let jsonResponse = try? await get(jsonURL) {
            let jsonBody = String(decoding: jsonResponse.0, as: UTF8.self)
            if ProfileFactory.isJSON(jsonBody) { body = jsonBody }
        }

        let profiles = try ProfileFactory.profiles(from: body)
        let subscription = Subscription(
            url: url,
            title: Self.header(response, "profile-title"),
            usage: Self.header(response, "subscription-userinfo").flatMap(Self.parseUsage),
            supportURL: Self.header(response, "support-url").flatMap(URL.init(string:)),
            webPageURL: Self.header(response, "profile-web-page-url").flatMap(URL.init(string:)),
            announce: Self.header(response, "announce"),
            updateIntervalHours: Self.header(response, "profile-update-interval").flatMap { Int($0) },
            updatedAt: Date()
        )
        return (subscription, profiles)
    }

    private func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        // Без этих заголовков Remnawave при включённом лимите устройств отдаёт заглушку вместо серверов.
        request.setValue(device.hwid, forHTTPHeaderField: "x-hwid")
        request.setValue("iOS", forHTTPHeaderField: "x-device-os")
        request.setValue(device.osVersion, forHTTPHeaderField: "x-ver-os")
        request.setValue(device.model, forHTTPHeaderField: "x-device-model")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.notHTTP }
        guard (200..<300).contains(http.statusCode) else { throw FetchError.badStatus(http.statusCode) }
        return (data, http)
    }

    private static func jsonVariant(of url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let path = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        guard !path.isEmpty, !path.hasSuffix("/json") else { return nil }
        components.path = path + "/json"
        return components.url
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
