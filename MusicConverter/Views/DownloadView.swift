import SwiftUI

/// 下载 Tab：URL 输入 + 下载列表 + 进度（复古包豪斯，随窗口自适应）
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
        VStack(alignment: .leading, spacing: 18) {
            // 标题
            HStack(spacing: 10) {
                Rectangle().fill(Bauhaus.red).frame(width: 14, height: 14)
                Text("下载")
                    .font(BauhausFont.title(24))
                    .foregroundStyle(Bauhaus.ink)
                Spacer()
            }

            // URL 输入卡片
            inputBar

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
        .confirmationDialog("选择下载格式", isPresented: $showFormatSheet, titleVisibility: .visible) {
            ForEach(DownloadFormat.downloadMenuOrder, id: \.self) { fmt in
                Button(fmt.dialogLabel) {
                    selectedFormat = fmt
                    startDownload()
                }
            }
            Button("取消", role: .cancel) {
                pendingURL = nil
            }
        } message: {
            Text(formatDialogMessage)
        }
    }

    /// 格式选择弹窗的引导文案
    private var formatDialogMessage: String {
        var lines: [String] = []
        if !pendingPlatform.isEmpty {
            lines.append("来源：\(pendingPlatform)")
        }
        lines.append("要看视频选「视频 MP4」；只要音乐选「仅音频 MP3」。「原画视频」为高阶选项，部分高清编码可能无法在本机直接播放。")
        return lines.joined(separator: "\n")
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Bauhaus.inkSecondary)
                TextField("粘贴音视频链接或视频直链（YouTube / Bilibili / .mp4 等）", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(BauhausFont.body(14))
                    .foregroundStyle(Bauhaus.ink)
                    .onSubmit { promptFormat() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Bauhaus.surface)
            .bauhausBorder(width: 2)

            Button { promptFormat() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("下载")
                }
                .font(BauhausFont.heading(15))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background((urlInput.isEmpty || isDownloading) ? Bauhaus.inkSecondary : Bauhaus.blue)
                .bauhausBorder(width: 2)
            }
            .buttonStyle(.plain)
            .disabled(urlInput.isEmpty || isDownloading)
        }
    }

    // MARK: - 空状态（填满剩余空间）

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Bauhaus.yellow)
                    .frame(width: 96, height: 96)
                    .offset(x: -22)
                    .bauhausBorder(width: 3, cornerRadius: 48)
                Rectangle().fill(Bauhaus.blue)
                    .frame(width: 82, height: 82)
                    .offset(x: 24, y: 10)
                    .bauhausBorder(width: 3, cornerRadius: 2)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 24, y: 10)
            }
            .padding(.bottom, 6)
            Text("粘贴链接即可开始下载")
                .font(BauhausFont.heading(17))
                .foregroundStyle(Bauhaus.ink)
            Text("支持 YouTube / Bilibili / 网易云 等主流平台")
                .font(BauhausFont.body(12))
                .foregroundStyle(Bauhaus.inkSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 任务列表卡片（随窗口拉伸）

    private var taskListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "下载任务", trailing: "\(tasks.count)")

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tasks) { task in
                        taskRow(task)
                        Rectangle()
                            .fill(Bauhaus.ink.opacity(0.12))
                            .frame(height: 1)
                    }
                }
            }
        }
        .background(Bauhaus.surface)
        .bauhausBorder(width: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func taskRow(_ task: DownloadTask) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title.isEmpty ? task.url : task.title)
                    .font(BauhausFont.body(13))
                    .foregroundStyle(Bauhaus.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !task.platform.isEmpty { Text(task.platform) }
                    Text(task.format)
                }
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.inkSecondary)
            }

            Spacer()

            if task.status == .downloading {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .tint(Bauhaus.red)
                    .frame(width: 130)
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

    // MARK: - 逻辑

    /// 弹出格式选择（不再直接下载）
    private func promptFormat() {
        let rawInput = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty else { return }
        // BT / 磁力链接暂不支持
        if PlatformDetector.isTorrentLink(rawInput) {
            logOutput += "[提示] 暂不支持 BT / 磁力链接（magnet:、.torrent）。请粘贴平台链接或视频直链（如 https://…/video.mp4）。\n"
            return
        }
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

        // 免费版累计下载限制（试下载 5 首）
        if !settings.isPro && settings.isDownloadLimitReached {
            logOutput += "[限制] 免费试下载 \(AppSettings.freeDownloadLimit) 首已用完，请升级 Pro 解锁无限下载\n"
            pendingURL = nil
            NotificationCenter.default.post(name: .showProPurchase, object: nil)
            return
        }

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
                    cookiesFromBrowser: settings.effectiveCookieBrowser,
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
                // 入库（音频→音乐库 / 视频→影音库，按扩展名自动判定）
                MusicLibraryStore.shared.addRecord(filePath: result.path, sourceFileName: result.title)
                // 累计下载计数
                settings.totalDownloadCount += 1
                settings.totalSavedMinutes += 2
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
        case .pending: return Bauhaus.inkSecondary
        case .downloading, .converting: return Bauhaus.blue
        case .completed: return Bauhaus.blue
        case .failed: return Bauhaus.red
        case .skipped: return Bauhaus.yellow
        }
    }
}
