import SwiftUI
import UserNotifications

/// 菜单栏弹出窗口视图
struct MenuBarPopoverView: View {
    @ObservedObject var stateManager = MenuBarStateManager.shared
    @EnvironmentObject var settings: AppSettings
    
    private let ffmpegService: FFmpegService
    
    @State private var isTargeted: Bool = false
    
    init(service: FFmpegService) {
        self.ffmpegService = service
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.accentColor)
                Text("快速转换")
                    .font(.headline)
                Spacer()
                if stateManager.isConverting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // 内容区域
            if stateManager.isConverting {
                convertingView
            } else if stateManager.showResults && !stateManager.lastBatchResults.isEmpty {
                resultsView
            } else if stateManager.pendingFiles.isEmpty {
                emptyDropView
            } else {
                pendingFilesView
            }
            
            Divider()
            
            // 底部操作栏
            bottomBar
        }
        .frame(width: 320)
    }
    
    // MARK: - 转换中视图
    
    private var convertingView: some View {
        VStack(spacing: 12) {
            // 总进度条
            let total = stateManager.totalCount
            let done = stateManager.completedCount + stateManager.failedCount
            let progress = total > 0 ? Double(done) / Double(total) : 0
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("转换进度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(done) / \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, 12)
            
            // 当前文件名
            if !stateManager.currentConvertingName.isEmpty {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                    Text(stateManager.currentConvertingName)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            // 已完成列表
            if !stateManager.lastBatchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(stateManager.lastBatchResults) { result in
                            HStack(spacing: 6) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? .green : .red)
                                    .font(.caption2)
                                Text(result.fileName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 100)
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(minHeight: 140)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - 结果视图
    
    private var resultsView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: stateManager.failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(stateManager.failedCount == 0 ? .green : .orange)
                Text(stateManager.failedCount == 0
                     ? "全部转换成功！"
                     : "成功 \(stateManager.completedCount) 个，失败 \(stateManager.failedCount) 个")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 12)
            
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(stateManager.lastBatchResults) { result in
                        HStack(spacing: 6) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .red)
                                .font(.caption2)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.fileName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if let err = result.errorMessage {
                                    Text(err)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 150)
            
            HStack {
                Spacer()
                Button {
                    stateManager.showResults = false
                    stateManager.lastBatchResults = []
                } label: {
                    Text("关闭")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(minHeight: 140)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - 空白拖拽视图
    
    private var emptyDropView: some View {
        VStack(spacing: 8) {
            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                .font(.system(size: 32))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            Text(isTargeted ? "松开以添加文件" : "拖拽音频文件到此处")
                .font(.body)
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            Text("支持 MP3, FLAC, WAV, M4A 等格式")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .padding(8)
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - 待转文件列表
    
    private var pendingFilesView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(stateManager.pendingFiles) { file in
                    fileRow(file)
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .padding(4)
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - 底部操作栏
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            if !stateManager.pendingFiles.isEmpty {
                Button {
                    stateManager.clearAll()
                } label: {
                    Text("清空")
                }
                .disabled(stateManager.isConverting)
                
                Spacer()
                
                Text("\(stateManager.pendingFiles.count) 个文件待转换")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    Task {
                        await stateManager.convertAll(settings: settings, service: ffmpegService)
                        // 转换完成后显示系统通知
                        if stateManager.failedCount == 0 && stateManager.completedCount > 0 {
                            showNotification(title: "转换完成", message: "成功转换 \(stateManager.completedCount) 个文件，已保存到音乐库")
                        } else if stateManager.completedCount > 0 {
                            showNotification(title: "转换完成", message: "成功 \(stateManager.completedCount) 个，失败 \(stateManager.failedCount) 个")
                        }
                    }
                } label: {
                    Label("开始转换", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(stateManager.isConverting)
            } else if stateManager.isConverting {
                Spacer()
                Text("正在转换中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else if stateManager.showResults {
                Spacer()
                Button {
                    // 打开主窗口音乐库
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: .showMusicLibrary, object: nil)
                } label: {
                    Label("查看音乐库", systemImage: "music.note.list")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func fileRow(_ file: MenuBarStateManager.PendingFile) -> some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.accentColor)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !file.fileSize.isEmpty {
                    Text(file.fileSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                stateManager.removeFile(file)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(stateManager.isConverting)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        
        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                stateManager.addFiles(urls)
            }
        }
        
        return !providers.isEmpty
    }
    
    private func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}

// MARK: - 自定义通知名

extension Notification.Name {
    static let showMusicLibrary = Notification.Name("showMusicLibrary")
    static let showProPurchase = Notification.Name("showProPurchase")
    static let showDownload = Notification.Name("showDownload")
    static let showVideoLibrary = Notification.Name("showVideoLibrary")
    static let showAbout = Notification.Name("showAbout")
}
