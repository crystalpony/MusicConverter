import Foundation

/// ffmpeg 本地转换服务
@MainActor
class FFmpegService: ObservableObject {
    private let runner = ProcessRunner()
    private let toolManager = ToolManager.shared

    /// 将本地音频文件转为 MP3
    func convert(
        inputPath: String,
        outputDir: String,
        bitrate: String = "320k",
        onOutput: @escaping (String) -> Void = { _ in }
    ) async throws -> String {
        try FileUtil.ensureDirectory(outputDir)

        // 前置格式校验：拦截网易云 .ncm 等加密格式
        let ext = (inputPath as NSString).pathExtension.lowercased()
        if ext == "ncm" {
            throw ServiceError.invalidInput(
                "\(inputPath) 是网易云加密格式（.ncm），请先用 ncmdump 解密，或在「NCM 解密」Tab 中处理。"
            )
        }

        let ffmpeg = toolManager.toolPath("ffmpeg")
        let title = FileUtil.stem(of: inputPath)
        let outputPath = "\(outputDir)/\(title).mp3"

        let args: [String] = [
            "-i", inputPath,
            "-vn", "-acodec", "libmp3lame",
            "-ab", bitrate, "-y",
            outputPath,
        ]

        let stream = runner.run(launchPath: ffmpeg, arguments: args)
        for await line in stream {
            onOutput(line)
        }

        let exitCode = await runner.waitUntilExit()
        guard exitCode == 0, FileManager.default.fileExists(atPath: outputPath) else {
            throw ServiceError.processFailed("ffmpeg", exitCode)
        }

        return outputPath
    }
}
