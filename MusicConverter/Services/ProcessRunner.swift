import Foundation
import Darwin

/// 通用异步 Process 执行器
/// 通过 Pipe 实时读取 stdout/stderr，支持进度解析
class ProcessRunner {
    private var process: Process?

    /// 执行命令并通过 AsyncStream 实时返回完整输出行
    func run(
        launchPath: String,
        arguments: [String],
        cwd: String? = nil,
        environment: [String: String] = [:]
    ) -> AsyncStream<String> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: String.self,
            bufferingPolicy: .bufferingNewest(1024)
        )

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
        env.merge(environment) { _, override in override }
        proc.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        do {
            try proc.run()
            self.process = proc
            // 父进程关闭写端，读线程在子进程退出后才能收到 EOF。
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()

            let readers = DispatchGroup()
            for (pipe, prefix) in [(stdoutPipe, ""), (stderrPipe, "[stderr] ")] {
                readers.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    Self.readLines(from: pipe.fileHandleForReading, prefix: prefix, into: continuation)
                    readers.leave()
                }
            }
            readers.notify(queue: .global(qos: .userInitiated)) {
                continuation.finish()
            }
        } catch {
            continuation.yield("[error] \(error.localizedDescription)")
            continuation.finish()
        }

        return stream
    }

    /// 等待进程结束并返回退出码
    func waitUntilExit() async -> Int32 {
        guard let proc = process else { return -1 }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                proc.waitUntilExit()
                continuation.resume(returning: proc.terminationStatus)
            }
        }
    }

    /// 终止进程
    func terminate() {
        process?.terminate()
    }

    private static func readLines(
        from handle: FileHandle,
        prefix: String,
        into continuation: AsyncStream<String>.Continuation
    ) {
        var pending = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            // POSIX read 会在有字节可读时返回；FileHandle.readData(ofLength:)
            // 可能攒满缓冲区，导致短进度行直到下载结束才出现在界面。
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count)
            }
            if count < 0 && errno == EINTR { continue }
            if count <= 0 { break }
            pending.append(contentsOf: buffer.prefix(count))
            while let end = pending.firstIndex(where: { $0 == 10 || $0 == 13 }) {
                let line = String(decoding: pending[..<end], as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty { continuation.yield(prefix + line) }
                pending.removeSubrange(...end)
            }
        }
        if !pending.isEmpty {
            let line = String(decoding: pending, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { continuation.yield(prefix + line) }
        }
        handle.closeFile()
    }
}
