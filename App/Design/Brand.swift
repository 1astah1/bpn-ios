import SwiftUI

/// Стиль баннера «Включи BPN»: почти чёрный фон, королевский синий, молочный шестигранник, моноширинные подписи `// …`.
enum Brand {
    static let background = Color(red: 0.043, green: 0.055, blue: 0.075)     // #0B0E13
    static let surface = Color(red: 0.078, green: 0.098, blue: 0.133)        // #141922
    static let blue = Color(red: 0.0, green: 0.322, blue: 0.706)             // #0052B4
    static let blueBright = Color(red: 0.184, green: 0.420, blue: 1.0)       // #2F6BFF
    static let blueSoft = Color(red: 0.561, green: 0.694, blue: 1.0)         // подписи
    static let cream = Color(red: 0.973, green: 0.961, blue: 0.925)          // #F8F5EC
    static let green = Color(red: 0.239, green: 0.863, blue: 0.518)
    static let amber = Color(red: 1.0, green: 0.714, blue: 0.294)
    static let red = Color(red: 1.0, green: 0.412, blue: 0.380)
    static let text = Color(red: 0.941, green: 0.949, blue: 0.969)
    static let textSecondary = Color(red: 0.553, green: 0.600, blue: 0.682)
}

enum GeistWeight: String {
    case medium = "Geist-Medium"
    case semibold = "Geist-SemiBold"
    case bold = "Geist-Bold"
    case black = "Geist-Black"
}

extension Font {
    /// Geist, масштабируется вместе с системным размером текста.
    static func geist(_ size: CGFloat, _ weight: GeistWeight = .medium, relativeTo style: TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    static func mono(_ size: CGFloat, bold: Bool = false, relativeTo style: TextStyle = .caption) -> Font {
        .custom(bold ? "GeistMono-Bold" : "GeistMono-Medium", size: size, relativeTo: style)
    }
}

/// Подпись в духе баннера: `// СКОРОСТЬ`.
struct MonoLabel: View {
    let text: String
    var color: Color = Brand.blueSoft
    var size: CGFloat = 12

    init(_ text: String, color: Color = Brand.blueSoft, size: CGFloat = 12) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text("// " + text.uppercased())
            .font(.mono(size))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

extension View {
    /// Тёмное стекло с тонкой светящейся обводкой, как капсулы на баннере.
    func glass<S: InsettableShape>(in shape: S, highlighted: Bool = false) -> some View {
        background {
            shape
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(highlighted ? 0.09 : 0.06), Color.white.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .background(shape.fill(Brand.surface.opacity(0.72)))
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Brand.blueBright.opacity(highlighted ? 0.9 : 0.42),
                                Brand.blueBright.opacity(highlighted ? 0.35 : 0.08),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
        }
    }
}

/// Фон: почти чёрный и мягкий синий свет за главным элементом. Без узоров — минимализм.
struct BrandBackground: View {
    /// 0 — VPN выключен, 1 — включён: свет за тумблером чуть разгорается.
    var glow: Double = 0
    var glowCenter = UnitPoint(x: 0.5, y: 0.47)

    var body: some View {
        ZStack {
            Brand.background
            RadialGradient(
                colors: [Brand.blue.opacity(0.10 + 0.16 * glow), .clear],
                center: glowCenter, startRadius: 10, endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

/// Нажатие сжимает элемент сразу, на касании, а не на отпускании.
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
    }
}
