import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Российские сайты напрямую",
                        isOn: Binding(
                            get: { model.state.directDomestic },
                            set: { value in Task { await model.setDirectDomestic(value) } }
                        )
                    )
                } footer: {
                    Text("Банки, Госуслуги и маркетплейсы откроются без VPN — с иностранного адреса они часто не пускают.")
                }

                if let subscription = model.state.subscription {
                    Section("Подписка") {
                        Button {
                            Task { await model.refresh() }
                        } label: {
                            HStack {
                                Text("Обновить")
                                Spacer()
                                if model.isRefreshing {
                                    ProgressView()
                                } else {
                                    Text(subscription.updatedAt, style: .relative)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let url = subscription.supportURL {
                            Link("Поддержка", destination: url)
                        }
                        if let url = subscription.webPageURL {
                            Link("Личный кабинет", destination: url)
                        }
                        if let announce = subscription.announce {
                            Text(announce)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button("Удалить подписку с устройства", role: .destructive) {
                        confirmRemove = true
                    }
                }

                Section("О приложении") {
                    LabeledContent("Версия", value: Self.appVersion)
                    LabeledContent("Ядро", value: Xray.version() ?? "—")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog("Удалить подписку и профиль VPN?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    Task {
                        await model.removeSubscription()
                        dismiss()
                    }
                }
            }
        }
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
