import SwiftUI

@main
struct MusicConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var activationManager = ActivationManager.shared
    @StateObject private var updateChecker = UpdateCheckerService.shared
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
                    // 静默检查版本更新（24 小时最多一次）
                    updateChecker.autoCheckOnLaunch()
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
                .alert("发现新版本 v\(updateChecker.latestVersion)", isPresented: $updateChecker.showUpdateAlert) {
                    Button("前往下载") { updateChecker.openDownloadPage() }
                    Button("稍后再说", role: .cancel) { }
                } message: {
                    Text("当前版本 v\(updateChecker.currentVersion)，建议更新以获得最新功能与修复。")
                }
                .alert("已是最新版本", isPresented: $updateChecker.showUpToDateAlert) {
                    Button("好的") { }
                } message: {
                    Text("当前版本 v\(updateChecker.currentVersion) 已是最新。")
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
                Button("检查更新…") {
                    Task { await UpdateCheckerService.shared.check() }
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }

        // 下载状态窗口：监视批量下载队列（可随时打开，不影响主窗口）
        Window("下载状态", id: "download-status") {
            DownloadStatusView()
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
        .defaultSize(width: 480, height: 520)
        .windowResizability(.contentMinSize)
    }
}
