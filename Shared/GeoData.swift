/// Категории в урезанных geoip.dat / geosite.dat (PacketTunnel/Resources, scripts/build-geodata.py).
/// Ссылку на категорию, которой нет в файле, ядро не прощает — не запускается. Поэтому такие ссылки
/// вырезаем из правил, а правило, в котором не осталось условий, убираем целиком.
enum GeoData {
    static let geosite: Set<String> = ["category-ru", "category-gov-ru", "private", "yandex", "vk", "mailru"]
    static let geoip: Set<String> = ["ru", "private"]

    static func isAvailable(_ entry: String) -> Bool {
        let lower = entry.lowercased()
        if lower.hasPrefix("geosite:") {
            let category = lower.dropFirst("geosite:".count).split(separator: "@").first.map(String.init) ?? ""
            return geosite.contains(category)
        }
        if lower.hasPrefix("geoip:") {
            var category = Substring(lower.dropFirst("geoip:".count))
            if category.hasPrefix("!") { category = category.dropFirst() }
            return geoip.contains(String(category))
        }
        // Внешние файлы (ext:file.dat:tag) мы не возим.
        return !lower.hasPrefix("ext:") && !lower.hasPrefix("ext-domain:") && !lower.hasPrefix("ext-ip:")
    }

    /// Чистит правило; nil — от условий ничего не осталось, правило надо убрать.
    static func filterRule(_ rule: [String: Any]) -> [String: Any]? {
        var rule = rule
        for key in ["domain", "domains", "ip", "source", "sourceIP"] {
            guard let list = rule[key] as? [String] else { continue }
            let kept = list.filter(isAvailable)
            if kept.isEmpty { return nil }
            rule[key] = kept
        }
        return rule
    }

    /// Для DNS-серверов: пустой список доменов означает «все домены», поэтому ключ убираем вместе с сервером.
    static func filterDNSServer(_ server: Any) -> Any? {
        guard var server = server as? [String: Any] else { return server }
        for key in ["domains", "expectIPs", "expectedIPs", "unexpectedIPs"] {
            guard let list = server[key] as? [String] else { continue }
            let kept = list.filter(isAvailable)
            if kept.isEmpty { return nil }
            server[key] = kept
        }
        return server
    }
}
