/// Сообщения приложения VPN-расширению (`sendProviderMessage`).
enum TunnelMessage: String {
    /// Перечитать конфиг из общей папки и перезапустить ядро на том же интерфейсе.
    case reload
}
