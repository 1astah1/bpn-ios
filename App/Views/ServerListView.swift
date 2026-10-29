import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                row(title: "Автовыбор", subtitle: "Самый быстрый сервер, при обрыве — следующий", selection: .auto, delay: nil)
            }
            Section("Серверы") {
                ForEach(model.state.servers) { server in
                    row(title: server.name, subtitle: nil, selection: .server(id: server.id), delay: model.delays[server.id])
                }
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

    /// `delay`: nil — не мерили, .some(nil) — не ответил.
    private func row(title: String, subtitle: String?, selection: ServerSelection, delay: Int??) -> some View {
        Button {
            Task { await model.select(selection) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let delay {
                    Text(delay.map { "\($0) мс" } ?? "нет ответа")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(delay == nil ? Color.red : .secondary)
                }
                if model.state.selection == selection {
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
