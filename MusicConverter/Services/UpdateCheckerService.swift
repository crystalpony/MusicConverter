import Foundation
import AppKit

/// 版本更新检查服务（全局单例）
/// 通过 GitHub Releases API 获取最新版本号，与本地版本比对；
/// 启动时静默自动检查（24 小时最多一次），发现新版本全局弹窗提醒
@MainActor
final class UpdateCheckerService: ObservableObject {
    static let shared = UpdateCheckerService()

    /// GitHub 仓库（owner/repo）
    static let repo = "crystalpony/MusicConverter"

    /// 是否正在检查
    @Published var isChecking: Bool = false
    /// 是否有新版本可用
    @Published var updateAvailable: Bool = false
    /// 最新版本号（不含 v 前缀）
    @Published var latestVersion: String = ""
    /// 更新说明（Release body）
    @Published var releaseNotes: String = ""
    /// Release 页面地址
    @Published var releaseURL: String = "https://github.com/\(UpdateCheckerService.repo)/releases/latest"
    /// DMG 直接下载地址（Release Assets 中的 .dmg）
    @Published var downloadURL: String?
    /// 最近一次检查时间
    @Published var lastCheckDate: Date?
    /// 检查失败原因
    @Published var checkError: String?
    /// 触发"发现新版本"弹窗
    @Published var showUpdateAlert: Bool = false
    /// 触发"已是最新版本"弹窗（手动检查时）
    @Published var showUpToDateAlert: Bool = false

    /// 当前应用版本号
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private init() {}

    // MARK: - GitHub Release 模型

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        let body: String?
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case assets
        }
    }

    // MARK: - 检查逻辑

    /// 启动时静默自动检查（24 小时最多一次）
    func autoCheckOnLaunch() {
        let key = "lastUpdateAutoCheckTime"
        let last = UserDefaults.standard.double(forKey: key)
        let now = Date().timeIntervalSince1970
        guard now - last > 24 * 3600 else { return }
        UserDefaults.standard.set(now, forKey: key)
        Task { await check(silent: true) }
    }

    /// 检查更新
    /// - Parameter silent: true 时仅在发现新版本才弹窗（用于启动自动检查）
    func check(silent: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        checkError = nil
        defer {
            isChecking = false
            lastCheckDate = Date()
        }

        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                checkError = "GitHub 响应异常，请稍后重试"
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let remote = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            latestVersion = remote
            releaseNotes = release.body ?? ""
            releaseURL = release.htmlURL
            downloadURL = release.assets
                .first { $0.name.lowercased().hasSuffix(".dmg") }?
                .browserDownloadURL

            updateAvailable = Self.isVersion(remote, newerThan: currentVersion)
            if updateAvailable {
                showUpdateAlert = true
            } else if !silent {
                showUpToDateAlert = true
            }
        } catch {
            checkError = "检查更新失败：\(error.localizedDescription)"
        }
    }

    /// 打开下载页（优先 DMG 直链，其次 Release 页面）
    func openDownloadPage() {
        let urlString = downloadURL ?? releaseURL
        if let u = URL(string: urlString) {
            NSWorkspace.shared.open(u)
        }
    }

    // MARK: - 版本比较

    /// 语义化版本比较：a 是否比 b 新（按 . 分段逐位比较数字）
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let av = a.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        let bv = b.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        for i in 0..<max(av.count, bv.count) {
            let x = i < av.count ? av[i] : 0
            let y = i < bv.count ? bv[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
