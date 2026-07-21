import Foundation

/// 服务层统一错误类型
enum ServiceError: LocalizedError {
    case toolNotFound(String)
    case processFailed(String, Int32)
    case noOutputFile
    case noNCMFiles
    case invalidInput(String)
    case cookieAccessDenied

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "\(name) 未找到，请确认已正确安装"
        case .processFailed(let name, let code):
            return "\(name) 执行失败，退出码 \(code)"
        case .noOutputFile:
            return "处理完成但未找到输出文件"
        case .noNCMFiles:
            return "目录下未找到 .ncm 文件"
        case .invalidInput(let msg):
            return "输入无效：\(msg)"
        case .cookieAccessDenied:
            return "无法读取浏览器 Cookie。Safari 受 macOS 保护需在「系统设置 → 隐私与安全性 → 完全磁盘访问」中授权本 App；更推荐改用 Firefox 或 Chrome（在设置→Cookie 中切换）。"
        }
    }
}
