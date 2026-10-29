import Foundation
import LibXray

enum XrayError: LocalizedError {
    case core(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .core(let message): return message
        case .badResponse: return "Ядро вернуло непонятный ответ"
        }
    }
}

/// Тонкая обёртка над единственной точкой входа libXray: `CGoInvoke` (JSON на входе и выходе).
enum Xray {
    private static let apiVersion = 3

    @discardableResult
    static func invoke(_ method: String, payload: [String: Any] = [:]) throws -> Any? {
        let request: [String: Any] = ["apiVersion": apiVersion, "method": method, "payload": payload]
        let requestJSON = String(decoding: try JSONSerialization.data(withJSONObject: request), as: UTF8.self)

        let responsePointer = requestJSON.withCString { CGoInvoke(UnsafeMutablePointer(mutating: $0)) }
        guard let responsePointer else { throw XrayError.badResponse }
        defer { CGoFree(responsePointer) }

        let responseData = Data(String(cString: responsePointer).utf8)
        guard let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw XrayError.badResponse
        }
        guard response["success"] as? Bool == true else {
            throw XrayError.core(response["error"] as? String ?? "неизвестная ошибка")
        }
        return response["data"]
    }

    static func run(config: String) throws {
        try invoke("runXray", payload: ["xrayJson": config])
    }

    static func stop() throws {
        try invoke("stopXray")
    }

    static func version() -> String? {
        (try? invoke("xrayVersion") as? [String: Any])?["version"] as? String
    }

    /// Ссылки vless:// и т.п. или base64-подписка → outbounds в формате Xray JSON.
    /// Имя из ссылки ядро кладёт в `tag`.
    static func outbounds(fromShareLinks text: String) throws -> [[String: Any]] {
        let data = try invoke("convertShareLinksToXrayJson", payload: ["text": text]) as? [String: Any]
        guard let outbounds = data?["outbounds"] as? [[String: Any]] else { throw XrayError.badResponse }
        return outbounds
    }

    /// Задержка до `url` через каждый outbound, мс; nil — не ответил.
    /// Ядро принимает не больше 5 конфигов за вызов и не работает, пока в этом же процессе запущен runXray.
    static func ping(outbounds: [[String: Any]], url: String, timeoutSeconds: Int) throws -> [Int?] {
        var delays: [Int?] = []
        for chunkStart in stride(from: 0, to: outbounds.count, by: 5) {
            let chunk = outbounds[chunkStart..<min(chunkStart + 5, outbounds.count)]
            let configs: [[String: Any]] = try chunk.map { outbound in
                let json = try JSONSerialization.data(withJSONObject: ["outbounds": [outbound]])
                return ["xrayJson": String(decoding: json, as: UTF8.self), "outboundTag": outbound["tag"] ?? ""]
            }
            let data = try invoke("pingBatch", payload: ["configs": configs, "timeout": timeoutSeconds, "url": url])
            let results = (data as? [String: Any])?["results"] as? [[String: Any]] ?? []
            for index in chunk.indices {
                let result = results.indices.contains(index - chunkStart) ? results[index - chunkStart] : [:]
                let success = result["success"] as? Bool ?? false
                delays.append(success ? (result["delay"] as? NSNumber)?.intValue : nil)
            }
        }
        return delays
    }
}
