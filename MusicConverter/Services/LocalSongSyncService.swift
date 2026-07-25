import Foundation

/// 本地同步支持的音频扩展名
private let syncAudioExtensions: Set<String> = [
    "mp3", "m4a", "flac", "wav", "aac", "ogg", "opus", "aiff", "wma"
]

/// 归一化字符串：小写 + 去空白 + 去标点符号，用于文件名/歌名模糊匹配
private func syncNormalize(_ s: String) -> String {
    let removeChars = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(.symbols)
    return String(s.lowercased().unicodeScalars.filter { !removeChars.contains($0) })
}

/// 递归收集目录（含子目录）内所有音频文件的归一化文件名
private func collectAudioStems(in directory: String) -> Set<String> {
    var stems: Set<String> = []
    let dirURL = URL(fileURLWithPath: directory)
    guard let enumerator = FileManager.default.enumerator(
        at: dirURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { return stems }

    for case let fileURL as URL in enumerator {
        guard syncAudioExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
        let stem = syncNormalize(fileURL.deletingPathExtension().lastPathComponent)
        if !stem.isEmpty { stems.insert(stem) }
    }
    return stems
}

/// 本地歌曲同步服务（全局单例）
/// 扫描下载目录（含子目录）建立本地歌曲索引，供歌单页标记"已下载"、
/// 批量下载器自动跳过已存在的歌曲；支持手动重新扫描
@MainActor
final class LocalSongSyncService: ObservableObject {
    static let shared = LocalSongSyncService()

    /// 是否正在扫描
    @Published var isScanning: Bool = false
    /// 最近一次扫描时间（nil 表示尚未扫描）
    @Published var lastScanDate: Date?
    /// 本地音频文件数量
    @Published private(set) var localFileCount: Int = 0

    /// 归一化文件名索引（来自磁盘扫描）
    private var fileStems: Set<String> = []
    /// 归一化元数据索引（来自音乐库记录的 标题 / 歌手+标题 组合）
    private var metaKeys: Set<String> = []
    /// 单曲匹配结果缓存（songId -> 是否已下载），重扫后清空
    private var matchCache: [String: Bool] = [:]
    /// 已扫描的目录（目录变更时自动重扫）
    private var scannedDirectory: String = ""

    private init() {}

    // MARK: - 扫描

    /// 首次进入或目录变更时才扫描（视图 onAppear 用）
    func rescanIfNeeded(directory: String) async {
        guard lastScanDate == nil || scannedDirectory != directory else { return }
        await rescan(directory: directory)
    }

    /// 重新扫描下载目录，重建本地索引（手动刷新用）
    func rescan(directory: String) async {
        guard !isScanning else { return }
        isScanning = true
        scannedDirectory = directory

        // 磁盘遍历放到后台线程，避免大目录卡 UI
        let expanded = (directory as NSString).expandingTildeInPath
        let stems = await Task.detached(priority: .utility) {
            collectAudioStems(in: expanded)
        }.value

        // 音乐库元数据辅助判定（标题 / 歌手+标题）
        var keys: Set<String> = []
        for record in MusicLibraryStore.shared.records where record.mediaType == .audio {
            let t = syncNormalize(record.title ?? "")
            let a = syncNormalize(record.artist ?? "")
            guard !t.isEmpty else { continue }
            keys.insert(t)
            if !a.isEmpty {
                keys.insert(a + t)
                keys.insert(t + a)
            }
        }

        fileStems = stems
        metaKeys = keys
        localFileCount = stems.count
        matchCache = [:]
        lastScanDate = Date()
        isScanning = false
    }

    /// 下载完成后即时登记新文件，无需整目录重扫
    func register(title: String, artist: String, filePath: String) {
        let stem = syncNormalize(
            URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        )
        if !stem.isEmpty { fileStems.insert(stem) }

        let t = syncNormalize(title)
        let a = syncNormalize(artist)
        if !t.isEmpty {
            metaKeys.insert(t)
            if !a.isEmpty {
                metaKeys.insert(a + t)
                metaKeys.insert(t + a)
            }
        }
        localFileCount = fileStems.count
        // 仅清除"未下载"的缓存结果（已下载的结论不会因新增文件而失效）
        matchCache = matchCache.filter { $0.value }
    }

    // MARK: - 查询

    /// 歌曲是否已存在于本地下载目录（带缓存）
    func isDownloaded(_ song: PlatformSong) -> Bool {
        if let hit = matchCache[song.id] { return hit }
        let result = match(title: song.title, artist: song.artist)
        matchCache[song.id] = result
        return result
    }

    /// 智能去重：按 文件名 / 标题 / 歌手+标题 多维度匹配
    private func match(title: String, artist: String) -> Bool {
        let t = syncNormalize(title)
        guard !t.isEmpty else { return false }
        let a = syncNormalize(artist)

        // 1. 精确匹配：文件名或音乐库元数据 == 标题
        if fileStems.contains(t) || metaKeys.contains(t) { return true }

        // 2. 组合匹配：歌手+标题 / 标题+歌手
        if !a.isEmpty {
            if fileStems.contains(a + t) || fileStems.contains(t + a) { return true }
            if metaKeys.contains(a + t) || metaKeys.contains(t + a) { return true }
        }

        // 3. 模糊匹配：文件名同时包含标题与歌手（兼容 "歌名 - 歌手 (Live)" 等变体）
        if t.count >= 2 {
            for stem in fileStems where stem.contains(t) {
                if a.isEmpty || stem.contains(a) { return true }
            }
        }
        return false
    }
}
