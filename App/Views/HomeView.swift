import NetworkExtension
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                if let subscription = model.state.subscription {
                    SubscriptionSummary(subscription: subscription)
                }

                Spacer()

                ConnectButton(status: model.status) {
                    Task { await model.toggleConnection() }
                }

                Text(model.status.title)
                    .font(.headline)
                    .foregroundStyle(model.isConnected ? Color.accentColor : .secondary)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: model.status)

                Spacer()

                NavigationLink {
                    ServerListView()
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text(model.selectedServerName)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle(model.state.subscription?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Настройки")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

private struct ConnectButton: View {
    let status: NEVPNStatus
    let action: () -> Void

    private var isOn: Bool { status == .connected }
    private var isBusy: Bool { [.connecting, .disconnecting, .reasserting].contains(status) }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isOn ? Color.accentColor : Color(.secondarySystemFill))
                Circle()
                    .strokeBorder(Color.accentColor.opacity(isOn ? 0.35 : 0), lineWidth: 10)
                    .padding(-14)
                if isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .tint(isOn ? .white : .accentColor)
                } else {
                    Image(systemName: "power")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
            }
            .frame(width: 176, height: 176)
        }
        .buttonStyle(PressScaleStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: isOn)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: status)
        .accessibilityLabel(isOn ? "Отключить" : "Подключить")
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SubscriptionSummary: View {
    let subscription: Subscription

    var body: some View {
        if let usage = subscription.usage {
            HStack(spacing: 12) {
                if let expire = usage.expire {
                    Metric(title: "Осталось", value: Self.daysLeft(until: expire))
                }
                Metric(
                    title: "Трафик",
                    value: usage.total > 0
                        ? "\(Self.bytes(usage.used)) из \(Self.bytes(usage.total))"
                        : Self.bytes(usage.used)
                )
            }
        }
    }

    private static func daysLeft(until date: Date) -> String {
        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
        return days == 0 ? "меньше дня" : "\(days) дн."
    }

    private static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .binary)
    }
}

private struct Metric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension NEVPNStatus {
    var title: String {
        switch self {
        case .connected: return "Подключено"
        case .connecting: return "Подключаемся…"
        case .reasserting: return "Восстанавливаем связь…"
        case .disconnecting: return "Отключаемся…"
        case .disconnected, .invalid: return "Не подключено"
        @unknown default: return "Не подключено"
        }
    }
}
