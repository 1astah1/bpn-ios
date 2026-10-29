import SwiftUI

/// Вертикальный тумблер «Включи BPN»: стеклянная капсула, шестигранник-ручка вверху — включено.
/// Ручку можно тянуть: идёт за пальцем 1:1, у краёв пружинит, при отпускании решает по скорости броска.
struct PowerCapsule: View {
    /// Куда стремится тумблер (желание пользователя), а не фактический статус туннеля.
    let isOn: Bool
    let knobMode: HexKnob.Mode
    let onToggle: () -> Void

    static let width: CGFloat = 132
    static let height: CGFloat = 304
    private let knob: CGFloat = 112
    private let inset: CGFloat = 10

    @State private var dragY: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var travel: CGFloat { Self.height - knob - inset * 2 }
    private var restingY: CGFloat { isOn ? 0 : travel }
    private var knobY: CGFloat { dragY ?? restingY }
    /// 0 — ручка внизу, 1 — вверху.
    private var progress: Double { Double(1 - knobY / travel).clamped(to: 0...1) }

    var body: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(Brand.surface.opacity(0.75))
                .overlay {
                    // Синяя заливка поднимается вслед за ручкой.
                    Capsule()
                        .fill(LinearGradient(colors: [Brand.blueBright, Brand.blue], startPoint: .top, endPoint: .bottom))
                        .opacity(0.12 + 0.7 * progress)
                        .mask(alignment: .bottom) {
                            Rectangle().frame(height: Self.height - knobY - inset)
                        }
                }
                .overlay {
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [Brand.blueBright.opacity(0.35 + 0.55 * progress), Brand.blueBright.opacity(0.12)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
                }

            HexKnob(mode: knobMode, size: knob)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 10)
                .shadow(color: Brand.blueBright.opacity(0.35 * progress), radius: 22)
                .offset(y: inset + knobY)
        }
        .frame(width: Self.width, height: Self.height)
        .contentShape(Capsule())
        .gesture(drag)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.8), value: isOn)
        .accessibilityElement()
        .accessibilityLabel(isOn ? "Отключить" : "Подключить")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onToggle() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Пока палец почти не сдвинулся — это нажатие, ручку не трогаем.
                guard abs(value.translation.height) > 6 || dragY != nil else { return }
                dragY = rubberBand(restingY + value.translation.height)
            }
            .onEnded { value in
                defer {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { dragY = nil }
                }
                guard dragY != nil else {
                    onToggle()
                    return
                }
                // Куда долетела бы ручка по инерции — по ней и решаем, а не по точке отпускания.
                let projected = restingY + value.predictedEndTranslation.height
                let wantsOn = projected < travel / 2
                if wantsOn != isOn { onToggle() }
            }
    }

    /// За краями хода ручка идёт всё туже, а не упирается.
    private func rubberBand(_ y: CGFloat) -> CGFloat {
        if y < 0 { return -Self.resist(-y) }
        if y > travel { return travel + Self.resist(y - travel) }
        return y
    }

    private static func resist(_ overshoot: CGFloat, dimension: CGFloat = 120, constant: CGFloat = 0.55) -> CGFloat {
        overshoot * dimension * constant / (dimension + constant * overshoot)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
