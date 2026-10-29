import Foundation
import NetworkExtension

/// Профиль VPN в системе: создание, запуск, остановка, статус.
@MainActor
final class TunnelController {
    var onStatusChange: ((NEVPNStatus) -> Void)?

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    var status: NEVPNStatus { manager?.connection.status ?? .invalid }
    /// Когда туннель поднялся — для таймера на главном экране.
    var connectedDate: Date? { manager?.connection.connectedDate }

    func load() async {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        if let existing = managers.first { attach(existing) }
        onStatusChange?(status)
    }

    func start() async throws {
        let manager = try await preparedManager()
        try manager.connection.startVPNTunnel()
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
    }

    /// Расширение перечитывает конфиг без разрыва VPN-профиля (сменили сервер или правила).
    func reloadConfig() async {
        guard let session = manager?.connection as? NETunnelProviderSession, status == .connected else { return }
        try? session.sendProviderMessage(Data(TunnelMessage.reload.rawValue.utf8)) { _ in }
    }

    func removeProfile() async {
        stop()
        try? await manager?.removeFromPreferences()
        manager = nil
        onStatusChange?(.invalid)
    }

    private func preparedManager() async throws -> NETunnelProviderManager {
        let manager = self.manager ?? NETunnelProviderManager()
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = (Bundle.main.bundleIdentifier ?? "") + ".tunnel"
        proto.serverAddress = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "VPN"
        manager.protocolConfiguration = proto
        manager.localizedDescription = proto.serverAddress
        manager.isEnabled = true

        // Сохранение показывает системный запрос «Разрешить добавить конфигурацию VPN» при первом запуске.
        try await manager.saveToPreferences()
        // Без повторной загрузки первый старт после сохранения падает с «конфигурация недействительна».
        try await manager.loadFromPreferences()
        attach(manager)
        return manager
    }

    private func attach(_ manager: NETunnelProviderManager) {
        self.manager = manager
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.onStatusChange?(self.status)
            }
        }
    }
}
