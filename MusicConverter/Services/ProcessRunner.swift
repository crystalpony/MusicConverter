import Foundation

/// 通用异步 Process 执行器
/// 通过 Pipe 实时读取 stdout/stderr，支持进度解析
class ProcessRunner {
    private var process: Process?

    /// 执行命令并通过 AsyncStream 实时返回输出行
    func run(launchPath: String, arguments: [String], cwd: String? = nil) -> AsyncStream<String> {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = arguments

        if let cwd = cwd {
            proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        // 设置环境变量，确保内嵌工具可被找到
        var env = ProcessInfo.processInfo.environment
        let bundleResources = Bundle.main.resourcePath ?? ""
        env["PATH"] = "\(bundleResources):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        proc.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        // 实时读取 stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !line.isEmpty {
                continuation.yield(line)
            }
        }

        // 实时读取 stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !line.isEmpty {
                continuation.yield("[stderr] \(line)")
            }
        }

        proc.terminationHandler = { _ in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            continuation.finish()
        }

        do {
            try proc.run()
            self.process = proc
        } catch {
            continuation.yield("[error] \(error.localizedDescription)")
            continuation.finish()
        }

        return stream
    }

    /// 等待进程结束并返回退出码
    func waitUntilExit() async -> Int32 {
        guard let proc = process else { return -1 }
        proc.waitUntilExit()
        return proc.terminationStatus
    }

    /// 终止进程
    func terminate() {
        process?.terminate()
    }
}
