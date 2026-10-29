import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var link = ""
    @State private var appeared = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            BrandBackground(glow: 0.45, glowCenter: UnitPoint(x: 0.5, y: 0.3))

            VStack(spacing: 0) {
                Spacer()
                HexKnob(mode: .lit, size: 140)
                    .shadow(color: Brand.blueBright.opacity(0.3), radius: 30)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.8)
                    .opacity(appeared || reduceMotion ? 1 : 0)

                VStack(spacing: 12) {
                    Text("Подключите\nподписку")
                        .font(.geist(38, .bold, relativeTo: .largeTitle))
                        .tracking(-1)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Brand.text)
                    Text("Скопируйте ссылку подписки в боте или личном кабинете и вставьте её сюда.")
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
                    Button(action: paste) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.clipboard.fill")
                            Text("Вставить ссылку")
                        }
                        .font(.geist(18, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background {
                            Capsule()
                                .fill(LinearGradient(colors: [Brand.blueBright, Brand.blue], startPoint: .top, endPoint: .bottom))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                                .shadow(color: Brand.blueBright.opacity(0.5), radius: 20, y: 6)
                        }
                    }
                    .buttonStyle(PressScale())

                    HStack(spacing: 10) {
                        TextField("", text: $link, prompt: Text("https://…").foregroundStyle(Brand.textSecondary.opacity(0.6)))
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
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { appeared = true }
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
