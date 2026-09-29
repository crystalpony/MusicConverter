import Foundation

/// 在本机准备分离引擎并生成伴奏；原曲不会被覆盖。
@MainActor
final class AudioSeparatorService {
    private let runner = ProcessRunner()
    private let fileManager = FileManager.default

    private var rootDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MusicConverter/AudioSeparator", isDirectory: true)
    }

    private var environment: [String: String] {
        [
            "UV_PYTHON_INSTALL_DIR": rootDirectory.appendingPathComponent("python").path,
            "UV_CACHE_DIR": fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MusicConverter/uv", isDirectory: true).path,
            "UV_NO_PROJECT": "1",
        ]
    }

    private var executable: URL {
        rootDirectory.appendingPathComponent("venv/bin/audio-separator")
    }

    private var installationMarker: URL {
        rootDirectory.appendingPathComponent("installed-version")
    }

    /// 首次使用自动下载 Python 和分离引擎，后续复用本地环境。
    func prepare(onOutput: @escaping (String) -> Void) async throws {
        guard #available(macOS 14.0, *) else {
            throw ServiceError.invalidInput("伴奏功能需要 macOS 14 或更新版本")
        }
#if arch(arm64)
        if fileManager.isExecutableFile(atPath: executable.path),
           (try? String(contentsOf: installationMarker, encoding: .utf8)) == "0.47.0-cpu" {
            return
        }
        guard let uvPath = Bundle.main.path(forResource: "uv", ofType: nil),
              fileManager.isExecutableFile(atPath: uvPath) else {
            throw ServiceError.toolNotFound("伴奏组件安装器 uv")
        }

        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let venv = rootDirectory.appendingPathComponent("venv", isDirectory: true)
        onOutput("[伴奏] 首次使用，正在准备本机分离组件（约 1 GB，需联网）…")
        try await run(
            uvPath,
            ["venv", "--python", "3.12", "--managed-python", "--no-project", "--clear", venv.path],
            environment: environment,
            onOutput: onOutput
        )
        try await run(
            uvPath,
            ["pip", "install", "--python", venv.appendingPathComponent("bin/python").path,
             "audio-separator[cpu]==0.47.0", "audioread==3.1.0"],
            environment: environment,
            onOutput: onOutput
        )
        guard fileManager.isExecutableFile(atPath: executable.path) else {
            throw ServiceError.toolNotFound("audio-separator")
        }
        try await run(
            executable.path,
            ["--env_info"],
            onOutput: onOutput
        )
        try "0.47.0-cpu".write(to: installationMarker, atomically: true, encoding: .utf8)
        onOutput("[伴奏] 分离组件已准备好")
#else
        throw ServiceError.invalidInput("伴奏功能当前需要 Apple 芯片 Mac")
#endif
    }

    func makeInstrumental(
        from inputPath: String,
        outputDirectory: String,
        onOutput: @escaping (String) -> Void
    ) async throws -> String {
        guard fileManager.isExecutableFile(atPath: executable.path) else {
            throw ServiceError.toolNotFound("audio-separator")
        }
        try FileUtil.ensureDirectory(outputDirectory)
        let workDirectory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
            .appendingPathComponent(".tunely-stems-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDirectory) }

        let modelDirectory = rootDirectory.appendingPathComponent("models", isDirectory: true)
        try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        onOutput("[伴奏] 正在分离人声；首次运行需下载约 56 MB 模型…")
        try await run(
            executable.path,
            [inputPath, "--model_filename", "UVR-MDX-NET-Inst_HQ_4.onnx",
             "--model_file_dir", modelDirectory.path,
             "--output_dir", workDirectory.path,
             "--single_stem", "Instrumental",
             "--output_format", "MP3", "--output_bitrate", "320k",
             "--custom_output_names", "{\"Instrumental\":\"instrumental\"}"],
            onOutput: onOutput
        )

        let generated = workDirectory.appendingPathComponent("instrumental.mp3")
        guard fileManager.fileExists(atPath: generated.path) else {
            throw ServiceError.noOutputFile
        }

        let baseName = ((inputPath as NSString).lastPathComponent as NSString).deletingPathExtension
        var destination = "\(outputDirectory)/\(baseName) 伴奏.mp3"
        var index = 1
        while fileManager.fileExists(atPath: destination) {
            destination = "\(outputDirectory)/\(baseName) 伴奏 (\(index)).mp3"
            index += 1
        }
        try fileManager.moveItem(atPath: generated.path, toPath: destination)
        return destination
    }

    private func run(
        _ path: String,
        _ arguments: [String],
        environment: [String: String] = [:],
        onOutput: @escaping (String) -> Void
    ) async throws {
        let stream = runner.run(launchPath: path, arguments: arguments, environment: environment)
        for await line in stream { onOutput(line) }
        let exitCode = await runner.waitUntilExit()
        guard exitCode == 0 else {
            throw ServiceError.processFailed((path as NSString).lastPathComponent, exitCode)
        }
    }
}
