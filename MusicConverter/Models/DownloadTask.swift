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

    enum TaskStatus: String {
        case pending = "等待中"
        case downloading = "下载中"
        case converting = "转换中"
        case completed = "已完成"
        case failed = "失败"
    }
}
