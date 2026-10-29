import Foundation
import NetworkExtension
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var status: NEVPNStatus = .invalid
    /// Чего хочет пользователь: тумблер встаёт сразу, не дожидаясь системы.
    @Published private(set) var wantsConnection = false
    @Published private(set) var connectedSince: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isMeasuring = false
    /// Задержка до сервера профиля, мс; nil — не ответил. Нет ключа — ещё не мерили.
    @Published private(set) var delays: [String: Int?] = [:]
    @Published var errorMessage: String?

    private let tunnel = TunnelController()

    init() {
        state = StateStore.load()
        tunnel.onStatusChange = { [weak self] status in
            guard let self else { return }
            self.status = status
            self.connectedSince = status == .connected ? self.tunnel.connectedDate : nil
            switch status {
            case .connected, .connecting, .reasserting: self.wantsConnection = true
            case .disconnected, .invalid: self.wantsConnection = false
            default: break
            }
        }
    }

    var isConnected: Bool { status == .connected }
    var isBusy: Bool { [.connecting, .disconnecting, .reasserting].contains(status) }

    func onLaunch() async {
        #if DEBUG
        // Скриншоты и проверка вёрстки в симуляторе, где туннель не поднимается: `-demo-connected`.
        if ProcessInfo.processInfo.arguments.contains("-demo-connected") {
            status = .connected
            wantsConnection = true
            connectedSince = Date().addingTimeInterval(-754)
            return
        }
        #endif
        await tunnel.load()
        if let subscription = state.subscription, subscription.isStale {
            await refresh()
        }
    }

    // MARK: Подписка

    /// Ссылка подписки — вставкой или диплинком `<scheme>://import?url=...`.
    func addSubscription(_ text: String) async {
        guard let url = Self.subscriptionURL(from: text) else {
            errorMessage = "Это не похоже на ссылку подписки"
            return
        }
        await load(url)
    }

    func handleOpenURL(_ url: URL) async {
        guard url.host == "import",
              let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value else { return }
        await addSubscription(raw)
    }

    func refresh() async {
        guard let url = state.subscription?.url else { return }
        await load(url)
    }

    func removeSubscription() async {
        await tunnel.removeProfile()
        delays = [:]
        update { $0 = AppState() }
    }

    private func load(_ url: URL) async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let (subscription, profiles) = try await client.fetch(url)
            update { state in
                state.subscription = subscription
                state.profiles = profiles
                if !profiles.contains(where: { $0.id == state.selectedProfileID }) {
                    state.selectedProfileID = profiles.first?.id
                }
            }
            delays = [:]
            await applyConfigIfConnected()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var client: SubscriptionClient {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Client"
        return SubscriptionClient(
            device: .init(hwid: DeviceID.current, osVersion: UIDevice.current.systemVersion, model: Self.deviceModel),
            userAgent: "\(name)/\(version) (iOS)"
        )
    }

    // MARK: Подключение

    func toggleConnection() async {
        if wantsConnection || isConnected || isBusy {
            wantsConnection = false
            tunnel.stop()
        } else {
            await connect()
        }
    }

    func connect() async {
        wantsConnection = true
        do {
            try writeTunnelConfig()
            try await tunnel.start()
        } catch {
            wantsConnection = false
            errorMessage = Self.describe(error)
        }
    }

    func select(_ profile: Profile) async {
        update { $0.selectedProfileID = profile.id }
        await applyConfigIfConnected()
    }

    private func applyConfigIfConnected() async {
        guard isConnected else { return }
        do {
            try writeTunnelConfig()
            await tunnel.reloadConfig()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func writeTunnelConfig() throws {
        guard let profile = state.selectedProfile else { throw ProfileFactory.ParseError.empty }
        #if DEBUG
        let logLevel = "info"
        #else
        let logLevel = "warning"
        #endif
        let config = try TunnelConfig.adapt(profile.config, logLevel: logLevel)
        try Data(config.utf8).write(
            to: AppGroup.tunnelConfigURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    // MARK: Скорость серверов

    /// Меряем из процесса приложения и только без VPN: через туннель цифры были бы двойными.
    func measureDelays() async {
        guard !isConnected, !isMeasuring else { return }
        let measurable = state.profiles.compactMap { profile -> (id: String, outbound: [String: Any])? in
            guard let data = profile.pingOutbound,
                  let outbound = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return (profile.id, outbound)
        }
        guard !measurable.isEmpty else { return }
        isMeasuring = true
        defer { isMeasuring = false }

        // У каждого профиля прокси с тегом "proxy" — для пачки нужны разные теги.
        let outbounds = measurable.enumerated().map { index, item in
            item.outbound.merging(["tag": "ping-\(index)"]) { $1 }
        }
        let results = await Task.detached(priority: .userInitiated) {
            try? Xray.ping(outbounds: outbounds, url: TunnelConfig.probeURL, timeoutSeconds: 5)
        }.value
        guard let results else {
            errorMessage = "Не удалось проверить серверы"
            return
        }
        delays = Dictionary(uniqueKeysWithValues: zip(measurable.map(\.id), results))
    }

    // MARK: Вспомогательное

    private func update(_ change: (inout AppState) -> Void) {
        var next = state
        change(&next)
        state = next
        do {
            try StateStore.save(next)
        } catch {
            errorMessage = "Не удалось сохранить настройки: \(error.localizedDescription)"
        }
    }

    /// Ошибки NetworkExtension приходят системными строками вроде «IPC failed» — переводим на человеческий.
    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == NEVPNErrorDomain, let code = NEVPNError.Code(rawValue: nsError.code) else {
            return error.localizedDescription
        }
        #if targetEnvironment(simulator)
        return "VPN в симуляторе не запускается — проверьте на iPhone"
        #else
        switch code {
        case .configurationReadWriteFailed:
            return "Не удалось сохранить настройки VPN. Если система спросила разрешение — нажмите «Разрешить»."
        case .configurationInvalid, .configurationStale, .configurationUnknown:
            return "Профиль VPN устарел. Попробуйте ещё раз — приложение пересоздаст его."
        case .configurationDisabled:
            return "Профиль VPN выключен в Настройках → VPN."
        case .connectionFailed:
            return "Не удалось подключиться. Выберите другой сервер или обновите подписку."
        @unknown default:
            return error.localizedDescription
        }
        #endif
    }

    private static func subscriptionURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https" || url.scheme == "http", url.host != nil else {
            return nil
        }
        return url
    }

    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

extension Subscription {
    /// Пора обновить: панель задаёт интервал в часах, по умолчанию раз в сутки.
    var isStale: Bool {
        let hours = Double(updateIntervalHours ?? 24)
        return Date().timeIntervalSince(updatedAt) > hours * 3600
    }
}
