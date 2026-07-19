import SwiftUI
import WebKit

/// WebView 包装器：加载平台登录页并监听 Cookie 变化
struct PlatformWebView: NSViewRepresentable {
    let platform: MusicPlatform
    let onLoginDetected: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // 加载登录页
        if let url = URL(string: platform.loginURL) {
            webView.load(URLRequest(url: url))
        }

        // 启动 Cookie 轮询检测
        context.coordinator.startCookiePolling(webView: webView)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(platform: platform, onLoginDetected: onLoginDetected)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let platform: MusicPlatform
        let onLoginDetected: () -> Void
        private var pollingTimer: Timer?
        private var loginDetected = false

        init(platform: MusicPlatform, onLoginDetected: @escaping () -> Void) {
            self.platform = platform
            self.onLoginDetected = onLoginDetected
        }

        /// 轮询检测 Cookie 变化（每 2 秒检查一次）
        func startCookiePolling(webView: WKWebView) {
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                guard let self = self, !self.loginDetected else {
                    self?.pollingTimer?.invalidate()
                    return
                }
                Task { @MainActor in
                    await self.checkLoginCookies(webView: webView)
                }
            }
        }

        @MainActor
        private func checkLoginCookies(webView: WKWebView) async {
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            let cookies = await cookieStore.allCookies()

            // 检查是否包含登录关键 Cookie
            let cookieNames = Set(cookies.map { $0.name })
            let hasAllKeys = platform.loginCookieKeys.allSatisfy { cookieNames.contains($0) }

            if hasAllKeys && !loginDetected {
                loginDetected = true
                pollingTimer?.invalidate()
                pollingTimer = nil

                // 关键：立即通过 MusicPlatformService 保存 Cookie 到 Keychain
                _ = await MusicPlatformService.shared.captureCookies(from: webView, for: platform)

                onLoginDetected()
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            // 允许所有导航（登录可能涉及多次跳转）
            return .allow
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 页面加载完成后立即检查一次
            Task { @MainActor in
                await checkLoginCookies(webView: webView)
            }
        }

        // MARK: - WKUIDelegate

        /// 处理新窗口请求（QQ 登录可能弹出新窗口）
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // 在当前 WebView 中加载，避免弹窗被拦截
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        deinit {
            pollingTimer?.invalidate()
        }
    }
}

/// 平台登录弹窗视图
struct PlatformLoginView: View {
    @ObservedObject var platformService = MusicPlatformService.shared
    @Environment(\.dismiss) private var dismiss

    let platform: MusicPlatform
    @State private var loginStatus: String = "请使用手机扫码或账号密码登录"
    @State private var isLoginSuccess: Bool = false
    @State private var showSuccessAnimation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Label(platform.rawValue, systemImage: platform.icon)
                    .font(.headline)

                Spacer()

                if isLoginSuccess {
                    Label("登录成功", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(loginStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if isLoginSuccess {
                // 登录成功界面
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
                        .opacity(showSuccessAnimation ? 1.0 : 0)

                    Text("登录成功！")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let account = platformService.accounts[platform] {
                        Text("欢迎，\(account.nickname)")
                            .foregroundStyle(.secondary)
                    }

                    Text("现在可以浏览你的歌单并批量下载了")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("开始浏览歌单") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(32)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        showSuccessAnimation = true
                    }
                }
            } else {
                // WebView 登录区
                PlatformWebView(platform: platform) {
                    // 检测到登录 Cookie
                    Task { @MainActor in
                        await handleLoginSuccess()
                    }
                }
                .frame(minWidth: 500, minHeight: 500)
            }
        }
        .frame(width: 560, height: 620)
    }

    @MainActor
    private func handleLoginSuccess() async {
        loginStatus = "正在验证登录状态..."

        // 这里需要通过 WebView 捕获 Cookie
        // 由于 WebView 的 Cookie 已在 Coordinator 中检测到，
        // 我们通过 PlatformService 来完成后续处理
        // 注意：实际 Cookie 捕获在 WebView 的 cookieStore 中完成

        // 模拟短暂延迟让用户看到状态变化
        try? await Task.sleep(nanoseconds: 500_000_000)

        withAnimation {
            isLoginSuccess = true
        }

        // 自动加载歌单
        platformService.selectedPlatform = platform
        await platformService.loadPlaylists()
    }
}

/// 平台登录入口组件（嵌入设置或歌单页面）
struct PlatformLoginEntryView: View {
    @ObservedObject var platformService = MusicPlatformService.shared
    @State private var showLoginSheet: Bool = false
    @State private var loginPlatform: MusicPlatform = .netease

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("音乐平台账号")
                .font(.headline)

            ForEach(MusicPlatform.allCases, id: \.self) { platform in
                HStack {
                    Image(systemName: platform.icon)
                        .frame(width: 24)

                    Text(platform.rawValue)
                        .font(.body)

                    Spacer()

                    if let account = platformService.accounts[platform], account.isLoggedIn {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text(account.nickname)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("退出") {
                                platformService.logout(platform: platform)
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    } else {
                        Button("登录") {
                            loginPlatform = platform
                            showLoginSheet = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            PlatformLoginView(platform: loginPlatform)
        }
    }
}
