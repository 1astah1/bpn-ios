import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var link = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Добавьте подписку")
                    .font(.largeTitle.bold())
                Text("Скопируйте ссылку подписки в боте или личном кабинете — приложение подхватит её из буфера.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Button {
                    guard let text = UIPasteboard.general.string else {
                        model.errorMessage = "В буфере обмена нет ссылки"
                        return
                    }
                    Task { await model.addSubscription(text) }
                } label: {
                    Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack {
                    TextField("https://…", text: $link)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .focused($fieldFocused)
                        .onSubmit(add)
                    Button("Добавить", action: add)
                        .disabled(link.isEmpty)
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(model.isRefreshing)
            .overlay {
                if model.isRefreshing { ProgressView() }
            }

            Spacer()
            Spacer()
        }
        .padding(24)
    }

    private func add() {
        fieldFocused = false
        let text = link
        Task { await model.addSubscription(text) }
    }
}
