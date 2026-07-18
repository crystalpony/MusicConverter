import AVFoundation
import SwiftUI

/// 音频播放服务
@MainActor
class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying: Bool = false
    @Published var currentRecordID: UUID?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var playerDelegate: PlayerDelegate?

    /// 当前播放列表（用于上/下一首切换）
    private var playlist: [MusicRecord] = []

    private init() {}

    // MARK: - 当前状态

    /// 当前正在播放的记录
    var currentRecord: MusicRecord? {
        guard let id = currentRecordID else { return nil }
        return playlist.first { $0.id == id }
    }

    /// 是否有下一首
    var hasNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx < playlist.count - 1
    }

    /// 是否有上一首
    var hasPrevious: Bool {
        guard let idx = currentIndex else { return false }
        return idx > 0
    }

    private var currentIndex: Int? {
        guard let id = currentRecordID else { return nil }
        return playlist.firstIndex { $0.id == id }
    }

    // MARK: - 播放控制

    /// 更新播放列表上下文（不打断当前播放）
    func setPlaylist(_ records: [MusicRecord]) {
        playlist = records
    }

    /// 切换播放/暂停（可传入所属列表作为切歌上下文）
    func togglePlay(_ record: MusicRecord, in playlist: [MusicRecord]? = nil) {
        if let playlist { self.playlist = playlist }
        if currentRecordID == record.id {
            if isPlaying { pause() } else { resume() }
        } else {
            play(record)
        }
    }

    /// 仅切换当前歌曲的播放/暂停（供播放条按钮使用）
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if currentRecordID != nil {
            resume()
        }
    }

    /// 播放指定文件
    func play(_ record: MusicRecord) {
        teardownPlayer()

        let url = URL(fileURLWithPath: record.filePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            let delegate = PlayerDelegate { [weak self] in
                Task { @MainActor in self?.handlePlaybackFinished() }
            }
            newPlayer.delegate = delegate
            newPlayer.prepareToPlay()
            newPlayer.play()

            player = newPlayer
            playerDelegate = delegate
            isPlaying = true
            currentRecordID = record.id
            duration = newPlayer.duration
            currentTime = 0

            // 确保当前歌曲在播放列表内
            if !playlist.contains(where: { $0.id == record.id }) {
                playlist.insert(record, at: 0)
            }
            startTimer()
        } catch {
            print("[AudioPlayer] 播放失败: \(error.localizedDescription)")
        }
    }

    /// 暂停
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    /// 恢复播放
    func resume() {
        player?.play()
        isPlaying = true
        startTimer()
    }

    /// 停止并重置
    func stop() {
        teardownPlayer()
        isPlaying = false
        currentRecordID = nil
        currentTime = 0
        duration = 0
    }

    /// 跳转到指定时间
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    /// 播放下一首
    func playNext() {
        guard let idx = currentIndex, idx < playlist.count - 1 else { return }
        play(playlist[idx + 1])
    }

    /// 播放上一首
    func playPrevious() {
        guard let idx = currentIndex, idx > 0 else { return }
        play(playlist[idx - 1])
    }

    // MARK: - 内部

    private func handlePlaybackFinished() {
        if hasNext {
            playNext()
        } else {
            stop()
        }
    }

    private func teardownPlayer() {
        stopTimer()
        player?.stop()
        player?.delegate = nil
        player = nil
        playerDelegate = nil
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

/// AVAudioPlayer 播放结束回调代理
private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
