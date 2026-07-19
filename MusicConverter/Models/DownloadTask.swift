import Foundation

/// 下载任务模型
struct DownloadTask: Identifiable {
    let id = UUID()
    var url: String
    var title: String = ""
    var platform: String = ""
    var status: TaskStatus = .pending
    var progress: Double = 0.0
    var outputPath: String = ""
    var fileSize: String = ""
    var bitrate: String = "320k"
    var format: String = DownloadFormat.audioMP3.rawValue
    var errorMessage: String?

    // MARK: - v2.0 歌单批量下载扩展字段

    /// 来源歌单名称
    var sourcePlaylist: String = ""
    /// 艺人
    var artist: String = ""
    /// 时长（秒）
    var duration: TimeInterval = 0
    /// 来源平台（MusicPlatform）
    var sourcePlatform: String = ""
    /// 歌曲 ID（平台内唯一标识）
    var songId: String = ""

    enum TaskStatus: String {
        case pending = "等待中"
        case downloading = "下载中"
        case converting = "转换中"
        case completed = "已完成"
        case failed = "失败"
        case skipped = "已跳过"
    }
}
