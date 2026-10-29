import SwiftUI
import UIKit

/// 3D-шестигранник из баннера: кадры рендера Blender (design/prepare_assets.py).
struct HexKnob: View {
    enum Mode: Equatable {
        /// Дуги Wi-Fi серые.
        case idle
        /// Крутится — идёт подключение.
        case spinning
        /// Дуги загораются по одной и горят синим.
        case lit
    }

    let mode: Mode
    var size: CGFloat = 100
    /// Кадров в секунду при вращении: 40 кадров на оборот.
    var spinFPS: Double = 30

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var litStep = 0

    var body: some View {
        ZStack {
            if mode == .spinning && !reduceMotion {
                TimelineView(.animation) { context in
                    let frames = HexFrames.spin
                    let index = Int(context.date.timeIntervalSinceReferenceDate * spinFPS) % max(frames.count, 1)
                    frame(frames.isEmpty ? nil : frames[index])
                }
                .transition(.opacity)
            } else {
                frame(HexFrames.lit.indices.contains(litStep) ? HexFrames.lit[litStep] : nil)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.18), value: mode)
        // Срабатывает и при появлении. Смена режима отменяет прошлую задачу — дуги не «догорят» после выключения.
        .task(id: mode) { await light(mode == .lit) }
        .accessibilityHidden(true)
    }

    private func frame(_ image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Color.clear
            }
        }
    }

    /// Дуги загораются снизу вверх, как на баннере.
    @MainActor
    private func light(_ on: Bool) async {
        guard on, !reduceMotion else {
            litStep = on ? 4 : 0
            return
        }
        for step in 1...4 {
            litStep = step
            do { try await Task.sleep(nanoseconds: 70_000_000) } catch { return }
        }
    }
}

enum HexFrames {
    static let spin: [UIImage] = (0..<40).compactMap { UIImage(named: String(format: "spin_%02d", $0)) }
    static let lit: [UIImage] = (0...4).compactMap { UIImage(named: "lit_\($0)") }
}
