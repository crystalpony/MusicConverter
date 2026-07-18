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
        var records = library.records
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
            Divider()
            
            if library.records.isEmpty {
                emptyState
            } else if viewMode == .list {
                listView
            } else {
                groupedView
            }

            // 底部播放条
            if player.currentRecordID != nil {
                Divider()
                playerBar
            }
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
        VStack(spacing: 6) {
            // 正在播放信息
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.currentRecord?.displayTitle ?? "")
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let artist = player.currentRecord?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            // 进度条
            HStack(spacing: 8) {
                Text(formatDuration(isSeeking ? seekValue : player.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

                Text(formatDuration(player.duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .leading)
            }

            // 控制按钮
            HStack(spacing: 28) {
                Button {
                    player.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(!player.hasPrevious)
                .foregroundStyle(player.hasPrevious ? .primary : .tertiary)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(!player.hasNext)
                .foregroundStyle(player.hasNext ? .primary : .tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
