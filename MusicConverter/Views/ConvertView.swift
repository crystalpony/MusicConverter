import SwiftUI
import UniformTypeIdentifiers

/// 统一转换 Tab：本地音频格式转换 + 网易云 NCM 解密（复古包豪斯，随窗口自适应）
struct ConvertView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var ffmpeg = FFmpegService()
    @StateObject private var ncmdump = NcmdumpService()

    @State private var tasks: [ConvertTask] = []
    @State private var logOutput: String = ""
    @State private var batchProgress: String = ""
    @State private var showUpgradeAlert: Bool = false
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 标题
            HStack(spacing: 10) {
                Rectangle().fill(Bauhaus.yellow).frame(width: 14, height: 14)
                Text("转换")
                    .font(BauhausFont.title(24))
                    .foregroundStyle(Bauhaus.ink)
                Spacer()
                Text("音频转 MP3 · 网易云 NCM 解密")
                    .font(BauhausFont.body(12))
                    .foregroundStyle(Bauhaus.inkSecondary)
            }

            // 拖拽区
            dropZone

            if !batchProgress.isEmpty {
                Text(batchProgress)
                    .font(BauhausFont.body(12))
                    .foregroundStyle(Bauhaus.inkSecondary)
            }

            // 主内容区（随窗口自适应）
            if tasks.isEmpty && logOutput.isEmpty {
                emptyState
            } else {
                VStack(spacing: 16) {
                    if !tasks.isEmpty { taskListCard }
                    if !logOutput.isEmpty { logCard }
                    if tasks.isEmpty { Spacer() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Bauhaus.paper)
        .alert("免费版转换次数受限", isPresented: $showUpgradeAlert) {
            Button("升级到 Pro") {
                NotificationCenter.default.post(name: .showProPurchase, object: nil)
            }
            Button("稍后再说", role: .cancel) {}
        } message: {
            Text("免费版每次最多处理 \(settings.effectiveConvertLimit) 个文件，升级 Pro 后可无限制批量转换。")
        }
    }

    // MARK: - 拖拽区（包豪斯硬边框）

    private var dropZone: some View {
        ZStack {
            Rectangle()
                .fill(isTargeted ? Bauhaus.yellow.opacity(0.18) : Bauhaus.surface)
                .bauhausBorder(isTargeted ? Bauhaus.red : Bauhaus.ink, width: 2)

            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Bauhaus.yellow).frame(width: 46, height: 46)
                        .bauhausBorder(width: 2, cornerRadius: 23)
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Bauhaus.ink)
                }
                Text("拖拽音频 / .ncm 文件或文件夹到此处")
                    .font(BauhausFont.heading(14))
                    .foregroundStyle(Bauhaus.ink)
                Text("点击可打开文件选择")
                    .font(BauhausFont.body(11))
                    .foregroundStyle(Bauhaus.inkSecondary)
            }
        }
        .frame(height: 130)
        .contentShape(Rectangle())
        .onTapGesture { openPanel() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleProviders(providers)
            return !providers.isEmpty
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Bauhaus.red)
                    .frame(width: 88, height: 88).offset(x: -24)
                    .bauhausBorder(width: 3, cornerRadius: 44)
                BauhausTriangle().fill(Bauhaus.yellow)
                    .frame(width: 82, height: 76).offset(x: 22, y: 8)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white).offset(x: -24)
            }
            .padding(.bottom, 4)
            Text("拖入文件即可自动识别并处理")
                .font(BauhausFont.heading(16))
                .foregroundStyle(Bauhaus.ink)
            VStack(spacing: 4) {
                Text("音频（mp3/wav/flac/aac/m4a/ogg…）→ 转为 MP3")
                Text("网易云 .ncm → 解密还原（支持整个文件夹批量）")
            }
            .font(BauhausFont.body(12))
            .foregroundStyle(Bauhaus.inkSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 任务列表卡片

    private var taskListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "处理任务", trailing: "\(tasks.count)")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tasks) { task in
                        taskRow(task)
                        Rectangle().fill(Bauhaus.ink.opacity(0.12)).frame(height: 1)
                    }
                }
            }
        }
        .background(Bauhaus.surface)
        .bauhausBorder(width: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func taskRow(_ task: ConvertTask) -> some View {
        HStack(spacing: 12) {
            // 类型标签
            Text(task.kind.rawValue)
                .font(BauhausFont.body(11))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(task.kind == .decrypt ? Bauhaus.red : Bauhaus.blue)
                .bauhausBorder(width: 1.5, cornerRadius: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title.isEmpty ? task.inputPath : task.title)
                    .font(BauhausFont.body(13))
                    .foregroundStyle(Bauhaus.ink)
                    .lineLimit(1)
                if !task.format.isEmpty {
                    Text(task.format.uppercased())
                        .font(BauhausFont.body(11))
                        .foregroundStyle(Bauhaus.inkSecondary)
                }
            }

            Spacer()

            if task.status == .converting || task.status == .decrypting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(task.status.rawValue)
                    .font(BauhausFont.body(12))
                    .foregroundStyle(statusColor(task.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(task.status).opacity(0.14))
                    .bauhausBorder(statusColor(task.status), width: 1.5, cornerRadius: 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - 日志卡片

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "日志", trailing: nil)
            ScrollView {
                Text(logOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Bauhaus.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(maxHeight: 140)
        }
        .background(Bauhaus.surface)
        .bauhausBorder(width: 2)
    }

    /// 黑底反白标题条
    private func sectionHeader(title: String, trailing: String?) -> some View {
        HStack {
            Text(title.uppercased())
                .font(BauhausFont.heading(13))
                .foregroundStyle(Bauhaus.paper)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(BauhausFont.body(12).monospacedDigit())
                    .foregroundStyle(Bauhaus.paper)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Bauhaus.ink)
    }

    // MARK: - 拖拽/选择处理

    /// 异步收集拖入的文件 URL
    private func handleProviders(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    lock.lock(); urls.append(url); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty { routeInputs(urls) }
        }
    }

    /// 点击弹出系统文件选择面板
    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            routeInputs(panel.urls)
        }
    }

    // MARK: - 路由：按类型分发到转换 / 解密

    /// ffmpeg 支持的主流音频格式（小写）
    private static let supportedAudioExtensions: Set<String> = [
        "mp3", "wav", "flac", "aac", "m4a", "ogg", "opus",
        "wma", "aiff", "aif", "ape", "wv", "ac3", "amr",
        "caf", "webm", "mp4", "mka", "mkv",
    ]

    private func routeInputs(_ urls: [URL]) {
        for url in urls {
            let path = url.path
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

            if isDir.boolValue {
                // 目录：批量解密其中的 .ncm
                batchDecryptDirectory(path)
                continue
            }

            let ext = url.pathExtension.lowercased()
            guard !ext.isEmpty else {
                logOutput += "[跳过] 无扩展名: \(url.lastPathComponent)\n"
                continue
            }

            // 免费版批量限制
            if !settings.isPro && tasks.count >= settings.effectiveConvertLimit {
                showUpgradeAlert = true
                logOutput += "[限制] 免费版最多同时处理 \(settings.effectiveConvertLimit) 个文件，升级 Pro 解锁无限制\n"
                return
            }

            if ext == "ncm" {
                decryptSingle(path)
            } else if Self.supportedAudioExtensions.contains(ext) {
                convertAudio(url)
            } else {
                logOutput += "[跳过] 不支持的格式 .\(ext): \(url.lastPathComponent)\n"
            }
        }
    }

    // MARK: - 转换（ffmpeg）

    private func convertAudio(_ url: URL) {
        let path = url.path
        var task = ConvertTask(inputPath: path, title: FileUtil.stem(of: path), kind: .convert)
        task.status = .converting
        tasks.append(task)
        let taskIndex = tasks.count - 1

        Task {
            do {
                let outputPath = try await ffmpeg.convert(
                    inputPath: path,
                    outputDir: settings.resolvedOutputDirectory,
                    bitrate: settings.defaultBitrate,
                    onOutput: { line in logOutput += line + "\n" }
                )
                tasks[taskIndex].status = .completed
                tasks[taskIndex].outputPath = outputPath
                tasks[taskIndex].format = "mp3"
                MusicLibraryStore.shared.addRecord(filePath: outputPath, sourceFileName: url.lastPathComponent)
            } catch {
                tasks[taskIndex].status = .failed
                tasks[taskIndex].errorMessage = error.localizedDescription
                logOutput += "[错误] \(error.localizedDescription)\n"
            }
        }
    }

    // MARK: - 解密（ncmdump）

    private func decryptSingle(_ path: String) {
        var task = ConvertTask(inputPath: path, title: FileUtil.stem(of: path), kind: .decrypt)
        task.status = .decrypting
        tasks.append(task)
        let taskIndex = tasks.count - 1

        Task {
            do {
                let result = try await ncmdump.decrypt(
                    inputPath: path,
                    outputDir: settings.resolvedOutputDirectory,
                    onOutput: { line in logOutput += line + "\n" }
                )
                tasks[taskIndex].status = .completed
                tasks[taskIndex].outputPath = result.path
                tasks[taskIndex].format = result.format
                MusicLibraryStore.shared.addRecord(filePath: result.path, sourceFileName: (path as NSString).lastPathComponent)
            } catch {
                tasks[taskIndex].status = .failed
                tasks[taskIndex].errorMessage = error.localizedDescription
                logOutput += "[错误] \(error.localizedDescription)\n"
            }
        }
    }

    private func batchDecryptDirectory(_ dirPath: String) {
        batchProgress = "扫描中..."

        Task {
            do {
                let results = try await ncmdump.batchDecrypt(
                    inputDir: dirPath,
                    outputDir: settings.resolvedOutputDirectory,
                    onProgress: { current, total in
                        batchProgress = "解密中 \(current)/\(total)"
                    },
                    onOutput: { line in logOutput += line + "\n" }
                )
                for result in results {
                    var task = ConvertTask(
                        inputPath: result.path,
                        title: FileUtil.stem(of: result.path),
                        kind: .decrypt
                    )
                    task.status = .completed
                    task.outputPath = result.path
                    task.format = result.format
                    tasks.append(task)
                    MusicLibraryStore.shared.addRecord(filePath: result.path, sourceFileName: (result.path as NSString).lastPathComponent)
                }
                batchProgress = "全部完成，共 \(results.count) 个文件"
            } catch {
                logOutput += "[错误] \(error.localizedDescription)\n"
                batchProgress = "失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: ConvertTask.TaskStatus) -> Color {
        switch status {
        case .pending: return Bauhaus.inkSecondary
        case .converting, .decrypting: return Bauhaus.blue
        case .completed: return Bauhaus.blue
        case .failed: return Bauhaus.red
        }
    }
}
