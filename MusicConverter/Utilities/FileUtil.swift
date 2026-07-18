import Foundation

/// 文件操作辅助工具
enum FileUtil {
    /// 格式化文件大小
    static func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// 确保目录存在
    static func ensureDirectory(_ path: String) throws {
        let fm = FileManager.default
        let expanded = (path as NSString).expandingTildeInPath
        if !fm.fileExists(atPath: expanded) {
            try fm.createDirectory(atPath: expanded, withIntermediateDirectories: true)
        }
    }

    /// 获取文件名（不含扩展名）
    static func stem(of path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }

    /// 获取文件扩展名
    static func ext(of path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.pathExtension
    }
}
