import Foundation

/// ncmdump NCM 解密服务
@MainActor
class NcmdumpService: ObservableObject {
    private let runner = ProcessRunner()
    private let toolManager = ToolManager.shared

    /// 解密单个 .ncm 文件
    func decrypt(
        inputPath: String,
        outputDir: String,
        onOutput: @escaping (String) -> Void = { _ in }
    ) async throws -> (path: String, format: String) {
        try FileUtil.ensureDirectory(outputDir)

        let ncmdump = toolManager.toolPath("ncmdump")
        // 用 -o 显式指定输出目录（ncmdump 默认输出到输入文件同目录）
        let args: [String] = ["-o", outputDir, inputPath]

        var stdoutCaptured = ""
        let stream = runner.run(launchPath: ncmdump, arguments: args)
        for await line in stream {
            onOutput(line)
            stdoutCaptured += line + "\n"
        }

        let exitCode = await runner.waitUntilExit()
        guard exitCode == 0 else {
            throw ServiceError.processFailed("ncmdump", exitCode)
        }

        // 优先从 [Done] ... -> 'OUTPUT_PATH' 解析实际输出路径
        if let outPath = parseDonePath(from: stdoutCaptured),
           FileManager.default.fileExists(atPath: outPath) {
            return (outPath, FileUtil.ext(of: outPath))
        }

        // 回退 1：在 outputDir 查找
        if let hit = findOutput(in: outputDir, stem: FileUtil.stem(of: inputPath)) {
            return hit
        }

        // 回退 2：在输入文件同目录查找（ncmdump 默认行为）
        let inputDir = (inputPath as NSString).deletingLastPathComponent
        if let hit = findOutput(in: inputDir, stem: FileUtil.stem(of: inputPath)) {
            return hit
        }

        throw ServiceError.noOutputFile
    }

    /// 批量解密目录下所有 .ncm 文件
    func batchDecrypt(
        inputDir: String,
        outputDir: String,
        onProgress: @escaping (Int, Int) -> Void = { _, _ in },
        onOutput: @escaping (String) -> Void = { _ in }
    ) async throws -> [(path: String, format: String)] {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(atPath: inputDir)
            .filter { $0.hasSuffix(".ncm") }
            .sorted()
            .map { "\(inputDir)/\($0)" }

        guard !files.isEmpty else {
            throw ServiceError.noNCMFiles
        }

        var results: [(path: String, format: String)] = []
        for (index, file) in files.enumerated() {
            onProgress(index + 1, files.count)
            let result = try await decrypt(inputPath: file, outputDir: outputDir, onOutput: onOutput)
            results.append(result)
        }

        return results
    }

    // MARK: - Helpers

    /// 从 ncmdump 输出中解析 [Done] 'input' -> 'output' 路径
    /// 支持带 ANSI 颜色码（如 \u{001B}[1m\u{001B}[32m[Done]\u{001B}[0m）
    private func parseDonePath(from output: String) -> String? {
        // 去掉 ANSI 转义序列
        let cleaned = output.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[a-zA-Z]",
            with: "",
            options: .regularExpression
        )
        // 逐行查找 [Done] ... -> 'path'
        for line in cleaned.components(separatedBy: .newlines).reversed() {
            guard line.contains("[Done]") && line.contains("->") else { continue }
            guard let arrowRange = line.range(of: "->") else { continue }
            let after = String(line[arrowRange.upperBound...])
            // 提取两个单引号之间的内容
            if let m = after.range(of: "'[^']+'", options: .regularExpression) {
                var s = String(after[m])
                s.removeFirst(); s.removeLast() // 去掉首尾引号
                if !s.isEmpty { return s }
            }
        }
        return nil
    }

    /// 在指定目录下按 stem 查找最新生成的音频文件
    private func findOutput(in dir: String, stem: String) -> (path: String, format: String)? {
        let fm = FileManager.default
        let allowed = Set(["mp3", "flac", "ogg", "m4a", "wav"])
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
        let matches = files
            .filter { FileUtil.stem(of: $0) == stem && allowed.contains(FileUtil.ext(of: $0).lowercased()) }
            .map { "\(dir)/\($0)" }
        guard let latest = matches.max(by: {
            (try? fm.attributesOfItem(atPath: $0)[.modificationDate] as? Date ?? .distantPast) ?? .distantPast
            < (try? fm.attributesOfItem(atPath: $1)[.modificationDate] as? Date ?? .distantPast) ?? .distantPast
        }) else { return nil }
        return (latest, FileUtil.ext(of: latest))
    }
}
