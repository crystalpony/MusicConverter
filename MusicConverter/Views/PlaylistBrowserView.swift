import SwiftUI

/// 歌单浏览 + 批量下载 Tab
struct PlaylistBrowserView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var platformService = MusicPlatformService.shared
    // 批量下载状态全局单例：切换 Tab / 窗口后进度不丢失
    @ObservedObject private var batchManager = BatchDownloadManager.shared
    // 本地歌曲同步：标记"已下载"、防止重复下载
    @ObservedObject private var syncService = LocalSongSyncService.shared

    // 歌单选择
    @State private var selectedPlaylist: Playlist?
    @State private var selectedSongs: Set<String> = []  // song id set

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
        .task {
            // 首次进入或下载目录变更时扫描本地歌曲
            await syncService.rescanIfNeeded(directory: settings.resolvedOutputDirectory)
            // 已登录但歌单为空时自动刷新（每次进入该页都会检查）
            if account?.isLoggedIn == true,
               platformService.playlists.isEmpty,
               !platformService.isLoadingPlaylists {
                await platformService.loadPlaylists()
            }
        }
        .alert("批量下载完成", isPresented: $batchManager.showResult) {
            Button("好的") { }
            Button("查看音乐库") {
                NotificationCenter.default.post(name: .showMusicLibrary, object: nil)
            }
        } message: {
            if let result = batchManager.lastResult {
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
            .onChange(of: platformService.selectedPlatform) { _ in
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
        .frame(maxHeight: .infinity)
        .background(Bauhaus.paper)
    }

    /// 当前登录账号（便捷访问）
    private var account: MusicPlatformAccount? {
        platformService.accounts[platformService.selectedPlatform]
    }

    /// 可下载的歌曲（排除本地已存在的）
    private var downloadableSongs: [PlatformSong] {
        platformService.currentSongs.filter { !syncService.isDownloaded($0) }
    }

    // MARK: - 右侧面板

    private var rightPanel: some View {
        VStack(spacing: 0) {
            if let playlist = selectedPlaylist {
                // 歌单标题
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(BauhausFont.title(18))
                            .foregroundStyle(Bauhaus.ink)
                        Text("\(playlist.trackCount) 首 · 来自\(playlist.platform.rawValue)")
                            .font(BauhausFont.body(12))
                            .foregroundStyle(Bauhaus.inkSecondary)
                    }
                    Spacer()

                    // 同步刷新：重新扫描下载目录，更新"已下载"标识
                    Button {
                        Task { await syncService.rescan(directory: settings.resolvedOutputDirectory) }
                    } label: {
                        if syncService.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("同步", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .font(.caption)
                    .disabled(syncService.isScanning)
                    .help("重新扫描下载目录，更新歌曲的\"已下载\"标识")

                    // 全选/反选（仅针对未下载且不在队列中的歌曲）
                    Button(selectedSongs.count == downloadableSongs.count && !downloadableSongs.isEmpty ? "取消全选" : "全选") {
                        if selectedSongs.count == downloadableSongs.count {
                            selectedSongs = []
                        } else {
                            selectedSongs = Set(downloadableSongs.map { $0.id })
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

                    // 下载状态窗口入口（有任务时显示）
                    if !batchManager.tasks.isEmpty {
                        Button {
                            openWindow(id: "download-status")
                        } label: {
                            Label(batchManager.isDownloading
                                  ? "下载状态 \(batchManager.completedCount)/\(batchManager.totalCount)"
                                  : "下载状态",
                                  systemImage: "list.bullet.rectangle")
                        }
                        .help("打开下载状态窗口，查看所有下载中和待下载的歌曲")
                    }

                    // 批量下载按钮（下载中也可继续追加到队列）
                    Button {
                        startBatchDownload()
                    } label: {
                        Label(batchManager.isDownloading
                              ? "加入队列 (\(selectedSongs.count))"
                              : "下载选中 (\(selectedSongs.count))",
                              systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSongs.isEmpty)
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
                                task: batchManager.task(forSongId: song.id),
                                isLocalDownloaded: syncService.isDownloaded(song),
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
                if batchManager.isDownloading {
                    VStack(spacing: 6) {
                        ProgressView(value: Double(batchManager.completedCount), total: Double(max(batchManager.totalCount, 1)))
                        HStack(spacing: 6) {
                            Text("正在下载 \(batchManager.completedCount)/\(batchManager.totalCount)")
                            if let title = batchManager.currentDownloadingTitle {
                                Text("·")
                                Text(title).lineLimit(1)
                            }
                        }
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
                    ZStack {
                        Rectangle().fill(Bauhaus.blue.opacity(0.2)).frame(width: 72, height: 72)
                            .bauhausBorder(width: 3)
                        Image(systemName: "music.note.list")
                            .font(.system(size: 34))
                            .foregroundStyle(Bauhaus.blue)
                    }
                    Text("选择一个歌单开始浏览")
                        .font(BauhausFont.heading(15))
                        .foregroundStyle(Bauhaus.ink)
                    if account?.isLoggedIn != true {
                        Text("请先登录音乐平台账号")
                            .font(BauhausFont.body(12))
                            .foregroundStyle(Bauhaus.inkSecondary)
                    }
                }
                Spacer()
            }
        }
        .frame(maxHeight: .infinity)
        .background(Bauhaus.paper)
    }

    // MARK: - 批量下载

    private func startBatchDownload() {
        // 过滤本地已存在与已在队列中（待下载/下载中）的歌曲，避免重复下载
        let songsToDownload = platformService.currentSongs.filter {
            selectedSongs.contains($0.id)
                && !batchManager.isQueued(songId: $0.id)
                && !syncService.isDownloaded($0)
        }
        guard !songsToDownload.isEmpty else { return }

        // 免费版累计下载限制（试下载 5 首，含队列中预占的配额）
        if !settings.isPro {
            if settings.isDownloadLimitReached {
                // 已达上限，弹出 Pro 升级提示
                NotificationCenter.default.post(name: .showProPurchase, object: nil)
                return
            }
            if songsToDownload.count + batchManager.activeCount > settings.remainingFreeDownloads {
                // 本批次超出剩余配额，弹出 Pro 升级提示
                NotificationCenter.default.post(name: .showProPurchase, object: nil)
                return
            }
        }

        // 交给全局管理器执行，下载中也可继续追加，视图销毁不影响下载
        batchManager.enqueue(
            songs: songsToDownload,
            format: selectedFormat,
            playlistName: selectedPlaylist?.name ?? "",
            settings: settings
        )

        // 清空选择，方便继续挑下一批
        selectedSongs = []

        // 自动打开下载状态窗口，方便监视整个队列
        openWindow(id: "download-status")
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
                Rectangle()
                    .fill(Bauhaus.yellow.opacity(0.4))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(Bauhaus.ink)
                    }
            }
            .frame(width: 40, height: 40)
            .clipped()
            .bauhausBorder(width: 2, cornerRadius: 2)
            .bauhausHardShadow(x: 2, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(BauhausFont.body(13))
                    .fontWeight(.semibold)
                    .foregroundStyle(Bauhaus.ink)
                    .lineLimit(1)
                Text("\(playlist.trackCount) 首")
                    .font(BauhausFont.body(11))
                    .foregroundStyle(Bauhaus.inkSecondary)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - 歌曲行视图

struct SongRowView: View {
    let song: PlatformSong
    let isSelected: Bool
    /// 本批次中该歌曲的下载任务（nil 表示不在本批次）
    var task: DownloadTask? = nil
    /// 本地下载目录中已存在该歌曲
    var isLocalDownloaded: Bool = false
    let onToggle: () -> Void

    /// 该歌曲是否在队列中未处理完（此时不允许改选，防止重复添加）
    private var isQueued: Bool {
        task?.status == .pending || task?.status == .downloading
    }

    /// 是否锁定勾选（队列处理中 / 本地已下载）
    private var isLocked: Bool {
        isQueued || isLocalDownloaded
    }

    var body: some View {
        HStack(spacing: 10) {
            // 方形勾选框（本地已下载显示绿色对勾并锁定）
            Button(action: onToggle) {
                ZStack {
                    Rectangle()
                        .fill(isLocalDownloaded ? Color.green.opacity(0.9) : (isSelected ? Bauhaus.red : Color.clear))
                        .frame(width: 18, height: 18)
                        .bauhausBorder(width: 2, cornerRadius: 2)
                    if isLocalDownloaded || isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLocked)

            // 歌曲信息（已下载置灰）
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(BauhausFont.body(13))
                    .foregroundStyle(isLocalDownloaded ? Bauhaus.inkSecondary : Bauhaus.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(song.artist)
                    Text("·")
                    Text(song.album)
                }
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.inkSecondary)
                .lineLimit(1)
            }

            Spacer()

            // 下载状态（本批次内的歌曲实时展示；否则显示本地"已下载"标识）
            if let task {
                statusView(for: task)
            } else if isLocalDownloaded {
                Label("已下载", systemImage: "checkmark.circle.fill")
                    .font(BauhausFont.body(11))
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
                    .help("下载目录中已存在该歌曲，无需重复下载")
            }

            // 时长
            Text(song.formattedDuration)
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.inkSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLocked { onToggle() }
        }
    }

    /// 单曲下载状态标签
    @ViewBuilder
    private func statusView(for task: DownloadTask) -> some View {
        switch task.status {
        case .downloading:
            HStack(spacing: 6) {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 70)
                Text("\(Int(task.progress * 100))%")
                    .font(BauhausFont.body(11))
                    .foregroundStyle(Bauhaus.blue)
                    .monospacedDigit()
            }
        case .completed:
            Label("已完成", systemImage: "checkmark.circle.fill")
                .font(BauhausFont.body(11))
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        case .failed:
            Label("失败", systemImage: "xmark.circle.fill")
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.red)
                .labelStyle(.titleAndIcon)
                .help(task.errorMessage ?? "下载失败")
        case .skipped:
            Text("已跳过")
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.yellow)
        case .pending:
            Text("等待中")
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.inkSecondary)
        case .converting:
            Text("转换中")
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.blue)
        }
    }
}

// MARK: - Helpers (end of file)
