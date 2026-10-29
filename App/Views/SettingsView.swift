import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let subscription = model.state.subscription {
                        group("Список серверов") {
                            Button {
                                Task { await model.refresh() }
                            } label: {
                                cell("Обновить", icon: "arrow.clockwise") {
                                    if model.isRefreshing {
                                        ProgressView().tint(Brand.blueSoft)
                                    } else {
                                        Text(subscription.updatedAt, style: .relative)
                                            .font(.geist(15))
                                            .foregroundStyle(Brand.textSecondary)
                                    }
                                }
                            }
                            .buttonStyle(PressScale(scale: 0.98))
                            // Ссылку на кабинет и объявление панели не показываем: там продление,
                            // а оплата в обход покупок App Store — повод для отказа на ревью.
                            if let url = subscription.supportURL {
                                divider
                                Link(destination: url) {
                                    cell("Поддержка", icon: "bubble.left.and.text.bubble.right") {
                                        Image(systemName: "arrow.up.right").foregroundStyle(Brand.textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    if let url = AppModel.privacyPolicyURL {
                        group("Данные") {
                            Link(destination: url) {
                                cell("Конфиденциальность", icon: "hand.raised") {
                                    Image(systemName: "arrow.up.right").foregroundStyle(Brand.textSecondary)
                                }
                            }
                        }
                    }

                    group("О приложении") {
                        cell("Версия", icon: "info.circle") {
                            Text(Self.appVersion).font(.mono(13)).foregroundStyle(Brand.textSecondary)
                        }
                        divider
                        cell("Ядро Xray", icon: "cpu") {
                            Text(Xray.version() ?? "—").font(.mono(13)).foregroundStyle(Brand.textSecondary)
                        }
                    }

                    Button {
                        confirmRemove = true
                    } label: {
                        Text("Удалить серверы с устройства")
                            .font(.geist(16, .semibold))
                            .foregroundStyle(Brand.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(PressScale(scale: 0.98))
                }
                .padding(16)
            }
            .background(BrandBackground(glow: 0.15, glowCenter: UnitPoint(x: 0.5, y: 0)))
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Brand.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog("Удалить серверы и профиль VPN?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    Task {
                        await model.removeSubscription()
                        dismiss()
                    }
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(title).padding(.leading, 6)
            VStack(spacing: 0) { content() }
                .glass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func cell<Accessory: View>(_ title: String, icon: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Brand.blueSoft)
                .frame(width: 24)
            Text(title)
                .font(.geist(16, .medium))
                .foregroundStyle(Brand.text)
                .multilineTextAlignment(.leading)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1).padding(.leading, 54)
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
