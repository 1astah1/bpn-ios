import SwiftUI

/// Вертикальный тумблер «Включи BPN»: стеклянная капсула, шестигранник-ручка вверху — включено.
/// Ручку можно тянуть: идёт за пальцем 1:1, у краёв пружинит, при отпускании решает по скорости броска.
struct PowerCapsule: View {
    /// Куда стремится тумблер (желание пользователя), а не фактический статус туннеля.
    let isOn: Bool
    let knobMode: HexKnob.Mode
    /// Высота подстраивается под экран: на iPhone SE капсула ниже.
    var height: CGFloat = 304
    let onToggle: () -> Void

    private var width: CGFloat { (height * 0.434).rounded() }
    private let inset: CGFloat = 10
    private var knob: CGFloat { width - inset * 2 }

    @State private var dragY: CGFloat?
    /// Ручка выше середины хода — пока тянут; nil — не тянут. Смена даёт короткий отклик.
    @State private var dragAboveMiddle: Bool?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var travel: CGFloat { height - knob - inset * 2 }
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
                            Rectangle().frame(height: max(0, height - knobY - inset))
                        }
                }
                .overlay {
                    // Блик стекла сверху — капсула читается объёмной, а не плоской.
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                        .padding(2)
                        .allowsHitTesting(false)
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

            // Подсказка «тяни вверх» в пустой части капсулы, пока выключено.
            LiftHint()
                .frame(height: travel)
                .offset(y: inset)
                .opacity(isOn || dragY != nil ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: isOn || dragY != nil)

            HexKnob(mode: knobMode, size: knob)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 10)
                .shadow(color: Brand.blueBright.opacity(0.35 * progress), radius: 22)
                .offset(y: inset + knobY)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .gesture(drag)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.8), value: isOn)
        .sensoryFeedback(trigger: dragAboveMiddle) { old, new in
            old != nil && new != nil && old != new ? .selection : nil
        }
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
                let y = rubberBand(restingY + value.translation.height)
                dragY = y
                dragAboveMiddle = y < travel / 2
            }
            .onEnded { value in
                defer {
                    dragAboveMiddle = nil
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

/// Три шеврона: раз в несколько секунд загораются снизу вверх — подсказка, куда тянуть.
private struct LiftHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let cycle = 2.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
            VStack(spacing: -6) {
                ForEach((0..<3).reversed(), id: \.self) { index in
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Brand.blueSoft.opacity(reduceMotion ? 0.35 : 0.12 + 0.5 * glow(index, at: seconds)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Нижний шеврон вспыхивает первым, верхний — последним, потом пауза.
    private func glow(_ index: Int, at seconds: Double) -> Double {
        let peak = 0.3 + Double(index) * 0.22
        return max(0, 1 - abs(seconds - peak) / 0.32)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
