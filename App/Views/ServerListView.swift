import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            ForEach(model.state.profiles) { profile in
                row(profile)
            }
        }
        .navigationTitle("Сервер")
        .refreshable { await model.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.isMeasuring {
                    ProgressView()
                } else {
                    Button("Скорость") {
                        Task { await model.measureDelays() }
                    }
                    .disabled(model.isConnected)
                }
            }
        }
    }

    private func row(_ profile: Profile) -> some View {
        Button {
            Task { await model.select(profile) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .foregroundStyle(.primary)
                    if profile.pingOutbound == nil {
                        Text("Несколько серверов, выбирает сам")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // nil — не мерили, .some(nil) — не ответил.
                if let delay = model.delays[profile.id] {
                    Text(delay.map { "\($0) мс" } ?? "нет ответа")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(delay == nil ? Color.red : Color.secondary)
                }
                if model.state.selectedProfile?.id == profile.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
