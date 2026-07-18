import Foundation

/// NCM 解密任务模型
struct NCMTask: Identifiable {
    let id = UUID()
    var inputPath: String
    var title: String = ""
    var status: TaskStatus = .pending
    var outputPath: String = ""
    var format: String = ""
    var fileSize: String = ""
    var errorMessage: String?

    enum TaskStatus: String {
        case pending = "等待中"
        case decrypting = "解密中"
        case completed = "已完成"
        case failed = "失败"
    }
}
