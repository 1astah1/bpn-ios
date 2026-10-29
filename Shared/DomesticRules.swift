/// Сайты, которые идут мимо VPN: банки, госуслуги и маркетплейсы часто не пускают с иностранных адресов.
/// Списком доменов, а не geosite.dat: VPN-расширению iOS дают около 50 МБ памяти, полный geosite в них не влезает.
enum DomesticRules {
    static let domains: [String] = [
        // Национальные зоны
        "domain:ru", "domain:su", "domain:xn--p1ai",
        // Российские сервисы вне .ru
        "domain:vk.com", "domain:vk.me", "domain:vk.company", "domain:userapi.com", "domain:vk-cdn.net",
        "domain:vkuser.net", "domain:vkuseraudio.net", "domain:vkuservideo.net", "domain:mycdn.me",
        "domain:yandex.net", "domain:yandex.com", "domain:yastatic.net", "domain:yandexcloud.net",
        "domain:wbstatic.net", "domain:wbbasket.net", "domain:avito.st", "domain:ozone.ru",
        "domain:sberbank.com", "domain:2gis.com", "domain:tbank-online.com",
    ]

    /// Локальные сети и служебные диапазоны — никогда не в туннель.
    static let privateCIDRs: [String] = [
        "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12",
        "192.168.0.0/16", "224.0.0.0/4", "255.255.255.255/32",
        "::1/128", "fc00::/7", "fe80::/10", "ff00::/8",
    ]

    /// DNS для российских доменов — напрямую, чтобы отдавались российские адреса CDN.
    static let dnsServer = "77.88.8.8"
}
