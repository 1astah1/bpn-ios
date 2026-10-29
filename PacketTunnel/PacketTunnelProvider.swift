import Darwin
import NetworkExtension
import os

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tunnel", category: "tunnel")
    private var tunFd: Int32?

    enum TunnelError: LocalizedError {
        case noConfig
        case noTunFd

        var errorDescription: String? {
            switch self {
            case .noConfig: return "Нет конфигурации — открой приложение и обнови подписку"
            case .noTunFd: return "Система не выдала VPN-интерфейс"
            }
        }
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let config = try? String(contentsOf: AppGroup.tunnelConfigURL, encoding: .utf8) else {
            completionHandler(TunnelError.noConfig)
            return
        }
        setTunnelNetworkSettings(Self.networkSettings()) { [weak self] error in
            guard let self else { return }
            if let error {
                self.log.error("network settings: \(error.localizedDescription, privacy: .public)")
                completionHandler(error)
                return
            }
            do {
                guard let fd = Self.findTunFd() else { throw TunnelError.noTunFd }
                self.tunFd = fd
                try Xray.run(config: Self.runtime(config, fd: fd))
                self.log.info("xray started, fd \(fd)")
                completionHandler(nil)
            } catch {
                self.log.error("start: \(error.localizedDescription, privacy: .public)")
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log.info("stop, reason \(reason.rawValue)")
        try? Xray.stop()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        switch TunnelMessage(rawValue: String(decoding: messageData, as: UTF8.self)) {
        case .reload:
            do {
                guard let fd = tunFd else { throw TunnelError.noTunFd }
                let config = try String(contentsOf: AppGroup.tunnelConfigURL, encoding: .utf8)
                try Xray.stop()
                try Xray.run(config: Self.runtime(config, fd: fd))
                completionHandler?(Data("ok".utf8))
            } catch {
                log.error("reload: \(error.localizedDescription, privacy: .public)")
                completionHandler?(Data(error.localizedDescription.utf8))
            }
        case nil:
            completionHandler?(nil)
        }
    }

    private static func networkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
        settings.mtu = NSNumber(value: TunnelInterface.mtu)

        let ipv4 = NEIPv4Settings(addresses: [TunnelInterface.ipv4Address], subnetMasks: [TunnelInterface.ipv4Mask])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = DomesticRules.privateIPv4CIDRs.compactMap(Self.ipv4Route)
        settings.ipv4Settings = ipv4

        // IPv6 тоже заворачиваем в туннель, иначе он уходит мимо VPN.
        let ipv6 = NEIPv6Settings(
            addresses: [TunnelInterface.ipv6Address],
            networkPrefixLengths: [NSNumber(value: TunnelInterface.ipv6PrefixLength)]
        )
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: [TunnelInterface.dnsServer])
        dns.matchDomains = [""]
        settings.dnsSettings = dns
        return settings
    }

    /// geoip.dat / geosite.dat лежат в ресурсах расширения.
    private static func runtime(_ config: String, fd: Int32) throws -> String {
        try TunnelConfig.runtime(config, tunFd: fd, assetDirectory: Bundle.main.resourcePath ?? "")
    }

    private static func ipv4Route(_ cidr: String) -> NEIPv4Route? {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, !parts[0].contains(":"), let bits = Int(parts[1]), (0...32).contains(bits) else {
            return nil
        }
        let mask = bits == 0 ? UInt32(0) : UInt32.max << (32 - bits)
        let maskString = (0..<4).map { String((mask >> (24 - 8 * $0)) & 0xFF) }.joined(separator: ".")
        return NEIPv4Route(destinationAddress: String(parts[0]), subnetMask: maskString)
    }

    /// fd интерфейса utun, который создала система: ищем сокет управления с именем `utunN`.
    /// Способ из документации Xray-core (proxy/tun/README.md, раздел iOS SUPPORT).
    private static func findTunFd() -> Int32? {
        var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        let prefix = Array("utun".utf8CString.dropLast())
        for fd: Int32 in 0...1024 {
            var length = socklen_t(buffer.count)
            // SYSPROTO_CONTROL = 2, UTUN_OPT_IFNAME = 2
            if getsockopt(fd, 2, 2, &buffer, &length) == 0, buffer.starts(with: prefix) {
                return fd
            }
        }
        return nil
    }
}
