import SwiftUI

/// 外观模式（跟随系统 / 浅色 / 深色）
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
    /// SwiftUI 首选配色方案（nil = 跟随系统）
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 全局应用设置，使用 @AppStorage 持久化
@MainActor
class AppSettings: ObservableObject {
    @AppStorage("outputDirectory") var outputDirectory: String = "~/Downloads/MusicConverter"
    @AppStorage("defaultBitrate") var defaultBitrate: String = "320k"
    @AppStorage("proxyAddress") var proxyAddress: String = ""
    @AppStorage("cookieFilePath") var cookieFilePath: String = ""
    /// 从浏览器自动读取 Cookie 的来源（空 = 关闭）；值为 yt-dlp --cookies-from-browser 接受的浏览器名
    @AppStorage("cookieBrowser") var cookieBrowser: String = ""
    @AppStorage("useProxy") var useProxy: Bool = false
    @AppStorage("menuBarEnabled") var menuBarEnabled: Bool = false
    /// 外观模式（跟随系统 / 浅色 / 深色）
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    @AppStorage("isPro") var isPro: Bool = false
    @AppStorage("bonusConversions") var bonusConversions: Int = 0

    // MARK: - v2.0 平台账号相关

    /// 是否使用平台 Cookie 进行下载（优先于手动 Cookie 文件）
    @AppStorage("usePlatformCookies") var usePlatformCookies: Bool = true

    /// 批量下载并发数（串行队列，1 = 逐个下载）
    @AppStorage("batchConcurrency") var batchConcurrency: Int = 1

    /// 累计下载歌曲数（用于成就系统）
    @AppStorage("totalDownloadCount") var totalDownloadCount: Int = 0

    /// 累计节省时间（分钟，用于效率可视化）
    @AppStorage("totalSavedMinutes") var totalSavedMinutes: Int = 0

    /// 是否已完成首次引导
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    static let bitrateOptions = ["128k", "192k", "256k", "320k"]

    /// 浏览器 Cookie 来源选项：(显示名, yt-dlp 值)；空值表示关闭。推荐 Firefox/Chrome，Safari 受系统限制常失败
    static let cookieBrowserOptions: [(String, String)] = [
        ("关闭", ""),
        ("Firefox（推荐）", "firefox"),
        ("Chrome", "chrome"),
        ("Edge", "edge"),
        ("Brave", "brave"),
        ("Safari（需完全磁盘访问）", "safari"),
    ]

    /// 免费版批量转换基础上限
    static let freeBatchLimit = 3

    /// 免费版试下载总上限（累计）
    static let freeDownloadLimit = 5

    /// 免费版有效转换上限（基础上限 + 彩蛋赠送次数）
    var effectiveConvertLimit: Int {
        Self.freeBatchLimit + bonusConversions
    }

    /// 免费版剩余可下载次数
    var remainingFreeDownloads: Int {
        max(0, Self.freeDownloadLimit - totalDownloadCount)
    }

    /// 是否已达到免费试下载上限
    var isDownloadLimitReached: Bool {
        remainingFreeDownloads <= 0
    }

    /// 获取展开后的输出目录路径
    var resolvedOutputDirectory: String {
        (outputDirectory as NSString).expandingTildeInPath
    }

    /// 获取有效的 Cookie 文件路径（优先平台 Cookie，其次手动配置）
    var effectiveCookieFilePath: String? {
        if usePlatformCookies {
            if let mergedPath = MusicPlatformService.shared.mergedCookieFilePath() {
                return mergedPath
            }
        }
        return cookieFilePath.isEmpty ? nil : cookieFilePath
    }

    /// 有效的浏览器 Cookie 来源（nil = 关闭）
    var effectiveCookieBrowser: String? {
        cookieBrowser.isEmpty ? nil : cookieBrowser
    }
}
