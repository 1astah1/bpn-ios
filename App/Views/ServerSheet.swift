import SwiftUI

/// Шторка выбора сервера: сверху «умные» режимы панели (Авто, Обход LTE), ниже страны с пингом.
struct ServerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var modes: [Profile] { model.state.profiles.filter { $0.pingOutbound == nil } }
    private var countries: [Profile] { model.state.profiles.filter { $0.pingOutbound != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !modes.isEmpty {
                        MonoLabel("Режимы").padding(.leading, 6)
                        ForEach(Array(modes.enumerated()), id: \.element.id) { index, profile in
                            row(profile, index: index)
                        }
                    }
                    MonoLabel("Страны · \(countries.count)").padding(.leading, 6).padding(.top, modes.isEmpty ? 0 : 14)
                    ForEach(Array(countries.enumerated()), id: \.element.id) { index, profile in
                        row(profile, index: modes.count + index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { await model.refresh() }
            .scrollContentBackground(.hidden)
            .background(BrandBackground(glow: 0.2, glowCenter: UnitPoint(x: 0.5, y: 0)))
            .navigationTitle("Серверы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if model.isMeasuring {
                        ProgressView().tint(Brand.blueSoft)
                    } else {
                        Button {
                            Task { await model.measureDelays() }
                        } label: {
                            Label("Скорость", systemImage: "speedometer").labelStyle(.titleAndIcon)
                        }
                        .disabled(model.isConnected)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onAppear { appeared = true }
    }

    private func row(_ profile: Profile, index: Int) -> some View {
        let name = ProfileName(profile.name)
        let selected = model.state.selectedProfile?.id == profile.id
        return Button {
            Task { await model.select(profile) }
        } label: {
            HStack(spacing: 14) {
                CodeBadge(code: name.code, isMode: profile.pingOutbound == nil, selected: selected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name.title)
                        .font(.geist(17, .semibold))
                        .foregroundStyle(Brand.text)
                    if profile.pingOutbound == nil {
                        Text("Несколько серверов, выбирает сам")
                            .font(.geist(13))
                            .foregroundStyle(Brand.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                if profile.pingOutbound != nil {
                    PingBadge(delay: model.delays[profile.id])
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? Brand.blueBright : Color.white.opacity(0.18))
                    .shadow(color: Brand.blueBright.opacity(selected ? 0.7 : 0), radius: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), highlighted: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.98))
        .animation(.spring(response: 0.3, dampingFraction: 1), value: selected)
        // Строки выезжают лесенкой при открытии шторки.
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 14)
        .animation(.spring(response: 0.45, dampingFraction: 0.9).delay(Double(min(index, 12)) * 0.03), value: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Код страны в рамке вместо флага-эмодзи: строже, в одном стиле с подписями и одинаково везде.
private struct CodeBadge: View {
    let code: String?
    let isMode: Bool
    let selected: Bool

    var body: some View {
        ZStack {
            if isMode {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Brand.blueSoft)
            } else {
                Text(code ?? "··")
                    .font(.mono(14, bold: true))
                    .foregroundStyle(Brand.text)
            }
        }
        .frame(width: 44, height: 44)
        .glass(in: RoundedRectangle(cornerRadius: 12, style: .continuous), highlighted: selected)
    }
}

/// Пинг: число и три полоски — зелёные, жёлтые, оранжевые.
private struct PingBadge: View {
    /// nil — не мерили, .some(nil) — не ответил.
    let delay: Int??

    private var level: Int {
        guard let measured = delay, let ms = measured else { return 0 }
        return ms < 150 ? 3 : (ms < 400 ? 2 : 1)
    }

    private var color: Color {
        switch level {
        case 3: return Brand.green
        case 2: return Brand.amber
        default: return Brand.red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if let measured = delay {
                Text(measured.map { "\($0) мс" } ?? "нет ответа")
                    .font(.mono(12))
                    .foregroundStyle(measured == nil ? Brand.red : Brand.textSecondary)
                    .contentTransition(.numericText())
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...3, id: \.self) { bar in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(bar <= level ? color : Color.white.opacity(0.14))
                        .frame(width: 4, height: CGFloat(4 + bar * 4))
                }
            }
        }
        .animation(.snappy, value: level)
    }
}
