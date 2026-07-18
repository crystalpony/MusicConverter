import Foundation

/// 下载格式选项
enum DownloadFormat: String, CaseIterable {
    case audioMP3       = "仅音频 (MP3)"
    case originalVideo  = "原画视频（保留原格式）"
    case bestVideo      = "最佳画质视频 (MP4)"

    /// yt-dlp 参数片段
    func ytDlpArgs(bitrate: String) -> [String] {
        switch self {
        case .audioMP3:
            return [
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", bitrate,
                "--embed-thumbnail",
                "--add-metadata",
            ]
        case .originalVideo:
            // 保持源格式，嵌入字幕和缩略图
            return [
                "--write-subs", "--write-auto-subs", "--sub-langs", "all",
                "--embed-thumbnail", "--embed-metadata",
            ]
        case .bestVideo:
            // 最佳画质 + 最佳音质，合并为 mp4
            return [
                "-f", "bv*+ba/b",
                "--merge-output-format", "mp4",
                "--embed-thumbnail", "--embed-metadata",
                "--write-subs", "--write-auto-subs", "--sub-langs", "all",
            ]
        }
    }

    /// 输出扩展名（用于查找）
    var expectedExtensions: [String] {
        switch self {
        case .audioMP3:      return ["mp3"]
        case .originalVideo: return ["mp4", "mkv", "webm", "mov", "flv", "m4a"]
        case .bestVideo:     return ["mp4", "mkv", "webm"]
        }
    }
}

/// yt-dlp 下载服务
@MainActor
class YtDlpService: ObservableObject {
    private let runner = ProcessRunner()
    private let toolManager = ToolManager.shared

    /// 下载 URL 并按指定格式保存
    func download(
        url rawURL: String,
        outputDir: String,
        format: DownloadFormat = .audioMP3,
        bitrate: String = "320k",
        cookieFile: String? = nil,
        proxy: String? = nil,
        onProgress: @escaping (Double) -> Void = { _ in },
        onOutput: @escaping (String) -> Void = { _ in }
    ) async throws -> (path: String, title: String) {
        try FileUtil.ensureDirectory(outputDir)

        // URL 清洗
        guard let url = PlatformDetector.extractURL(from: rawURL), !url.isEmpty else {
            throw ServiceError.invalidInput("未检测到有效 URL：\(rawURL)")
        }

        let ytdlp = toolManager.toolPath("yt-dlp")
        let platform = PlatformDetector.detect(url: url)

        // 前置拦截不支持的平台
        if let unsupported = PlatformDetector.unsupportedPlatform(url: url) {
            throw ServiceError.invalidInput("不支持 \(unsupported)：该平台有 DRM 保护，yt-dlp 无法下载")
        }

        var args: [String] = format.ytDlpArgs(bitrate: bitrate)

        // 保留原始标题（含中文），不强制 ASCII 化；重名时自动加序号
        args += [
            "-o", "\(outputDir)/%(title)s.%(ext)s",
            "--no-overwrites",
            "--no-warnings",
            "--newline",
            "--no-colors",
        ]

        // Bilibili 特殊处理
        if platform == "Bilibili" {
            args += ["--referer", "https://www.bilibili.com"]
        }

        if let cookieFile = cookieFile, !cookieFile.isEmpty {
            args += ["--cookies", cookieFile]
        }
        if let proxy = proxy, !proxy.isEmpty {
            args += ["--proxy", proxy]
        }

        args.append(url)

        // 运行 yt-dlp，实时捕获 stdout 解析进度和最终路径
        var lastMergedPath: String?
        let stream = runner.run(launchPath: ytdlp, arguments: args)

        for await line in stream {
            onOutput(line)

            // 进度: [download]  45.2% of ...
            if let range = line.range(of: #"\[download\]\s+([\d.]+)%"#, options: .regularExpression) {
                let match = String(line[range])
                if let pctRange = match.range(of: #"[\d.]+"#, options: .regularExpression) {
                    let pctStr = match[pctRange]
                    if let pct = Double(pctStr) {
                        onProgress(pct / 100.0)
                    }
                }
            }

            // 合并完成: [Merger] Merging formats into "/path/to/file.mp4"
            if line.contains("[Merger]") || line.contains("Merging formats into") {
                if let path = extractQuotedPath(from: line) {
                    lastMergedPath = path
                }
            }

            // 已完成: [download] Destination: /path/to/file.mp3
            if line.contains("[download] Destination:") {
                if let path = line.components(separatedBy: "[download] Destination:").last?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    lastMergedPath = path
                }
            }

            // 已存在跳过: [download] /path already exists
            if line.contains("already exists") {
                if let path = extractQuotedPath(from: line) ?? extractTrailingPath(from: line) {
                    lastMergedPath = path
                }
            }
        }

        let exitCode = await runner.waitUntilExit()
        guard exitCode == 0 else {
            throw ServiceError.processFailed("yt-dlp", exitCode)
        }

        // 优先使用 yt-dlp 输出中明确的路径
        if let p = lastMergedPath, FileManager.default.fileExists(atPath: p) {
            return (p, FileUtil.stem(of: p))
        }

        // 回退：在 outputDir 中按格式期望扩展名查找最新文件
        let fm = FileManager.default
        let allowed = Set(format.expectedExtensions)
        let files = (try? fm.contentsOfDirectory(atPath: outputDir)) ?? []
        let candidates = files
            .filter { allowed.contains(FileUtil.ext(of: $0).lowercased()) }
            .map { "\(outputDir)/\($0)" }
        guard let latest = candidates.max(by: {
            (try? fm.attributesOfItem(atPath: $0)[.modificationDate] as? Date ?? .distantPast) ?? .distantPast
            < (try? fm.attributesOfItem(atPath: $1)[.modificationDate] as? Date ?? .distantPast) ?? .distantPast
        }) else {
            throw ServiceError.noOutputFile
        }
        return (latest, FileUtil.stem(of: latest))
    }

    // MARK: - Helpers

    private func extractQuotedPath(from line: String) -> String? {
        // "xxx" 或 'xxx'
        if let r = line.range(of: #""[^"]+\.(mp4|mkv|webm|mp3|flac|m4a|ogg|mov)""#, options: .regularExpression) {
            var s = String(line[r]); s.removeFirst(); s.removeLast(); return s
        }
        if let r = line.range(of: #"'[^']+\.(mp4|mkv|webm|mp3|flac|m4a|ogg|mov)'"#, options: .regularExpression) {
            var s = String(line[r]); s.removeFirst(); s.removeLast(); return s
        }
        return nil
    }

    private func extractTrailingPath(from line: String) -> String? {
        // 最后一个 /xxx 开头的 token
        let parts = line.components(separatedBy: .whitespaces)
        for p in parts.reversed() {
            if p.hasPrefix("/") { return p }
        }
        return nil
    }
}
