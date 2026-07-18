import Foundation

/// 管理内嵌 CLI 工具的路径解析
class ToolManager {
    static let shared = ToolManager()

    /// 获取指定工具的可执行文件路径
    /// 优先使用 .app bundle 内嵌的二进制，回退到系统 PATH
    func toolPath(_ name: String) -> String {
        // 优先使用 bundle 内嵌的二进制
        if let path = Bundle.main.path(forResource: name, ofType: nil) {
            return path
        }
        // 回退到系统 PATH
        return name
    }

    /// 检查工具是否可用
    func isAvailable(_ name: String) -> Bool {
        let path = toolPath(name)
        return FileManager.default.isExecutableFile(atPath: path)
    }

    /// 获取所有工具的状态
    func status() -> [String: Bool] {
        return [
            "yt-dlp": isAvailable("yt-dlp"),
            "ffmpeg": isAvailable("ffmpeg"),
            "ncmdump": isAvailable("ncmdump"),
        ]
    }
}
