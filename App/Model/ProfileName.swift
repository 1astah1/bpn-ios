import Foundation

/// Имя профиля из панели («🇨🇿 Czech | Чехия #1») → флаг, русское название, код страны для плашек.
struct ProfileName {
    let flag: String?
    let title: String
    let code: String?

    init(_ raw: String) {
        let scalars = Array(raw.unicodeScalars.drop { $0.properties.isWhitespace })
        let indicators = scalars.prefix { Self.regionalIndicators.contains($0.value) }
        var rest = raw
        if indicators.count >= 2 {
            let pair = Array(indicators.prefix(2))
            flag = String(String.UnicodeScalarView(pair))
            code = String(pair.compactMap { Unicode.Scalar($0.value - 0x1F1E6 + 65).map(Character.init) })
            rest = String(String.UnicodeScalarView(scalars.dropFirst(2)))
        } else {
            flag = nil
            code = nil
        }
        let parts = rest.stripEmoji().split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // У панели формат «English | Русский» — берём русскую часть.
        title = parts.last(where: { $0.unicodeScalars.contains(where: Self.isCyrillic) }) ?? parts.first ?? raw
    }

    private static let regionalIndicators: ClosedRange<UInt32> = 0x1F1E6...0x1F1FF

    private static func isCyrillic(_ scalar: Unicode.Scalar) -> Bool {
        (0x0400...0x04FF).contains(scalar.value)
    }
}

extension String {
    /// Без эмодзи: в заголовках панели бывают значки вроде 🛜, которые не нужны в шапке.
    func stripEmoji() -> String {
        let kept = unicodeScalars.filter { scalar in
            !(scalar.properties.isEmojiPresentation || scalar.value >= 0x1F000 || scalar.value == 0xFE0F || scalar.value == 0x200D)
        }
        return String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespaces)
    }
}
