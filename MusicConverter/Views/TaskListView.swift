import SwiftUI

/// 通用任务列表组件：显示任务进度和状态
struct TaskListView<TaskItem: Identifiable>: View where TaskItem: TaskListDisplayable {
    let tasks: [TaskItem]
    let title: String

    var body: some View {
        if !tasks.isEmpty {
            GroupBox(title) {
                List {
                    ForEach(tasks) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.displayTitle)
                                    .font(.body)
                                    .lineLimit(1)
                                if !task.displaySubtitle.isEmpty {
                                    Text(task.displaySubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if task.isInProgress {
                                ProgressBar(progress: task.progress)
                                    .frame(width: 120)
                            } else {
                                Text(task.statusLabel)
                                    .font(.caption)
                                    .foregroundStyle(task.statusColor)
                            }
                        }
                    }
                }
                .frame(minHeight: 150)
            }
        }
    }
}

/// 任务列表项协议
protocol TaskListDisplayable: Identifiable {
    var displayTitle: String { get }
    var displaySubtitle: String { get }
    var isInProgress: Bool { get }
    var progress: Double { get }
    var statusLabel: String { get }
    var statusColor: Color { get }
}

// DownloadTask 适配
extension DownloadTask: TaskListDisplayable {
    var displayTitle: String { title.isEmpty ? url : title }
    var displaySubtitle: String { platform }
    var isInProgress: Bool { status == .downloading || status == .converting }
    var statusLabel: String { status.rawValue }
    var statusColor: Color {
        switch status {
        case .pending: return .secondary
        case .downloading, .converting: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .orange
        }
    }
}

// ConvertTask 适配
extension ConvertTask: TaskListDisplayable {
    var displayTitle: String { title.isEmpty ? inputPath : title }
    var displaySubtitle: String { "" }
    var isInProgress: Bool { status == .converting }
    var statusLabel: String { status.rawValue }
    var statusColor: Color {
        switch status {
        case .pending: return .secondary
        case .converting: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// NCMTask 适配
extension NCMTask: TaskListDisplayable {
    var displayTitle: String { title.isEmpty ? inputPath : title }
    var displaySubtitle: String { format.uppercased() }
    var isInProgress: Bool { status == .decrypting }
    var progress: Double { status == .decrypting ? 0.5 : (status == .completed ? 1.0 : 0.0) }
    var statusLabel: String { status.rawValue }
    var statusColor: Color {
        switch status {
        case .pending: return .secondary
        case .decrypting: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
