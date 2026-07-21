import SwiftUI
import AppKit

/// 音乐库视图 - 显示已转换的音乐文件列表
struct MusicLibraryView: View {
    @ObservedObject var library = MusicLibraryStore.shared
    @ObservedObject var player = AudioPlayerService.shared
    @EnvironmentObject var settings: AppSettings
    
    @State private var searchText: String = ""
    @State private var viewMode: ViewMode = .list
    @State private var sortOrder: SortOrder = .newest
    @State private var isSeeking: Bool = false
    @State private var seekValue: Double = 0
    
    enum ViewMode {
        case list, grouped
    }
    
    enum SortOrder: String, CaseIterable {
        case newest = "最新优先"
        case oldest = "最早优先"
        case name = "按文件名"
    }
    
    private var filteredRecords: [MusicRecord] {
        var records = library.records.filter { !$0.isVideo }
        // 搜索过滤
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            records = records.filter {
                $0.fileName.lowercased().contains(query) ||
                ($0.artist ?? "").lowercased().contains(query) ||
                ($0.album ?? "").lowercased().contains(query) ||
                $0.sourceFileName.lowercased().contains(query)
            }
        }
        // 排序
        switch sortOrder {
        case .newest:
            records.sort { $0.convertedAt > $1.convertedAt }
        case .oldest:
            records.sort { $0.convertedAt < $1.convertedAt }
        case .name:
            records.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        }
        return records
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar
            Rectangle().fill(Bauhaus.ink).frame(height: 2)

            if filteredRecords.isEmpty {
                emptyState
            } else if viewMode == .list {
                listView
            } else {
                groupedView
            }

            // 底部播放条
            if player.currentRecordID != nil {
                Rectangle().fill(Bauhaus.ink).frame(height: 2)
                playerBar
            }
        }
        .background(Bauhaus.paper)
        .task {
            // 进入音乐库时自动补回输出目录里尚未入库的音频（只增不删）
            await library.importNewFiles(from: settings.resolvedOutputDirectory)
        }
    }
    
    // MARK: - 工具栏
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索文件名、艺人、专辑...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            
            // 排序
            Picker("", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            // 视图切换
            Button {
                viewMode = viewMode == .list ? .grouped : .list
            } label: {
                Image(systemName: viewMode == .list ? "rectangle.grid.1x2" : "list.bullet")
            }
            .help(viewMode == .list ? "切换为分组视图" : "切换为列表视图")
            
            // 打开输出目录
            Button {
                let path = settings.resolvedOutputDirectory
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            } label: {
                Image(systemName: "folder")
            }
            .help("打开输出目录")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - 空白状态
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("还没有转换过的音乐")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("拖拽文件到菜单栏图标或使用「转换」功能开始")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 列表视图
    
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredRecords) { record in
                    musicRow(record, playlist: filteredRecords)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 分组视图
    
    private var groupedView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                let grouped = library.groupedRecords()
                ForEach(grouped, id: \.artist) { group in
                    DisclosureGroup {
                        ForEach(group.albums, id: \.album) { albumGroup in
                            DisclosureGroup {
                                ForEach(albumGroup.records) { record in
                                    musicRow(record, playlist: albumGroup.records)
                                }
                                .padding(.leading, 16)
                            } label: {
                                HStack {
                                    Image(systemName: "opticaldisc")
                                        .foregroundStyle(.secondary)
                                    Text(albumGroup.album)
                                        .font(.subheadline)
                                    Text("(\(albumGroup.records.count))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.accentColor)
                            Text(group.artist)
                                .font(.headline)
                            let total = group.albums.reduce(0) { $0 + $1.records.count }
                            Text("(\(total))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 音乐行
    
    private func musicRow(_ record: MusicRecord, playlist: [MusicRecord]) -> some View {
        let isCurrent = player.currentRecordID == record.id
        
        return HStack(spacing: 10) {
            // 封面缩略图
            CoverImageView(path: record.coverPath, fallbackIcon: "music.note",
                           accent: isCurrent ? Bauhaus.red : Bauhaus.blue)
                .frame(width: 40, height: 40)
                .clipped()
                .bauhausBorder(width: 1.5, cornerRadius: 2)

            // 播放按钮
            Button {
                player.togglePlay(record, in: playlist)
            } label: {
                Image(systemName: isCurrent && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                
                HStack(spacing: 6) {
                    if let artist = record.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let album = record.album, !album.isEmpty {
                        Text("-")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let duration = record.duration {
                        Text(formatDuration(duration))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // 转换时间
            Text(record.convertedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            // 打开文件夹
            Button {
                NSWorkspace.shared.selectFile(record.filePath, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("在 Finder 中显示")
            
            // 删除
            Button {
                library.removeRecord(record)
                if player.currentRecordID == record.id {
                    player.stop()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("从音乐库移除")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent
                      ? Color.accentColor.opacity(0.1)
                      : Color(nsColor: .controlBackgroundColor))
        )
    }
    
    // MARK: - 底部播放条

    private var playerBar: some View {
        VStack(spacing: 8) {
            // 正在播放信息
            HStack(spacing: 10) {
                // 封面方块
                ZStack {
                    Rectangle().fill(Bauhaus.yellow)
                    Image(systemName: "music.note")
                        .foregroundStyle(Bauhaus.ink)
                }
                .frame(width: 34, height: 34)
                .bauhausBorder(width: 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(player.currentRecord?.displayTitle ?? "")
                        .font(BauhausFont.heading(13))
                        .foregroundStyle(Bauhaus.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let artist = player.currentRecord?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(BauhausFont.body(11))
                            .foregroundStyle(Bauhaus.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()

                // 音量
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .font(.caption2)
                        .foregroundStyle(Bauhaus.inkSecondary)
                    Slider(value: Binding(
                        get: { Double(player.volume) },
                        set: { player.volume = Float($0) }
                    ), in: 0...1)
                    .frame(width: 90)
                    .tint(Bauhaus.blue)
                }
            }

            // 进度条
            HStack(spacing: 8) {
                Text(formatDuration(isSeeking ? seekValue : player.currentTime))
                    .font(BauhausFont.body(11))
                    .foregroundStyle(Bauhaus.inkSecondary)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { isSeeking ? seekValue : player.currentTime },
                        set: { seekValue = $0 }
                    ),
                    in: 0...max(player.duration, 0.1),
                    onEditingChanged: { editing in
                        if editing {
                            isSeeking = true
                        } else {
                            player.seek(to: seekValue)
                            isSeeking = false
                        }
                    }
                )
                .tint(Bauhaus.red)

                Text(formatDuration(player.duration))
                    .font(BauhausFont.body(11))
                    .foregroundStyle(Bauhaus.inkSecondary)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .leading)
            }

            // 控制按钮
            HStack(spacing: 24) {
                // 随机
                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.body)
                        .foregroundStyle(player.isShuffle ? Bauhaus.red : Bauhaus.inkSecondary)
                }
                .buttonStyle(.plain)
                .help(player.isShuffle ? "随机播放：开" : "随机播放：关")

                Button {
                    player.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.body)
                        .foregroundStyle(player.hasPrevious ? Bauhaus.ink : Bauhaus.inkSecondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!player.hasPrevious)

                // 播放/暂停（圆形硬边框）
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.body)
                        .foregroundStyle(Bauhaus.ink)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Bauhaus.yellow))
                        .bauhausBorder(width: 2, cornerRadius: 19)
                }
                .buttonStyle(.plain)

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundStyle(player.hasNext ? Bauhaus.ink : Bauhaus.inkSecondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!player.hasNext)

                // 循环模式
                Button {
                    player.cycleRepeatMode()
                } label: {
                    Image(systemName: player.repeatMode.icon)
                        .font(.body)
                        .foregroundStyle(player.repeatMode == .off ? Bauhaus.inkSecondary : Bauhaus.blue)
                }
                .buttonStyle(.plain)
                .help(player.repeatMode.rawValue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Bauhaus.surface)
    }

    // MARK: - Helpers
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
