import SwiftUI

/// 全局应用设置，使用 @AppStorage 持久化
@MainActor
class AppSettings: ObservableObject {
    @AppStorage("outputDirectory") var outputDirectory: String = "~/Downloads/MusicConverter"
    @AppStorage("defaultBitrate") var defaultBitrate: String = "320k"
    @AppStorage("proxyAddress") var proxyAddress: String = ""
    @AppStorage("cookieFilePath") var cookieFilePath: String = ""
    @AppStorage("useProxy") var useProxy: Bool = false
    @AppStorage("menuBarEnabled") var menuBarEnabled: Bool = false
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

    /// 免费版批量转换基础上限
    static let freeBatchLimit = 3

    /// 免费版有效转换上限（基础上限 + 彩蛋赠送次数）
    var effectiveConvertLimit: Int {
        Self.freeBatchLimit + bonusConversions
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
}
