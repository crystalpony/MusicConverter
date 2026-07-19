import SwiftUI

@main
struct MusicConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var activationManager = ActivationManager.shared
    @State private var showProPurchase: Bool = false
    @State private var showOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(activationManager)
                .frame(minWidth: 700, minHeight: 500)
                .onAppear {
                    appDelegate.configure(settings: settings)
                    // 启动时扫描输出目录，初始化音乐库
                    Task {
                        await MusicLibraryStore.shared.scanDirectory(settings.resolvedOutputDirectory)
                    }
                    // 同步激活状态到 settings
                    settings.isPro = activationManager.isPro
                    // 首次启动显示引导
                    if !settings.hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .onReceive(activationManager.$isPro) { isPro in
                    settings.isPro = isPro
                }
                .onReceive(NotificationCenter.default.publisher(for: .showProPurchase)) { _ in
                    showProPurchase = true
                }
                .sheet(isPresented: $showProPurchase) {
                    ProPurchaseView()
                        .environmentObject(settings)
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .environmentObject(settings)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}
