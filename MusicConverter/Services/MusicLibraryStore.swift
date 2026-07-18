import Foundation
import SwiftUI
import Combine

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

    /// 用于显示的标题（优先 ID3 标题，其次文件名）
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return (fileName as NSString).deletingPathExtension
    }

    static func == (lhs: MusicRecord, rhs: MusicRecord) -> Bool {
        lhs.id == rhs.id
    }
}

/// 音乐库数据管理（全局单例）—— JSON 持久化
@MainActor
class MusicLibraryStore: ObservableObject {
    static let shared = MusicLibraryStore()

    @Published var records: [MusicRecord] = []

    private let fileManager = FileManager.default
    private var persistenceURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MusicConverter", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("library.json")
    }

    private init() {
        loadRecords()
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
            duration: nil
        )
        records.insert(record, at: 0) // 新的在前
        saveRecords()

        // 异步读取元数据
        Task {
            await refreshMetadata(for: record.id)
        }
    }

    /// 删除记录
    func removeRecord(_ record: MusicRecord) {
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
        saveRecords()
    }

    // MARK: - 启动扫描

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
            guard ext == "mp3" else { continue }
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
                    duration: nil
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
