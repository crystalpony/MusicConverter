import SwiftUI
import UniformTypeIdentifiers

/// NCM 解密 Tab
struct NCMView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var service = NcmdumpService()

    @State private var tasks: [NCMTask] = []
    @State private var isDecrypting: Bool = false
    @State private var logOutput: String = ""
    @State private var batchProgress: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // 拖拽区域（支持 .ncm 文件或目录）
            FileDropZone(
                prompt: "拖拽 .ncm 文件或目录到此处，或点击选择",
                acceptedTypes: [],
                allowsDirectories: true,
                onDrop: { urls in
                    handleDrop(urls)
                }
            )

            // 批量进度
            if !batchProgress.isEmpty {
                Text(batchProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 任务列表
            if !tasks.isEmpty {
                GroupBox("解密任务") {
                    List {
                        ForEach($tasks) { $task in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(task.title.isEmpty ? task.inputPath : task.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    if !task.format.isEmpty {
                                        Text(task.format.uppercased())
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }

                                Spacer()

                                if task.status == .decrypting {
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
    }

    private func handleDrop(_ urls: [URL]) {
        for url in urls {
            let path = url.path
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

            if isDir.boolValue {
                decryptDirectory(path)
            } else if path.hasSuffix(".ncm") {
                decryptSingle(path)
            }
        }
    }

    private func decryptSingle(_ path: String) {
        var task = NCMTask(inputPath: path, title: FileUtil.stem(of: path))
        task.status = .decrypting
        tasks.append(task)
        let taskIndex = tasks.count - 1
        isDecrypting = true

        Task {
            do {
                let result = try await service.decrypt(
                    inputPath: path,
                    outputDir: settings.resolvedOutputDirectory,
                    onOutput: { line in logOutput += line + "\n" }
                )
                tasks[taskIndex].status = .completed
                tasks[taskIndex].outputPath = result.path
                tasks[taskIndex].format = result.format
            } catch {
                tasks[taskIndex].status = .failed
                tasks[taskIndex].errorMessage = error.localizedDescription
                logOutput += "[错误] \(error.localizedDescription)\n"
            }
            isDecrypting = false
        }
    }

    private func decryptDirectory(_ dirPath: String) {
        isDecrypting = true
        logOutput = ""
        batchProgress = "扫描中..."

        Task {
            do {
                let results = try await service.batchDecrypt(
                    inputDir: dirPath,
                    outputDir: settings.resolvedOutputDirectory,
                    onProgress: { current, total in
                        batchProgress = "\(current)/\(total)"
                    },
                    onOutput: { line in logOutput += line + "\n" }
                )
                for result in results {
                    tasks.append(NCMTask(
                        inputPath: result.path,
                        title: FileUtil.stem(of: result.path),
                        status: .completed,
                        outputPath: result.path,
                        format: result.format
                    ))
                }
                batchProgress = "全部完成，共 \(results.count) 个文件"
            } catch {
                logOutput += "[错误] \(error.localizedDescription)\n"
                batchProgress = "失败: \(error.localizedDescription)"
            }
            isDecrypting = false
        }
    }

    private func statusColor(_ status: NCMTask.TaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .decrypting: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
