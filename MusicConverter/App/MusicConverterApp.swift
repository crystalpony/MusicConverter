import SwiftUI

@main
struct MusicConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var activationManager = ActivationManager.shared
    @State private var showProPurchase: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var showAbout: Bool = false

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
                .onReceive(NotificationCenter.default.publisher(for: .showAbout)) { _ in
                    showAbout = true
                }
                .sheet(isPresented: $showAbout) {
                    AboutView()
                        .preferredColorScheme(settings.appearanceMode.colorScheme)
                }
                .sheet(isPresented: $showProPurchase) {
                    ProPurchaseView()
                        .environmentObject(settings)
                        .preferredColorScheme(settings.appearanceMode.colorScheme)
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .environmentObject(settings)
                        .preferredColorScheme(settings.appearanceMode.colorScheme)
                }
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 Tunely") {
                    NotificationCenter.default.post(name: .showAbout, object: nil)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
    }
}
