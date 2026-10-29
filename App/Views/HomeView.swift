import NetworkExtension
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showServers = false
    @State private var showSettings = false

    private var profileName: ProfileName? { model.state.selectedProfile.map { ProfileName($0.name) } }
    private var glow: Double { model.isConnected ? 1 : (model.wantsConnection ? 0.55 : 0) }

    var body: some View {
        ZStack {
            BrandBackground(glow: glow)
                .animation(.easeInOut(duration: 0.6), value: glow)

            GeometryReader { proxy in
                // Капсула занимает ~40% высоты: на iPhone SE она ниже, на Pro Max — не больше 304 pt.
                let capsuleHeight = min(304, max(210, proxy.size.height * 0.4))
                VStack(spacing: 0) {
                    topBar
                    header
                        .padding(.top, 14)
                    Spacer(minLength: 8)
                    stage(height: capsuleHeight)
                    Spacer(minLength: 8)
                    statusLine
                        .frame(height: 72)
                    Spacer(minLength: 12)
                    MetricsStrip()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showServers) {
            ServerSheet()
                .presentationDetents([.medium, .large])
                .presentationBackground(Brand.background)
                .presentationCornerRadius(30)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $model.showVPNExplainer) {
            VPNExplainerSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationBackground(Brand.background)
                .presentationCornerRadius(30)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.wantsConnection)
        .sensoryFeedback(trigger: model.status) { _, new in
            new == .connected ? .success : nil
        }
    }

    private var topBar: some View {
        HStack {
            Text(model.state.subscription?.title?.stripEmoji() ?? "")
                .font(.mono(13, bold: true))
                .tracking(2)
                .foregroundStyle(Brand.text.opacity(0.8))
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Brand.text)
                    .frame(width: 44, height: 44)
                    .glass(in: Circle())
            }
            .buttonStyle(PressScale(scale: 0.92))
            .accessibilityLabel("Настройки")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var header: some View {
        VStack(spacing: 10) {
            MonoLabel(model.statusCaption, color: model.isConnected ? Brand.green : Brand.blueSoft)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: model.statusCaption)
            Button {
                showServers = true
            } label: {
                HStack(spacing: 10) {
                    Text(profileName?.title ?? "Выберите сервер")
                        .font(.geist(34, .bold, relativeTo: .largeTitle))
                        .tracking(-0.8)
                        .foregroundStyle(Brand.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Brand.textSecondary)
                }
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .accessibilityIdentifier("server-picker")
            .accessibilityHint("Выбрать сервер")

            Text(model.selectedProfileCaption)
                .font(.geist(14, .medium))
                .foregroundStyle(Brand.textSecondary)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: model.selectedProfileCaption)
        }
    }

    /// Тумблер в центре — единственный акцент экрана.
    private func stage(height: CGFloat) -> some View {
        PowerCapsule(isOn: model.wantsConnection, knobMode: model.knobMode, height: height) {
            Task { await model.toggleConnection() }
        }
        .frame(height: height + 16)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let since = model.connectedSince {
            VStack(spacing: 4) {
                TimelineView(.periodic(from: since, by: 1)) { context in
                    let seconds = max(0, Int(context.date.timeIntervalSince(since)))
                    Text(Self.clock(seconds))
                        .font(.geist(40, .bold, relativeTo: .title))
                        .monospacedDigit()
                        .foregroundStyle(Brand.text)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.25), value: seconds)
                }
                MonoLabel("Время подключения", color: Brand.textSecondary, size: 11)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Text(model.wantsConnection ? "Подключаемся…" : "Потяните ручку вверх или нажмите")
                .font(.geist(15, .medium))
                .foregroundStyle(Brand.textSecondary)
                .transition(.opacity)
        }
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}

/// Полоса с цифрами внизу — как блок «скорость · серверы · поддержка» на баннере.
private struct MetricsStrip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.metrics.enumerated()), id: \.offset) { index, metric in
                if index > 0 {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 34)
                }
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(metric.value)
                            .font(.geist(24, .bold, relativeTo: .title2))
                            .monospacedDigit()
                            .foregroundStyle(Brand.text)
                            .contentTransition(.numericText())
                        Text(metric.unit)
                            .font(.geist(13, .semibold))
                            .foregroundStyle(Brand.blueSoft)
                    }
                    Text(metric.caption.uppercased())
                        .font(.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(Brand.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .glass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .animation(.snappy, value: model.metrics)
    }
}

struct Metric: Equatable {
    var value: String
    var unit: String
    var caption: String
}

extension AppModel {
    var statusCaption: String {
        switch status {
        case .connected: return "Подключено"
        case .connecting: return "Подключаемся"
        case .reasserting: return "Восстанавливаем связь"
        case .disconnecting: return "Отключаемся"
        default: return wantsConnection ? "Подключаемся" : "Не подключено"
        }
    }

    /// Под названием сервера: что внутри режима или пинг страны.
    var selectedProfileCaption: String {
        guard let profile = state.selectedProfile else { return " " }
        if profile.pingOutbound == nil {
            let count = profile.serverCount ?? 0
            return count > 1 ? "\(count) \(Self.serversWord(count)), выбирает быстрый" : "Выбирает быстрый сервер"
        }
        if let measured = delays[profile.id] {
            return measured.map { "Пинг \($0) мс" } ?? "Сервер не ответил"
        }
        return ProfileName(profile.name).code.map { "Сервер \($0)" } ?? " "
    }

    static func serversWord(_ count: Int) -> String {
        let tens = count % 100, ones = count % 10
        if (11...14).contains(tens) { return "серверов" }
        if ones == 1 { return "сервер" }
        if (2...4).contains(ones) { return "сервера" }
        return "серверов"
    }

    var knobMode: HexKnob.Mode {
        if status == .connected { return .lit }
        return wantsConnection || isBusy ? .spinning : .idle
    }

    var metrics: [Metric] {
        var result: [Metric] = []
        if let usage = state.subscription?.usage {
            if let expire = usage.expire {
                let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: expire).day ?? 0)
                result.append(Metric(value: "\(days)", unit: "дн", caption: "Осталось"))
            }
            let (value, unit) = Self.size(usage.used)
            result.append(Metric(value: value, unit: unit, caption: usage.total > 0 ? "из \(Self.size(usage.total).0) \(Self.size(usage.total).1)" : "Трафик"))
        }
        if let id = state.selectedProfile?.id, let measured = delays[id], let delay = measured {
            result.append(Metric(value: "\(delay)", unit: "мс", caption: "Пинг"))
        } else {
            let servers = Set(state.profiles.filter { $0.pingOutbound != nil }.compactMap { ProfileName($0.name).code }).count
            result.append(Metric(value: "\(servers)", unit: "", caption: "Стран"))
        }
        return result
    }

    private static func size(_ bytes: Int64) -> (String, String) {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 100 { return (String(format: "%.0f", gb), "ГБ") }
        if gb >= 1 { return (String(format: "%.1f", gb).replacingOccurrences(of: ".", with: ","), "ГБ") }
        return (String(format: "%.0f", Double(bytes) / 1_048_576), "МБ")
    }
}
