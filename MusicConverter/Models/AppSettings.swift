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
}
