import SwiftUI

@main
struct UmbraApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Brand.blueBright)
                .task { await model.onLaunch() }
                .onOpenURL { url in
                    Task { await model.handleOpenURL(url) }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.state.subscription == nil {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .alert(
            "Не получилось",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }),
            presenting: model.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
}
