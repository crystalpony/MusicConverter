import SwiftUI
import AVKit
import AppKit

/// 影音库视图 - 展示已下载的视频并用复古电视框小窗播放
struct VideoLibraryView: View {
    @ObservedObject var library = MusicLibraryStore.shared
    @ObservedObject var videoPlayer = VideoPlayerService.shared
    @EnvironmentObject var settings: AppSettings

    @State private var searchText: String = ""
    @State private var pendingDelete: MusicRecord?

    private var videoRecords: [MusicRecord] {
        var records = library.records.filter { $0.isVideo }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            records = records.filter {
                $0.fileName.lowercased().contains(q) ||
                $0.displayTitle.lowercased().contains(q)
            }
        }
        return records.sorted { $0.convertedAt > $1.convertedAt }
    }

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(Bauhaus.ink).frame(height: 2)

            if videoRecords.isEmpty {
                emptyState
            } else {
                gridView
            }

            // 复古电视框小窗
            if videoPlayer.currentRecordID != nil {
                Rectangle().fill(Bauhaus.ink).frame(height: 2)
                RetroTVFrameView()
                    .padding(16)
            }
        }
        .background(Bauhaus.paper)
        .task {
            // 进入影音库时自动补回输出目录里尚未入库的视频（只增不删）
            await library.importNewFiles(from: settings.resolvedOutputDirectory)
        }
        .confirmationDialog(
            "删除「\(pendingDelete?.displayTitle ?? "")」？",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("彻底删除（含磁盘文件）", role: .destructive) {
                if let record = pendingDelete {
                    if videoPlayer.currentRecordID == record.id { videoPlayer.stop() }
                    library.deleteRecordAndFile(record)
                }
                pendingDelete = nil
            }
            Button("仅从库中移除") {
                if let record = pendingDelete {
                    if videoPlayer.currentRecordID == record.id { videoPlayer.stop() }
                    library.removeRecord(record)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("“彻底删除”会从硬盘删除视频文件，不可恢复；“仅从库中移除”保留文件。")
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("影音库")
                .font(BauhausFont.heading(18))
                .foregroundStyle(Bauhaus.ink)

            Circle().fill(Bauhaus.red).frame(width: 10, height: 10)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Bauhaus.inkSecondary)
                TextField("搜索视频...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Bauhaus.inkSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 3).fill(Bauhaus.surface))
            .bauhausBorder(width: 1.5)
            .frame(maxWidth: 260)

            Spacer()

            Button {
                let path = settings.resolvedOutputDirectory
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            } label: {
                Image(systemName: "folder")
                    .foregroundStyle(Bauhaus.ink)
            }
            .buttonStyle(.plain)
            .help("打开输出目录")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            // 包豪斯几何插画：电视轮廓
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Bauhaus.yellow)
                    .frame(width: 120, height: 90)
                    .bauhausBorder(width: 3, cornerRadius: 8)
                    .bauhausHardShadow()
                Circle().fill(Bauhaus.blue).frame(width: 34, height: 34)
                    .bauhausBorder(width: 3, cornerRadius: 17)
                BauhausTriangle().fill(Bauhaus.red).frame(width: 18, height: 16)
            }
            Text("还没有下载视频")
                .font(BauhausFont.heading(16))
                .foregroundStyle(Bauhaus.ink)
            Text("在「下载」页粘贴视频链接，选择「视频」格式即可入库")
                .font(BauhausFont.body(12))
                .foregroundStyle(Bauhaus.inkSecondary)
            Button {
                NotificationCenter.default.post(name: .showDownload, object: nil)
            } label: {
                Text("去下载视频")
                    .font(BauhausFont.heading(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Bauhaus.red)
                    .bauhausBorder(width: 2)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 网格

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(videoRecords.enumerated()), id: \.element.id) { index, record in
                    videoCard(record, accentIndex: index)
                }
            }
            .padding(16)
        }
    }

    private func videoCard(_ record: MusicRecord, accentIndex: Int) -> some View {
        let isCurrent = videoPlayer.currentRecordID == record.id
        let accent = Bauhaus.accent(accentIndex)

        return VStack(alignment: .leading, spacing: 0) {
            // 缩略图（封面抽帧 / 几何占位）+ 播放键
            ZStack {
                CoverImageView(path: record.coverPath, fallbackIcon: "film", accent: accent)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Bauhaus.ink)
                    .background(Circle().fill(.white).padding(4))
            }
            .frame(height: 110)
            .clipped()
            .overlay(alignment: .topTrailing) {
                Button {
                    pendingDelete = record
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Bauhaus.red)
                        .bauhausBorder(width: 1.5, cornerRadius: 2)
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("删除视频")
            }

            Rectangle().fill(Bauhaus.ink).frame(height: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.displayTitle)
                    .font(BauhausFont.body(13))
                    .fontWeight(.semibold)
                    .foregroundStyle(Bauhaus.ink)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(record.convertedAt, style: .date)
                    .font(BauhausFont.body(10))
                    .foregroundStyle(Bauhaus.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Bauhaus.surface)
        }
        .bauhausBorder(width: isCurrent ? 3 : 2)
        .bauhausHardShadow(x: isCurrent ? 5 : 3, y: isCurrent ? 5 : 3)
        .contentShape(Rectangle())
        .onTapGesture {
            videoPlayer.play(record)
        }
    }
}

// MARK: - 复古 CRT 电视框播放器

/// 复古包豪斯电视框：外壳 + 旋钮 + 视频区 + 品牌条
struct RetroTVFrameView: View {
    @ObservedObject var videoPlayer = VideoPlayerService.shared

    var body: some View {
        HStack(spacing: 0) {
            // 视频屏幕区
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(Color.black)
                    VideoPlayer(player: videoPlayer.player)
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: 420)
                .padding(10)
                .background(Bauhaus.ink)           // 黑色屏框
                .padding(8)
                .background(Bauhaus.yellow)         // 电视外壳
                .bauhausBorder(width: 3)

                // 品牌条
                HStack(spacing: 8) {
                    Text("BAUHAUS TV")
                        .font(BauhausFont.heading(12))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(videoPlayer.currentRecord?.displayTitle ?? "")
                        .font(BauhausFont.body(11))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: 420)
                .background(Bauhaus.red)
                .bauhausBorder(width: 3)
            }

            // 右侧旋钮控制面板
            VStack(spacing: 16) {
                knob(color: Bauhaus.blue)
                knob(color: Bauhaus.red)

                Button {
                    videoPlayer.togglePlayPause()
                } label: {
                    Image(systemName: videoPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(Bauhaus.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Bauhaus.yellow))
                        .bauhausBorder(width: 2, cornerRadius: 20)
                }
                .buttonStyle(.plain)

                Button {
                    videoPlayer.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.body)
                        .foregroundStyle(Bauhaus.ink)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Bauhaus.surface))
                        .bauhausBorder(width: 2, cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16)
        }
        .padding(14)
        .background(Bauhaus.surface)
        .bauhausBorder(width: 3)
        .bauhausHardShadow(x: 5, y: 5)
    }

    private func knob(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 26, height: 26)
            .overlay(
                Rectangle()
                    .fill(Bauhaus.ink)
                    .frame(width: 2, height: 12)
                    .offset(y: -3)
            )
            .bauhausBorder(width: 2, cornerRadius: 13)
    }
}
