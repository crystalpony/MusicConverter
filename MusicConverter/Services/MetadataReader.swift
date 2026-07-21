import AVFoundation
import AppKit

/// 音视频文件元数据读取器
enum MetadataReader {
    struct Metadata {
        let title: String?
        let artist: String?
        let album: String?
        let duration: TimeInterval?
        let artwork: Data?   // 封面原始数据（JPEG/PNG）
    }

    /// 读取音频文件的元数据（标题、艺人、专辑、时长）
    static func readMetadata(for url: URL) async -> Metadata {
        let asset = AVURLAsset(url: url)

        // 时长
        var duration: TimeInterval?
        if let d = try? await asset.load(.duration) {
            duration = d.seconds.isFinite ? d.seconds : nil
        }

        var title: String?
        var artist: String?
        var album: String?

        // 1. 通用元数据
        if let common = try? await asset.load(.commonMetadata) {
            for item in common {
                guard let key = item.commonKey else { continue }
                let value = try? await item.load(.stringValue)
                switch key {
                case .commonKeyTitle:
                    if title == nil { title = value }
                case .commonKeyArtist:
                    if artist == nil { artist = value }
                case .commonKeyAlbumName:
                    if album == nil { album = value }
                default:
                    break
                }
            }
        }

        // 2. 格式专有元数据（ID3 / iTunes），补齐通用元数据读不到的字段
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                guard let items = try? await asset.loadMetadata(for: format) else { continue }
                for item in items {
                    guard let identifier = item.identifier else { continue }
                    guard let value = try? await item.load(.stringValue),
                          !value.isEmpty else { continue }

                    switch identifier {
                    case .id3MetadataTitleDescription, .iTunesMetadataSongName:
                        if title == nil { title = value }
                    case .id3MetadataLeadPerformer, .id3MetadataOriginalArtist,
                         .id3MetadataBand, .iTunesMetadataArtist, .iTunesMetadataAlbumArtist:
                        if artist == nil { artist = value }
                    case .id3MetadataAlbumTitle, .iTunesMetadataAlbum:
                        if album == nil { album = value }
                    default:
                        break
                    }
                }
            }
        }

        // 3. 文件名兜底：解析 "艺人 - 标题" 格式
        if artist == nil || title == nil {
            let base = url.deletingPathExtension().lastPathComponent
            let separators = [" - ", " – ", "-", "_"]
            var matched = false
            for sep in separators {
                let parts = base.components(separatedBy: sep)
                if parts.count >= 2,
                   !parts[0].trimmingCharacters(in: .whitespaces).isEmpty {
                    if artist == nil {
                        artist = parts[0].trimmingCharacters(in: .whitespaces)
                    }
                    if title == nil {
                        title = parts[1...].joined(separator: sep).trimmingCharacters(in: .whitespaces)
                    }
                    matched = true
                    break
                }
            }
            if !matched, title == nil {
                title = base
            }
        }

        // 4. 封面：优先内嵌（音频/视频），视频无内嵌时抽帧生成
        var artwork = await loadEmbeddedArtwork(from: asset)
        if artwork == nil,
           MusicRecord.videoExtensions.contains(url.pathExtension.lowercased()) {
            artwork = await generateVideoThumbnail(from: asset)
        }

        return Metadata(
            title: clean(title),
            artist: clean(artist),
            album: clean(album),
            duration: duration,
            artwork: artwork
        )
    }

    // MARK: - 封面提取

    /// 提取内嵌封面（通用 artwork + ID3/iTunes 图片）
    private static func loadEmbeddedArtwork(from asset: AVURLAsset) async -> Data? {
        if let common = try? await asset.load(.commonMetadata) {
            for item in common where item.commonKey == .commonKeyArtwork {
                if let data = try? await item.load(.dataValue), !data.isEmpty { return data }
            }
        }
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                guard let items = try? await asset.loadMetadata(for: format) else { continue }
                for item in items {
                    guard item.identifier == .id3MetadataAttachedPicture
                            || item.identifier == .iTunesMetadataCoverArt else { continue }
                    if let data = try? await item.load(.dataValue), !data.isEmpty { return data }
                }
            }
        }
        return nil
    }

    /// 为视频抽帧生成缩略图（取第 1 秒处）
    private static func generateVideoThumbnail(from asset: AVURLAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        guard let (cgImage, _) = try? await generator.image(at: time) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    /// 清理空白字符，空字符串归为 nil
    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
