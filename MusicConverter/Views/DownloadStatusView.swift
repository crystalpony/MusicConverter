import SwiftUI

/// 下载状态窗口：同时监视链接下载和歌单批量下载
struct DownloadStatusView: View {
    @ObservedObject private var batchManager = BatchDownloadManager.shared
    @ObservedObject private var directManager = DirectDownloadManager.shared

    private var allTasks: [DownloadTask] {
        directManager.tasks + batchManager.tasks
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if allTasks.isEmpty {
                emptyState
            } else {
                summaryBar

                Divider()

                taskList
            }
        }
        .frame(minWidth: 420, idealWidth: 480, minHeight: 360, idealHeight: 520)
        .background(Bauhaus.paper)
    }

    // MARK: - 标题栏

    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Bauhaus.blue).frame(width: 14, height: 14)
            Text("下载状态")
                .font(BauhausFont.title(20))
                .foregroundStyle(Bauhaus.ink)
            Spacer()
            if batchManager.isDownloading || directManager.isDownloading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("任务进行中")
                        .font(BauhausFont.body(12))
                        .foregroundStyle(Bauhaus.inkSecondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - 统计条

    private var summaryBar: some View {
        HStack(spacing: 10) {
            countBadge("进行中", count: count(of: .downloading) + count(of: .converting), color: Bauhaus.blue)
            countBadge("等待中", count: count(of: .pending), color: Bauhaus.inkSecondary)
            countBadge("已完成", count: count(of: .completed), color: .green)
            countBadge("失败", count: count(of: .failed), color: Bauhaus.red)
            countBadge("已跳过", count: count(of: .skipped), color: Bauhaus.yellow)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private func count(of status: DownloadTask.TaskStatus) -> Int {
        allTasks.filter { $0.status == status }.count
    }

    private func countBadge(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(color).frame(width: 8, height: 8)
            Text("\(title) \(count)")
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .bauhausBorder(color, width: 1.5, cornerRadius: 2)
    }

    // MARK: - 任务列表

    /// 排序：下载中 > 等待中 > 失败 > 已跳过 > 已完成
    private var sortedTasks: [DownloadTask] {
        allTasks.sorted { rank($0.status) < rank($1.status) }
    }

    private func rank(_ status: DownloadTask.TaskStatus) -> Int {
        switch status {
        case .downloading: return 0
        case .converting:  return 1
        case .pending:     return 2
        case .failed:      return 3
        case .skipped:     return 4
        case .completed:   return 5
        }
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedTasks) { task in
                    taskRow(task)
                    Rectangle()
                        .fill(Bauhaus.ink.opacity(0.1))
                        .frame(height: 1)
                }
            }
        }
    }

    private func taskRow(_ task: DownloadTask) -> some View {
        HStack(spacing: 12) {
            statusIcon(task.status)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title.isEmpty ? task.url : task.title)
                    .font(BauhausFont.body(13))
                    .foregroundStyle(Bauhaus.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !task.artist.isEmpty { Text(task.artist) }
                    if !task.sourcePlaylist.isEmpty {
                        Text("·")
                        Text(task.sourcePlaylist)
                    }
                    if task.status == .failed, let msg = task.errorMessage {
                        Text("·")
                        Text(msg).foregroundStyle(Bauhaus.red)
                    }
                }
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.inkSecondary)
                .lineLimit(1)
            }

            Spacer()

            if task.status == .downloading {
                HStack(spacing: 6) {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                        .tint(Bauhaus.blue)
                        .frame(width: 90)
                    Text("\(Int(task.progress * 100))%")
                        .font(BauhausFont.body(11))
                        .foregroundStyle(Bauhaus.blue)
                        .monospacedDigit()
                }
            } else if task.status == .converting {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("处理中")
                        .font(BauhausFont.body(11))
                        .foregroundStyle(Bauhaus.blue)
                }
            } else {
                Text(task.status.rawValue)
                    .font(BauhausFont.body(11))
                    .foregroundStyle(statusColor(task.status))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(statusColor(task.status).opacity(0.12))
                    .bauhausBorder(statusColor(task.status), width: 1.5, cornerRadius: 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func statusIcon(_ status: DownloadTask.TaskStatus) -> some View {
        switch status {
        case .downloading, .converting:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Bauhaus.blue)
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(Bauhaus.inkSecondary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Bauhaus.red)
        case .skipped:
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(Bauhaus.yellow)
        }
    }

    private func statusColor(_ status: DownloadTask.TaskStatus) -> Color {
        switch status {
        case .pending: return Bauhaus.inkSecondary
        case .downloading, .converting: return Bauhaus.blue
        case .completed: return .green
        case .failed: return Bauhaus.red
        case .skipped: return Bauhaus.yellow
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(Bauhaus.inkSecondary)
            Text("暂无下载任务")
                .font(BauhausFont.heading(14))
                .foregroundStyle(Bauhaus.ink)
            Text("在「下载」或「歌单」页开始任务后，这里会显示进度")
                .font(BauhausFont.body(12))
                .foregroundStyle(Bauhaus.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
