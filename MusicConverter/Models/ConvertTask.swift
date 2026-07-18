import Foundation

/// 本地文件转换任务模型
struct ConvertTask: Identifiable {
    let id = UUID()
    var inputPath: String
    var title: String = ""
    var status: TaskStatus = .pending
    var progress: Double = 0.0
    var outputPath: String = ""
    var fileSize: String = ""
    var bitrate: String = "320k"
    var errorMessage: String?

    enum TaskStatus: String {
        case pending = "等待中"
        case converting = "转换中"
        case completed = "已完成"
        case failed = "失败"
    }
}
