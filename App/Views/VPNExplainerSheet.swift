import SwiftUI

/// Перед системным окном «Добавить конфигурацию VPN»: текст системного окна поменять нельзя,
/// а ревью отклоняет VPN, если пользователю не объяснили, что произойдёт с данными.
struct VPNExplainerSheet: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonoLabel("Первое подключение")
            Text("iOS попросит добавить конфигурацию VPN")
                .font(.geist(26, .bold, relativeTo: .title))
                .tracking(-0.5)
                .foregroundStyle(Brand.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Через неё трафик устройства пойдёт на выбранный вами сервер. Приложение не записывает, какие сайты вы открываете, и ничего не передаёт третьим лицам. Отключить VPN можно в любой момент здесь или в Настройках iOS.")
                .font(.geist(16))
                .foregroundStyle(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            PrimaryButton(title: "Продолжить") {
                Task { await model.confirmVPNExplainer() }
            }
        }
        .padding(24)
        .padding(.top, 8)
        .presentationDetents([.height(400)])
        .presentationBackground(Brand.background)
        .presentationCornerRadius(30)
        .presentationDragIndicator(.visible)
    }
}
