/// Маршрутизация для подписок, которые отдают только ссылки (без полного конфига от панели):
/// российские сайты и локальные сети — мимо VPN. Банки, госуслуги и маркетплейсы часто не пускают
/// с иностранных адресов.
enum DomesticRules {
    static let domains: [String] = [
        "geosite:private", "geosite:category-ru",
        "domain:ru", "domain:su", "domain:xn--p1ai",
        "domain:vk.com", "domain:vk.me", "domain:userapi.com", "domain:mycdn.me",
        "domain:yandex.net", "domain:yastatic.net", "domain:2gis.com", "domain:wbstatic.net",
    ]

    static let ips: [String] = ["geoip:private", "geoip:ru"]

    /// Локальные сети и служебные диапазоны — исключаем из туннеля ещё на уровне iOS.
    static let privateIPv4CIDRs: [String] = [
        "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12",
        "192.168.0.0/16", "224.0.0.0/4", "255.255.255.255/32",
    ]
}
