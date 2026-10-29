import SwiftUI
import UIKit

/// Первый запуск: сначала — какие данные передаются (App Review 5.4 требует показать это до использования сервиса),
/// потом — ссылка подписки.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            BrandBackground(glow: 0.45, glowCenter: UnitPoint(x: 0.5, y: 0.3))
            if model.state.privacyAcceptedAt == nil {
                PrivacyStep()
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .offset(x: -24))))
            } else {
                SubscriptionStep()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 24)), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 1), value: model.state.privacyAcceptedAt == nil)
    }
}

private struct PrivacyStep: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)
            MonoLabel("Данные и приватность")
            Text("Что приложение\nпередаёт")
                .font(.geist(34, .bold, relativeTo: .largeTitle))
                .tracking(-0.9)
                .foregroundStyle(Brand.text)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 22) {
                item("link", "Ссылку, которую вы добавите", "Только чтобы загрузить список серверов по ней.")
                item("iphone", "Идентификатор устройства, модель и версию iOS",
                     "Только тому серверу из ссылки, который сам ведёт лимит устройств. Больше никуда.")
                item("eye.slash", "Не хранит историю и трафик",
                     "Приложение не ведёт журнал посещённых сайтов, не продаёт и не передаёт данные третьим лицам.")
            }
            .padding(.top, 32)

            Spacer(minLength: 24)

            if let url = AppModel.privacyPolicyURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text("Политика конфиденциальности")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.geist(15, .semibold))
                    .foregroundStyle(Brand.blueSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            }

            PrimaryButton(title: "Понятно, продолжить") {
                model.acceptPrivacy()
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }

    private func item(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Brand.blueSoft)
                .frame(width: 44, height: 44)
                .glass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.geist(17, .semibold))
                    .foregroundStyle(Brand.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(.geist(15))
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SubscriptionStep: View {
    @EnvironmentObject private var model: AppModel
    @State private var link = ""
    @State private var appeared = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HexKnob(mode: .lit, size: 140)
                .shadow(color: Brand.blueBright.opacity(0.3), radius: 30)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
                .opacity(appeared || reduceMotion ? 1 : 0)

            VStack(spacing: 12) {
                Text("Добавьте\nсерверы")
                    .font(.geist(38, .bold, relativeTo: .largeTitle))
                    .tracking(-1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Brand.text)
                Text("Вставьте ссылку на список серверов или конфиг: vless://, vmess://, trojan://, ss://, hysteria2://")
                    .font(.geist(16))
                    .foregroundStyle(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 36)
            .offset(y: appeared || reduceMotion ? 0 : 16)
            .opacity(appeared || reduceMotion ? 1 : 0)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Вставить из буфера", icon: "doc.on.clipboard.fill", action: paste)

                HStack(spacing: 10) {
                    TextField("", text: $link, prompt: Text("https://… или vless://…").foregroundStyle(Brand.textSecondary.opacity(0.6)))
                        .font(.mono(15))
                        .foregroundStyle(Brand.text)
                        .tint(Brand.blueBright)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .focused($fieldFocused)
                        .onSubmit(add)
                    Button("Добавить", action: add)
                        .font(.geist(15, .semibold))
                        .foregroundStyle(link.isEmpty ? Brand.textSecondary : Brand.blueSoft)
                        .disabled(link.isEmpty)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .glass(in: Capsule(), highlighted: fieldFocused)
                .animation(.easeOut(duration: 0.2), value: fieldFocused)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .disabled(model.isRefreshing)
            .overlay {
                if model.isRefreshing { ProgressView().tint(.white) }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { appeared = true }
        }
    }

    private func paste() {
        guard let text = UIPasteboard.general.string else {
            model.errorMessage = "В буфере обмена нет ссылки"
            return
        }
        Task { await model.addSubscription(text) }
    }

    private func add() {
        fieldFocused = false
        let text = link
        Task { await model.addSubscription(text) }
    }
}

/// Главная кнопка: синяя капсула с мягким светом.
struct PrimaryButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.geist(18, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background {
                Capsule()
                    .fill(LinearGradient(colors: [Brand.blueBright, Brand.blue], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                    .shadow(color: Brand.blueBright.opacity(0.4), radius: 18, y: 6)
            }
        }
        .buttonStyle(PressScale())
    }
}
