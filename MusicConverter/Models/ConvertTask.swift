import Foundation

/// 统一转换任务模型（音频格式转换 + 网易云 NCM 解密）
struct ConvertTask: Identifiable {
    let id = UUID()
    var inputPath: String
    var title: String = ""
    var kind: TaskKind = .convert
    var status: TaskStatus = .pending
    var progress: Double = 0.0
    var outputPath: String = ""
    var format: String = ""        // 输出格式（转换固定 MP3 / 解密后的原始格式）
    var fileSize: String = ""
    var bitrate: String = "320k"
    var errorMessage: String?

    /// 任务类型
    enum TaskKind: String {
        case convert = "转换"
        case decrypt = "解密"
    }

    enum TaskStatus: String {
        case pending = "等待中"
        case converting = "转换中"
        case decrypting = "解密中"
        case completed = "已完成"
        case failed = "失败"
    }
}
