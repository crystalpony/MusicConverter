import Foundation
import SwiftUI

/// 转换结果
struct ConvertResult: Identifiable {
    let id = UUID()
    let fileName: String
    let outputPath: String
    let success: Bool
    let errorMessage: String?
}

/// 菜单栏待转换文件管理（全局单例）
@MainActor
class MenuBarStateManager: ObservableObject {
    static let shared = MenuBarStateManager()
    
    @Published var pendingFiles: [PendingFile] = []
    @Published var isConverting: Bool = false
    @Published var completedCount: Int = 0
    @Published var failedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var currentConvertingName: String = ""
    @Published var lastBatchResults: [ConvertResult] = []
    @Published var showResults: Bool = false
    
    /// 转换完成后回调（用于弹出主窗口）
    var onConvertComplete: (() -> Void)?
    
    /// 支持的音频格式
    static let supportedAudioExtensions: Set<String> = [
        "mp3", "wav", "flac", "aac", "m4a", "ogg", "opus",
        "wma", "aiff", "aif", "ape", "wv", "ac3", "amr",
        "caf", "webm", "mp4", "mka", "mkv",
    ]
    
    /// 待转换文件模型
    struct PendingFile: Identifiable {
        let id = UUID()
        let url: URL
        var fileName: String { url.lastPathComponent }
        var fileSize: String {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? UInt64 else { return "" }
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
    }
    
    /// 添加文件到待转区（去重）
    func addFiles(_ urls: [URL]) {
        let existingPaths = Set(pendingFiles.map { $0.url.path })
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard Self.supportedAudioExtensions.contains(ext) else { continue }
            guard !existingPaths.contains(url.path) else { continue }
            pendingFiles.append(PendingFile(url: url))
        }
        showResults = false
        lastBatchResults = []
    }
    
    /// 移除单个文件
    func removeFile(_ file: PendingFile) {
        pendingFiles.removeAll { $0.id == file.id }
    }
    
    /// 清空待转区
    func clearAll() {
        pendingFiles.removeAll()
        lastBatchResults = []
        showResults = false
    }
    
    /// 批量转换
    func convertAll(settings: AppSettings, service: FFmpegService) async {
        guard !pendingFiles.isEmpty else { return }
        
        isConverting = true
        completedCount = 0
        failedCount = 0
        totalCount = pendingFiles.count
        lastBatchResults = []
        showResults = false
        
        let outputDir = settings.resolvedOutputDirectory
        let bitrate = settings.defaultBitrate
        let filesToConvert = pendingFiles
        
        for file in filesToConvert {
            currentConvertingName = file.fileName
            do {
                let outputPath = try await service.convert(
                    inputPath: file.url.path,
                    outputDir: outputDir,
                    bitrate: bitrate
                )
                completedCount += 1
                pendingFiles.removeAll { $0.id == file.id }
                
                let result = ConvertResult(fileName: file.fileName, outputPath: outputPath, success: true, errorMessage: nil)
                lastBatchResults.append(result)
                
                // 记录到音乐库
                MusicLibraryStore.shared.addRecord(filePath: outputPath, sourceFileName: file.fileName)
            } catch {
                failedCount += 1
                let result = ConvertResult(fileName: file.fileName, outputPath: "", success: false, errorMessage: error.localizedDescription)
                lastBatchResults.append(result)
                print("[菜单栏转换错误] \(error.localizedDescription)")
            }
        }
        
        currentConvertingName = ""
        isConverting = false
        showResults = true
        
        // 触发回调
        onConvertComplete?()
    }
}
