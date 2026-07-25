import Foundation

/// 歌单批量下载管理器（全局单例，动态队列）
/// 批量下载状态独立于视图生命周期：切换 Tab / 窗口后进度、任务列表不丢失；
/// 下载进行中仍可继续追加新歌曲，自动按 songId 去重并排入队尾串行下载
@MainActor
final class BatchDownloadManager: ObservableObject {
    static let shared = BatchDownloadManager()

    private let ytDlpService = YtDlpService()

    /// 是否有队列在下载
    @Published var isDownloading: Bool = false
    /// 本轮会话所有任务（含追加的，按 songId 对应）
    @Published var tasks: [DownloadTask] = []
    /// 整体进度（已处理数, 总数；追加歌曲后总数动态增长）
    @Published var completedCount: Int = 0
    @Published var totalCount: Int = 0
    /// 最近一轮下载结果
    @Published var lastResult: YtDlpService.BatchResult?
    /// 是否展示结果弹窗
    @Published var showResult: Bool = false

    /// 待下载队列（与 tasks 中 pending 项一一对应）
    private var queue: [(song: PlatformSong, format: DownloadFormat, playlistName: String)] = []
    /// songId -> tasks 下标索引（会话内 tasks 只追加不删除，下标稳定），列表渲染 O(1) 查询
    private var taskIndexBySongId: [String: Int] = [:]
    /// 串行下载工作协程（nil 表示空闲）
    private var worker: Task<Void, Never>?
    private var sessionStart = Date()
    private var sessionResult = YtDlpService.BatchResult()

    private init() {}

    /// 按歌曲 ID 查询本轮任务状态（O(1)，供列表每行渲染调用）
    func task(forSongId id: String) -> DownloadTask? {
        guard let idx = taskIndexBySongId[id] else { return nil }
        return tasks[idx]
    }

    /// 当前正在下载的歌曲标题（用于进度条文案）
    var currentDownloadingTitle: String? {
        tasks.first { $0.status == .downloading }?.title
    }

    /// 队列中未处理完的数量（待下载 + 下载中），用于免费配额预占计算
    var activeCount: Int {
        tasks.filter { $0.status == .pending || $0.status == .downloading }.count
    }

    /// 歌曲是否已在队列中（待下载或下载中，避免重复添加）
    func isQueued(songId: String) -> Bool {
        guard let t = task(forSongId: songId) else { return false }
        return t.status == .pending || t.status == .downloading
    }

    /// 追加歌曲到下载队列（下载中也可继续添加；已在队列中的自动跳过）
    /// 本地已存在的歌曲不下载，直接以"已跳过"状态展示在状态窗口
    func enqueue(
        songs: [PlatformSong],
        format: DownloadFormat,
        playlistName: String,
        settings: AppSettings
    ) {
        let newSongs = songs.filter { !isQueued(songId: $0.id) }
        guard !newSongs.isEmpty else { return }

        // 空闲状态开新一轮会话：清空上一轮任务与统计
        if worker == nil {
            tasks = []
            taskIndexBySongId = [:]
            completedCount = 0
            totalCount = 0
            sessionResult = YtDlpService.BatchResult()
            sessionStart = Date()
        }

        let sync = LocalSongSyncService.shared
        var enqueuedCount = 0

        for song in newSongs {
            // 本地已存在 → 直接标记"已跳过"，不进下载队列
            if sync.isDownloaded(song) {
                guard task(forSongId: song.id) == nil else { continue }
                appendTask(makeTask(
                    for: song, format: format, playlistName: playlistName,
                    settings: settings, status: .skipped
                ))
                sessionResult.skipped += 1
                totalCount += 1
                continue
            }

            appendTask(makeTask(
                for: song, format: format, playlistName: playlistName,
                settings: settings, status: .pending
            ))
            queue.append((song, format, playlistName))
            totalCount += 1
            enqueuedCount += 1
        }
        completedCount = sessionResult.completed + sessionResult.failed + sessionResult.skipped

        if worker == nil && enqueuedCount > 0 {
            isDownloading = true
            worker = Task { await self.processQueue(settings: settings) }
        }
    }

    /// 追加任务并维护 songId 索引
    private func appendTask(_ task: DownloadTask) {
        tasks.append(task)
        taskIndexBySongId[task.songId] = tasks.count - 1
    }

    /// 构造下载任务
    private func makeTask(
        for song: PlatformSong,
        format: DownloadFormat,
        playlistName: String,
        settings: AppSettings,
        status: DownloadTask.TaskStatus
    ) -> DownloadTask {
        DownloadTask(
            url: song.downloadURL,
            title: song.title,
            platform: song.platform.rawValue,
            status: status,
            bitrate: settings.defaultBitrate,
            format: format.rawValue,
            sourcePlaylist: playlistName,
            artist: song.artist,
            duration: song.duration,
            sourcePlatform: song.platform.rawValue,
            songId: song.id
        )
    }

    /// 串行消费队列，直到全部下完（期间追加的会继续处理）
    private func processQueue(settings: AppSettings) async {
        while !queue.isEmpty {
            let item = queue.removeFirst()
            guard let idx = taskIndexBySongId[item.song.id],
                  tasks[idx].status == .pending else { continue }

            tasks[idx].status = .downloading

            do {
                let result = try await ytDlpService.download(
                    url: item.song.downloadURL,
                    outputDir: settings.resolvedOutputDirectory,
                    format: item.format,
                    bitrate: settings.defaultBitrate,
                    cookieFile: settings.effectiveCookieFilePath,
                    cookiesFromBrowser: settings.effectiveCookieBrowser,
                    proxy: settings.useProxy ? settings.proxyAddress : nil,
                    onProgress: { [weak self] progress in
                        // tasks 在会话内只追加不删除，idx 稳定
                        self?.tasks[idx].progress = progress
                    }
                )

                tasks[idx].status = .completed
                tasks[idx].outputPath = result.path
                tasks[idx].title = result.title
                sessionResult.completed += 1

                // 入库到音乐库 + 登记本地同步索引 + 更新统计（每首约节省 2 分钟手动操作）
                MusicLibraryStore.shared.addRecord(
                    filePath: result.path,
                    sourceFileName: item.song.title
                )
                LocalSongSyncService.shared.register(
                    title: item.song.title,
                    artist: item.song.artist,
                    filePath: result.path
                )
                settings.totalDownloadCount += 1
                settings.totalSavedMinutes += 2

            } catch {
                // 判断是否为"已存在"跳过
                if error.localizedDescription.contains("already exists") {
                    tasks[idx].status = .skipped
                    sessionResult.skipped += 1
                } else {
                    tasks[idx].status = .failed
                    tasks[idx].errorMessage = error.localizedDescription
                    sessionResult.failed += 1
                }
            }

            completedCount = sessionResult.completed + sessionResult.failed + sessionResult.skipped
        }

        sessionResult.totalDuration = Date().timeIntervalSince(sessionStart)
        lastResult = sessionResult
        isDownloading = false
        showResult = true
        worker = nil
    }
}
