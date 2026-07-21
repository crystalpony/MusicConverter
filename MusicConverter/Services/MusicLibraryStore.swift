import Foundation
import SwiftUI
import Combine

/// 媒体类型
enum MediaType: String, Codable {
    case audio
    case video
}

/// 已转换的音乐文件记录
struct MusicRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String        // 显示文件名
    let filePath: String        // 绝对路径
    let sourceFileName: String  // 原始文件名
    let convertedAt: Date       // 转换时间
    var title: String?          // 标题
    var artist: String?         // 艺人
    var album: String?          // 专辑
    var duration: TimeInterval? // 时长（秒）
    var mediaType: MediaType = .audio  // 音频 / 视频
    var coverPath: String?      // 封面缩略图本地路径

    /// 用于显示的标题（优先 ID3 标题，其次文件名）
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return (fileName as NSString).deletingPathExtension
    }

    /// 是否为视频
    var isVideo: Bool { mediaType == .video }

    init(id: UUID, fileName: String, filePath: String, sourceFileName: String,
         convertedAt: Date, title: String? = nil, artist: String? = nil,
         album: String? = nil, duration: TimeInterval? = nil, mediaType: MediaType = .audio,
         coverPath: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.sourceFileName = sourceFileName
        self.convertedAt = convertedAt
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.mediaType = mediaType
        self.coverPath = coverPath
    }

    // 向后兼容旧 library.json（缺少 mediaType 时默认 audio）
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        fileName = try c.decode(String.self, forKey: .fileName)
        filePath = try c.decode(String.self, forKey: .filePath)
        sourceFileName = try c.decode(String.self, forKey: .sourceFileName)
        convertedAt = try c.decode(Date.self, forKey: .convertedAt)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        album = try c.decodeIfPresent(String.self, forKey: .album)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration)
        mediaType = try c.decodeIfPresent(MediaType.self, forKey: .mediaType) ?? .audio
        coverPath = try c.decodeIfPresent(String.self, forKey: .coverPath)
    }

    static func == (lhs: MusicRecord, rhs: MusicRecord) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - 扩展名判定

    /// 视频扩展名集合
    static let videoExtensions: Set<String> = ["mp4", "mkv", "webm", "mov", "m4v"]

    /// 依据扩展名判定媒体类型
    static func mediaType(forExtension ext: String) -> MediaType {
        videoExtensions.contains(ext.lowercased()) ? .video : .audio
    }
}

/// 音乐库数据管理（全局单例）—— JSON 持久化
@MainActor
class MusicLibraryStore: ObservableObject {
    static let shared = MusicLibraryStore()

    @Published var records: [MusicRecord] = []

    private let fileManager = FileManager.default
    private var appSupportDir: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MusicConverter", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    private var persistenceURL: URL {
        appSupportDir.appendingPathComponent("library.json")
    }
    /// 封面缓存目录
    private var coversDir: URL {
        let dir = appSupportDir.appendingPathComponent("covers", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        loadRecords()
    }

    // MARK: - 忽略列表（“仅移出库”的文件不再被自动扫回）

    private let ignoredKey = "ignoredLibraryPaths"
    private var ignoredPaths: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: ignoredKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: ignoredKey) }
    }

    // MARK: - 持久化

    private func loadRecords() {
        guard fileManager.fileExists(atPath: persistenceURL.path),
              let data = try? Data(contentsOf: persistenceURL),
              let decoded = try? JSONDecoder().decode([MusicRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func saveRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }

    // MARK: - 增删

    /// 添加一条已转换的记录（去重，按 filePath）
    func addRecord(filePath: String, sourceFileName: String) {
        // 用户主动下载/转换 → 取消之前的忽略标记
        if ignoredPaths.contains(filePath) { ignoredPaths.remove(filePath) }
        guard !records.contains(where: { $0.filePath == filePath }) else { return }
        let url = URL(fileURLWithPath: filePath)
        let record = MusicRecord(
            id: UUID(),
            fileName: url.lastPathComponent,
            filePath: filePath,
            sourceFileName: sourceFileName,
            convertedAt: Date(),
            title: nil,
            artist: nil,
            album: nil,
            duration: nil,
            mediaType: MusicRecord.mediaType(forExtension: url.pathExtension)
        )
        records.insert(record, at: 0) // 新的在前
        saveRecords()

        // 异步读取元数据
        Task {
            await refreshMetadata(for: record.id)
        }
    }

    /// 从库中移除（保留磁盘文件，并标记忽略以免被自动扫回）
    func removeRecord(_ record: MusicRecord) {
        if let cover = record.coverPath {
            try? fileManager.removeItem(atPath: cover)
        }
        var ignored = ignoredPaths
        ignored.insert(record.filePath)
        ignoredPaths = ignored
        records.removeAll { $0.id == record.id }
        saveRecords()
    }

    /// 彻底删除（同时删除磁盘源文件与封面）
    func deleteRecordAndFile(_ record: MusicRecord) {
        try? fileManager.removeItem(atPath: record.filePath)
        if let cover = record.coverPath {
            try? fileManager.removeItem(atPath: cover)
        }
        records.removeAll { $0.id == record.id }
        saveRecords()
    }

    /// 清空所有记录
    func clearAll() {
        records.removeAll()
        saveRecords()
    }

    // MARK: - 元数据

    /// 刷新单条记录的 ID3 元数据
    func refreshMetadata(for id: UUID) async {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let url = URL(fileURLWithPath: records[index].filePath)
        let meta = await MetadataReader.readMetadata(for: url)
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].title = meta.title
        records[idx].artist = meta.artist
        records[idx].album = meta.album
        records[idx].duration = meta.duration
        // 保存封面（仅当尚未保存时）
        if records[idx].coverPath == nil, let artwork = meta.artwork {
            records[idx].coverPath = saveCover(artwork, for: id)
        }
        saveRecords()
    }

    /// 将封面数据写入缓存目录，返回路径
    private func saveCover(_ data: Data, for id: UUID) -> String? {
        let dest = coversDir.appendingPathComponent("\(id.uuidString).jpg")
        do {
            try data.write(to: dest, options: .atomic)
            return dest.path
        } catch {
            return nil
        }
    }

    // MARK: - 启动扫描

    /// 从目录导入未记录的音视频文件（只增不删，安全）——用于补回外部下载/历史文件
    func importNewFiles(from directory: String) async {
        let dirURL = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
        guard let enumerator = fileManager.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        let existingPaths = Set(records.map { $0.filePath })
        let ignored = ignoredPaths
        var addedIDs: [UUID] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "mp3" || MusicRecord.videoExtensions.contains(ext) else { continue }
            let path = fileURL.path
            guard !existingPaths.contains(path), !ignored.contains(path) else { continue }

            let record = MusicRecord(
                id: UUID(),
                fileName: fileURL.lastPathComponent,
                filePath: path,
                sourceFileName: fileURL.deletingPathExtension().lastPathComponent,
                convertedAt: (try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date(),
                mediaType: MusicRecord.mediaType(forExtension: ext)
            )
            records.insert(record, at: 0)
            addedIDs.append(record.id)
        }

        guard !addedIDs.isEmpty else { return }
        records.sort { $0.convertedAt > $1.convertedAt }
        saveRecords()
        for id in addedIDs {
            await refreshMetadata(for: id)
        }
    }

    /// 扫描输出目录，补充未记录的 MP3 文件，移除已不存在的记录
    func scanDirectory(_ directory: String) async {
        let dirURL = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
        guard let enumerator = fileManager.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        let existingPaths = Set(records.map { $0.filePath })
        var foundPaths: Set<String> = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "mp3" || MusicRecord.videoExtensions.contains(ext) else { continue }
            let path = fileURL.path
            foundPaths.insert(path)

            if !existingPaths.contains(path) {
                let record = MusicRecord(
                    id: UUID(),
                    fileName: fileURL.lastPathComponent,
                    filePath: path,
                    sourceFileName: fileURL.deletingPathExtension().lastPathComponent,
                    convertedAt: (try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date(),
                    title: nil,
                    artist: nil,
                    album: nil,
                    duration: nil,
                    mediaType: MusicRecord.mediaType(forExtension: ext)
                )
                records.append(record)
            }
        }

        // 移除已不存在的记录
        records.removeAll { !foundPaths.contains($0.filePath) }

        // 按转换时间倒序
        records.sort { $0.convertedAt > $1.convertedAt }
        saveRecords()

        // 异步读取缺失元数据的记录
        for record in records where record.artist == nil || record.duration == nil {
            await refreshMetadata(for: record.id)
        }
    }

    // MARK: - 查询

    /// 按艺人 > 专辑分组
    func groupedRecords() -> [(artist: String, albums: [(album: String, records: [MusicRecord])])] {
        let dict = Dictionary(grouping: records) { $0.artist ?? "未知艺人" }
        return dict.map { artist, recs in
            let albumDict = Dictionary(grouping: recs) { $0.album ?? "未知专辑" }
            let albums = albumDict.map { (album: $0.key, records: $0.value.sorted { $0.convertedAt > $1.convertedAt }) }
                .sorted { $0.album < $1.album }
            return (artist: artist, albums: albums)
        }.sorted { $0.artist < $1.artist }
    }
}
