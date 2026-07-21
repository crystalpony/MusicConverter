import AVKit
import SwiftUI

/// 视频播放服务（基于 AVPlayer）
/// 与音频播放互斥：开始播放视频时暂停音频播放器
@MainActor
class VideoPlayerService: ObservableObject {
    static let shared = VideoPlayerService()

    @Published var player = AVPlayer()
    @Published var currentRecordID: UUID?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var timeObserver: Any?

    private init() {}

    /// 当前正在播放的记录
    var currentRecord: MusicRecord? {
        guard let id = currentRecordID else { return nil }
        return MusicLibraryStore.shared.records.first { $0.id == id }
    }

    // MARK: - 播放控制

    /// 载入并播放一条视频记录
    func play(_ record: MusicRecord) {
        let url = URL(fileURLWithPath: record.filePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // 与音频互斥
        AudioPlayerService.shared.pause()

        removeTimeObserver()

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        currentRecordID = record.id
        currentTime = 0
        duration = 0

        addTimeObserver()
        observeDuration(for: item)

        player.play()
        isPlaying = true
    }

    /// 切换播放/暂停
    func togglePlayPause() {
        guard currentRecordID != nil else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    /// 暂停
    func pause() {
        player.pause()
        isPlaying = false
    }

    /// 停止并清空
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeTimeObserver()
        isPlaying = false
        currentRecordID = nil
        currentTime = 0
        duration = 0
    }

    /// 跳转
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
    }

    // MARK: - 内部

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                if let dur = self.player.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                }
            }
        }
    }

    private func observeDuration(for item: AVPlayerItem) {
        Task { @MainActor in
            // 异步获取时长
            if let dur = try? await item.asset.load(.duration) {
                let seconds = dur.seconds
                if seconds.isFinite { self.duration = seconds }
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
}
