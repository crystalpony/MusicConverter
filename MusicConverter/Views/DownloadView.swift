import SwiftUI

/// 下载 Tab：URL 输入 + 下载列表 + 进度
struct DownloadView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var service = YtDlpService()

    @State private var urlInput: String = ""
    @State private var tasks: [DownloadTask] = []
    @State private var isDownloading: Bool = false
    @State private var logOutput: String = ""

    /// 格式选择对话框
    @State private var pendingURL: String?
    @State private var pendingPlatform: String = ""
    @State private var showFormatSheet: Bool = false
    @State private var selectedFormat: DownloadFormat = .audioMP3

    var body: some View {
        VStack(spacing: 16) {
            // URL 输入区
            HStack {
                TextField("粘贴音视频链接（YouTube / Bilibili / 网易云等）", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { promptFormat() }

                Button("下载") { promptFormat() }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlInput.isEmpty || isDownloading)
            }

            // 任务列表
            if !tasks.isEmpty {
                GroupBox("下载任务") {
                    List {
                        ForEach($tasks) { $task in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title.isEmpty ? task.url : task.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        if !task.platform.isEmpty {
                                            Text(task.platform)
                                        }
                                        Text(task.format)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if task.status == .downloading {
                                    ProgressView(value: task.progress)
                                        .progressViewStyle(.linear)
                                        .frame(width: 120)
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
        .confirmationDialog("选择下载格式", isPresented: $showFormatSheet, titleVisibility: .visible) {
            ForEach(DownloadFormat.allCases, id: \.self) { fmt in
                Button(fmt.rawValue) {
                    selectedFormat = fmt
                    startDownload()
                }
            }
            Button("取消", role: .cancel) {
                pendingURL = nil
            }
        } message: {
            if !pendingPlatform.isEmpty {
                Text("平台：\(pendingPlatform)")
            }
        }
    }

    /// 弹出格式选择（不再直接下载）
    private func promptFormat() {
        let rawInput = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty else { return }
        guard let cleanedURL = PlatformDetector.extractURL(from: rawInput) else {
            logOutput += "[错误] 未检测到有效 URL：\(rawInput)\n"
            return
        }
        // 前置拦截不支持的平台
        if let unsupported = PlatformDetector.unsupportedPlatform(url: cleanedURL) {
            logOutput += "[错误] 不支持 \(unsupported)：该平台有 DRM 保护，yt-dlp 无法下载\n"
            return
        }
        // 条件支持平台检测（需要 Cookie）
        let hasCookie = settings.effectiveCookieFilePath != nil
        if let conditional = PlatformDetector.conditionalPlatform(url: cleanedURL, hasCookie: hasCookie) {
            logOutput += "[提示] \(conditional) 需要先登录账号（在「歌单」Tab 扫码登录）或配置 Cookie 文件后才能下载\n"
            return
        }
        pendingURL = cleanedURL
        pendingPlatform = PlatformDetector.detect(url: cleanedURL)
        showFormatSheet = true
    }

    /// 用户选定格式后开始下载
    private func startDownload() {
        guard let cleanedURL = pendingURL else { return }
        let fmt = selectedFormat

        var task = DownloadTask(
            url: cleanedURL,
            platform: pendingPlatform,
            bitrate: settings.defaultBitrate,
            format: fmt.rawValue
        )
        task.status = .downloading
        tasks.append(task)
        let taskIndex = tasks.count - 1
        urlInput = ""
        pendingURL = nil
        isDownloading = true
        logOutput = ""

        Task {
            do {
                let result = try await service.download(
                    url: cleanedURL,
                    outputDir: settings.resolvedOutputDirectory,
                    format: fmt,
                    bitrate: settings.defaultBitrate,
                    cookieFile: settings.effectiveCookieFilePath,
                    proxy: settings.useProxy ? settings.proxyAddress : nil,
                    onProgress: { progress in
                        tasks[taskIndex].progress = progress
                    },
                    onOutput: { line in
                        logOutput += line + "\n"
                    }
                )
                tasks[taskIndex].status = .completed
                tasks[taskIndex].title = result.title
                tasks[taskIndex].outputPath = result.path
            } catch {
                tasks[taskIndex].status = .failed
                tasks[taskIndex].errorMessage = error.localizedDescription
                logOutput += "[错误] \(error.localizedDescription)\n"
            }
            isDownloading = false
        }
    }

    private func statusColor(_ status: DownloadTask.TaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .downloading, .converting: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .orange
        }
    }
}
