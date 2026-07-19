import SwiftUI

/// 歌单浏览 + 批量下载 Tab
struct PlaylistBrowserView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var platformService = MusicPlatformService.shared
    @StateObject private var ytDlpService = YtDlpService()

    // 歌单选择
    @State private var selectedPlaylist: Playlist?
    @State private var selectedSongs: Set<String> = []  // song id set
    @State private var isBatchDownloading: Bool = false
    @State private var batchProgress: (current: Int, total: Int) = (0, 0)
    @State private var batchTasks: [DownloadTask] = []
    @State private var showBatchResult: Bool = false
    @State private var lastBatchResult: YtDlpService.BatchResult?

    // 登录弹窗
    @State private var showLoginSheet: Bool = false

    // 格式选择
    @State private var selectedFormat: DownloadFormat = .audioMP3

    var body: some View {
        HSplitView {
            // 左侧：平台切换 + 歌单列表
            leftPanel
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            // 右侧：歌曲列表 + 批量操作
            rightPanel
                .frame(minWidth: 400)
        }
        .sheet(isPresented: $showLoginSheet) {
            PlatformLoginView(platform: platformService.selectedPlatform)
        }
        .alert("批量下载完成", isPresented: $showBatchResult) {
            Button("好的") { }
            Button("查看音乐库") {
                NotificationCenter.default.post(name: .showMusicLibrary, object: nil)
            }
        } message: {
            if let result = lastBatchResult {
                Text("成功 \(result.completed) 首，跳过 \(result.skipped) 首，失败 \(result.failed) 首\n耗时 \(formatDuration(result.totalDuration))")
            }
        }
    }

    // MARK: - 左侧面板

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 平台切换
            Picker("平台", selection: $platformService.selectedPlatform) {
                ForEach(MusicPlatform.allCases, id: \.self) { platform in
                    Label(platform.rawValue, systemImage: platform.icon)
                        .tag(platform)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: platformService.selectedPlatform) { _, _ in
                selectedPlaylist = nil
                selectedSongs = []
                Task { await platformService.loadPlaylists() }
            }

            // 登录状态
            if let account = platformService.accounts[platformService.selectedPlatform],
               account.isLoggedIn {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text(account.nickname)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("刷新") {
                        Task { await platformService.loadPlaylists() }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    showLoginSheet = true
                } label: {
                    Label("登录\(platformService.selectedPlatform.rawValue)", systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Divider()

            // 歌单列表
            if platformService.isLoadingPlaylists {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("加载歌单中...")
                    Spacer()
                }
                Spacer()
            } else if platformService.playlists.isEmpty && account?.isLoggedIn == true {
                Spacer()
                Text("暂无歌单")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(platformService.playlists, selection: Binding(
                    get: { selectedPlaylist },
                    set: { newValue in
                        selectedPlaylist = newValue
                        selectedSongs = []
                        if let playlist = newValue {
                            Task { await platformService.loadSongs(for: playlist) }
                        }
                    }
                )) { playlist in
                    PlaylistRowView(playlist: playlist)
                        .tag(playlist)
                }
                .listStyle(.sidebar)
            }
        }
        .padding(.vertical, 8)
    }

    /// 当前登录账号（便捷访问）
    private var account: MusicPlatformAccount? {
        platformService.accounts[platformService.selectedPlatform]
    }

    // MARK: - 右侧面板

    private var rightPanel: some View {
        VStack(spacing: 0) {
            if let playlist = selectedPlaylist {
                // 歌单标题
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("\(playlist.trackCount) 首 · 来自\(playlist.platform.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    // 全选/反选
                    Button(selectedSongs.count == platformService.currentSongs.count ? "取消全选" : "全选") {
                        if selectedSongs.count == platformService.currentSongs.count {
                            selectedSongs = []
                        } else {
                            selectedSongs = Set(platformService.currentSongs.map { $0.id })
                        }
                    }
                    .font(.caption)

                    // 格式选择
                    Picker("格式", selection: $selectedFormat) {
                        ForEach(DownloadFormat.allCases, id: \.self) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .frame(width: 160)

                    // 批量下载按钮
                    Button {
                        startBatchDownload()
                    } label: {
                        Label("下载选中 (\(selectedSongs.count))", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSongs.isEmpty || isBatchDownloading)
                }
                .padding()

                Divider()

                // 歌曲列表
                if platformService.isLoadingSongs {
                    Spacer()
                    ProgressView("加载歌曲中...")
                    Spacer()
                } else {
                    List {
                        ForEach(platformService.currentSongs) { song in
                            SongRowView(
                                song: song,
                                isSelected: selectedSongs.contains(song.id),
                                isDownloading: isBatchDownloading,
                                onToggle: {
                                    if selectedSongs.contains(song.id) {
                                        selectedSongs.remove(song.id)
                                    } else {
                                        selectedSongs.insert(song.id)
                                    }
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }

                // 批量下载进度条
                if isBatchDownloading {
                    VStack(spacing: 6) {
                        ProgressView(value: Double(batchProgress.current), total: Double(max(batchProgress.total, 1)))
                        Text("正在下载 \(batchProgress.current)/\(batchProgress.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.05))
                }

            } else {
                // 未选择歌单
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("选择一个歌单开始浏览")
                        .foregroundStyle(.secondary)
                    if account?.isLoggedIn != true {
                        Text("请先登录音乐平台账号")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - 批量下载

    private func startBatchDownload() {
        let songsToDownload = platformService.currentSongs.filter { selectedSongs.contains($0.id) }
        guard !songsToDownload.isEmpty else { return }

        // 免费版限制
        if !settings.isPro && songsToDownload.count > settings.effectiveConvertLimit {
            // 弹出 Pro 升级提示（通过通知触发）
            NotificationCenter.default.post(name: .showProPurchase, object: nil)
            return
        }

        isBatchDownloading = true
        batchProgress = (0, songsToDownload.count)
        batchTasks = []

        let playlistName = selectedPlaylist?.name ?? ""
        let cookieFile = settings.effectiveCookieFilePath

        Task {
            let result = await ytDlpService.batchDownload(
                songs: songsToDownload,
                outputDir: settings.resolvedOutputDirectory,
                format: selectedFormat,
                bitrate: settings.defaultBitrate,
                cookieFile: cookieFile,
                proxy: settings.useProxy ? settings.proxyAddress : nil,
                playlistName: playlistName,
                onTaskUpdate: { index, task in
                    if index < batchTasks.count {
                        batchTasks[index] = task
                    } else {
                        batchTasks.append(task)
                    }
                },
                onProgress: { current, total in
                    batchProgress = (current, total)
                }
            )

            // 更新统计数据
            settings.totalDownloadCount += result.completed
            // 每首歌约节省 2 分钟手动操作
            settings.totalSavedMinutes += result.completed * 2

            lastBatchResult = result
            isBatchDownloading = false
            showBatchResult = true
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins) 分 \(secs) 秒"
        }
        return "\(secs) 秒"
    }
}

// MARK: - 歌单行视图

struct PlaylistRowView: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 10) {
            // 封面
            AsyncImage(url: URL(string: playlist.coverURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 40, height: 40)
            .cornerRadius(4)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)
                Text("\(playlist.trackCount) 首")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 歌曲行视图

struct SongRowView: View {
    let song: PlatformSong
    let isSelected: Bool
    let isDownloading: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // 勾选框
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(isDownloading)

            // 歌曲信息
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(song.artist)
                    Text("·")
                    Text(song.album)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            // 时长
            Text(song.formattedDuration)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

// MARK: - Helpers (end of file)
