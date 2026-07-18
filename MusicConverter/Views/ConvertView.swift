import SwiftUI
import UniformTypeIdentifiers

/// 转换 Tab：本地音频文件转 MP3
struct ConvertView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var service = FFmpegService()

    @State private var tasks: [ConvertTask] = []
    @State private var isConverting: Bool = false
    @State private var logOutput: String = ""
    @State private var showUpgradeAlert: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // 拖拽区域 + 文件选择
            FileDropZone(
                acceptedTypes: [UTType.audio],
                onDrop: { urls in
                    addFiles(urls)
                }
            )

            // 任务列表
            if !tasks.isEmpty {
                GroupBox("转换任务") {
                    List {
                        ForEach($tasks) { $task in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title.isEmpty ? task.inputPath : task.title)
                                        .font(.body)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if task.status == .converting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text(task.status.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(statusColor(task.status))
                                }
                            }
                        }
                    }
                    .frame(minHeight: 150)
                }
            }

            // 日志区
            if !logOutput.isEmpty {
                GroupBox("日志") {
                    ScrollView {
                        Text(logOutput)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 120)
                }
            }

            Spacer()
        }
        .alert("免费版转换次数受限", isPresented: $showUpgradeAlert) {
            Button("升级到 Pro") {
                NotificationCenter.default.post(name: .showProPurchase, object: nil)
            }
            Button("稍后再说", role: .cancel) {}
        } message: {
            Text("免费版每次最多转换 \(settings.effectiveConvertLimit) 个文件，升级 Pro 后可无限制批量转换。")
        }
    }

    /// ffmpeg 支持的主流音频格式（小写）
    private static let supportedAudioExtensions: Set<String> = [
        "mp3", "wav", "flac", "aac", "m4a", "ogg", "opus",
        "wma", "aiff", "aif", "ape", "wv", "ac3", "amr",
        "caf", "webm", "mp4", "mka", "mkv",
    ]

    private func addFiles(_ urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard !ext.isEmpty else {
                logOutput += "[跳过] 无扩展名: \(url.lastPathComponent)\n"
                continue
            }
            guard Self.supportedAudioExtensions.contains(ext) else {
                if ext == "ncm" {
                    logOutput += "[提示] \(url.lastPathComponent) 是网易云加密格式，请切到「NCM 解密」Tab 处理\n"
                } else {
                    logOutput += "[跳过] 不支持的格式 .\(ext): \(url.lastPathComponent)\n"
                }
                continue
            }

            // 免费版批量限制检查
            if !settings.isPro && tasks.count >= settings.effectiveConvertLimit {
                showUpgradeAlert = true
                logOutput += "[限制] 免费版最多同时转换 \(settings.effectiveConvertLimit) 个文件，升级 Pro 解锁无限制\n"
                return
            }

            let path = url.path
            var task = ConvertTask(inputPath: path, title: FileUtil.stem(of: path))
            task.status = .converting
            tasks.append(task)
            let taskIndex = tasks.count - 1
            isConverting = true

            Task {
                do {
                    let outputPath = try await service.convert(
                        inputPath: path,
                        outputDir: settings.resolvedOutputDirectory,
                        bitrate: settings.defaultBitrate,
                        onOutput: { line in
                            logOutput += line + "\n"
                        }
                    )
                    tasks[taskIndex].status = .completed
                    tasks[taskIndex].outputPath = outputPath
                    // 记录到音乐库
                    MusicLibraryStore.shared.addRecord(filePath: outputPath, sourceFileName: url.lastPathComponent)
                } catch {
                    tasks[taskIndex].status = .failed
                    tasks[taskIndex].errorMessage = error.localizedDescription
                    logOutput += "[错误] \(error.localizedDescription)\n"
                }
                isConverting = false
            }
        }
    }

    private func statusColor(_ status: ConvertTask.TaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .converting: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
