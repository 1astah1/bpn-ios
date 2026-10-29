import Foundation
import Security

/// Постоянный идентификатор устройства для лимита устройств в панели.
/// Лежит в Keychain, поэтому переживает переустановку — иначе каждая переустановка съедала бы слот.
enum DeviceID {
    private static let account = "hwid"

    static var current: String {
        #if DEBUG
        // UI-тесты стирают симулятор — без постоянного id каждый прогон занимал бы новое место в лимите устройств.
        if let testID = ProcessInfo.processInfo.environment["UMBRA_TEST_HWID"], !testID.isEmpty { return testID }
        #endif
        if let existing = read() { return existing }
        let fresh = UUID().uuidString.lowercased()
        save(fresh)
        return fresh
    }

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
    }

    private static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func save(_ value: String) {
        var query = baseQuery
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }
}
