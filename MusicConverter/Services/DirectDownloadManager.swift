import Foundation

/// 链接下载的会话状态。页面和窗口可重建，正在运行的任务仍由此对象持有。
@MainActor
final class DirectDownloadManager: ObservableObject {
    static let shared = DirectDownloadManager()

    @Published private(set) var tasks: [DownloadTask] = []
    @Published private(set) var isDownloading = false
    @Published private(set) var logOutput = ""

    private let service = YtDlpService()
    private let separator = AudioSeparatorService()

    private init() {}

    func start(
        url: String,
        platform: String,
        format: DownloadFormat,
        createInstrumental: Bool = false,
        settings: AppSettings
    ) {
        guard !isDownloading else { return }

        // 会话历史只保留最近 199 条，避免长时间运行后每次进度刷新都复制大数组。
        if tasks.count >= 200 {
            tasks.removeFirst(tasks.count - 199)
        }

        var downloadTask = DownloadTask(
            url: url,
            title: "",
            platform: platform,
            bitrate: settings.defaultBitrate,
            format: createInstrumental ? "MP3 + 伴奏" : format.rawValue
        )
        downloadTask.status = createInstrumental ? .converting : .downloading
        tasks.append(downloadTask)
        let taskID = downloadTask.id
        isDownloading = true
        logOutput = ""

        Task {
            do {
                if createInstrumental {
                    try await separator.prepare { [weak self] line in self?.appendLog(line) }
                    update(taskID) { $0.status = .downloading }
                }
                let result: (path: String, title: String)
                result = try await service.download(
                    url: url,
                    outputDir: settings.resolvedOutputDirectory,
                    format: format,
                    bitrate: settings.defaultBitrate,
                    cookieFile: settings.effectiveCookieFilePath,
                    cookiesFromBrowser: settings.effectiveCookieBrowser,
                    proxy: settings.useProxy ? settings.proxyAddress : nil,
                    onProgress: { [weak self] progress in
                        self?.update(taskID) { $0.progress = progress }
                    },
                    onProcessing: { [weak self] in
                        self?.update(taskID) { $0.status = .converting }
                    },
                    onOutput: { [weak self] line in self?.appendLog(line) }
                )
                update(taskID) {
                    $0.title = result.title
                    $0.outputPath = result.path
                }
                MusicLibraryStore.shared.addRecord(filePath: result.path, sourceFileName: result.title)
                settings.totalDownloadCount += 1
                settings.totalSavedMinutes += 2

                if createInstrumental {
                    update(taskID) { $0.status = .converting }
                    let path = try await separator.makeInstrumental(
                        from: result.path,
                        outputDirectory: settings.resolvedOutputDirectory,
                        onOutput: { [weak self] line in self?.appendLog(line) }
                    )
                    update(taskID) { $0.outputPath = path }
                    MusicLibraryStore.shared.addRecord(filePath: path, sourceFileName: result.title)
                    appendLog("[伴奏] 已保存：\(path)")
                }
                update(taskID) {
                    $0.status = .completed
                    $0.progress = 1
                }
            } catch {
                update(taskID) {
                    $0.status = .failed
                    $0.errorMessage = error.localizedDescription
                }
                appendLog("[错误] \(error.localizedDescription)")
            }
            isDownloading = false
        }
    }

    func appendLog(_ line: String) {
        // 进度已有独立 UI；高频百分比输出不再触发整块日志重排。
        if line.hasPrefix("[download]") && line.contains("%") { return }
        if line.contains("%|") { return }
        logOutput += line + "\n"
        if logOutput.count > 20_000 {
            logOutput = String(logOutput.suffix(10_000))
        }
    }

    private func update(_ id: UUID, _ change: (inout DownloadTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[index])
    }
}
