import SwiftUI
import AppKit
import UniformTypeIdentifiers
import UserNotifications

/// 应用代理：控制菜单栏和 Dock 行为
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settings: AppSettings?
    private var ffmpegService: FFmpegService?
    private var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    /// 注入 settings 并监听菜单栏开关
    func configure(settings: AppSettings) {
        self.settings = settings
        self.ffmpegService = FFmpegService()
        updateStatusBar(enabled: settings.menuBarEnabled)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func settingsChanged() {
        guard let settings = settings else { return }
        updateStatusBar(enabled: settings.menuBarEnabled)
    }
    
    private func updateStatusBar(enabled: Bool) {
        if enabled {
            if statusItem == nil {
                createStatusBar()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            eventMonitor?.stop()
            eventMonitor = nil
        }
    }
    
    private func createStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "音乐转换")
            button.image?.size = NSSize(width: 16, height: 16)
        }
        
        // 注册转换完成回调：弹出主窗口并切到音乐库
        MenuBarStateManager.shared.onConvertComplete = { [weak self] in
            Task { @MainActor in
                // 短暂延迟让用户看到结果
                try? await Task.sleep(nanoseconds: 800_000_000)
                // 关闭 popover
                self?.closePopover()
                // 激活主窗口
                NSApp.activate(ignoringOtherApps: true)
                // 通知切到音乐库 Tab
                NotificationCenter.default.post(name: .showMusicLibrary, object: nil)
                // 确保主窗口可见
                if NSApp.windows.isEmpty || NSApp.windows.allSatisfy({ !$0.isVisible }) {
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
        
        // 创建可接受拖拽的自定义视图（覆盖整个按钮区域）
        let dropView = MenuBarDropView(frame: .zero)
        dropView.onDropFiles = { [weak self] urls in
            self?.handleDroppedFiles(urls)
        }
        dropView.onDragEntered = { [weak self] in
            self?.handleDragEntered()
        }
        
        if let button = item.button {
            button.addSubview(dropView)
            dropView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dropView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                dropView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                dropView.topAnchor.constraint(equalTo: button.topAnchor),
                dropView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
            
            // 点击手势
            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(togglePopover))
            button.addGestureRecognizer(clickGesture)
        }
        
        // 创建 Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.behavior = .transient
        popover.animates = true
        
        if let service = ffmpegService {
            popover.contentViewController = NSHostingController(
                rootView: MenuBarPopoverView(service: service)
                    .environmentObject(settings!)
            )
        }
        
        self.popover = popover
        
        // 点击外部关闭
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                self?.closePopover()
            }
        }
        eventMonitor?.start()
        
        statusItem = item
    }
    
    @objc private func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    private func showPopover() {
        guard let popover = popover,
              let button = statusItem?.button,
              !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    
    private func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
        eventMonitor?.start()
    }
    
    /// 拖拽进入时显示弹窗
    private func handleDragEntered() {
        // 显示弹窗
        showPopover()
    }
    
    /// 处理拖放到菜单栏的文件
    private func handleDroppedFiles(_ urls: [URL]) {
        // 添加文件到待转区
        MenuBarStateManager.shared.addFiles(urls)
        
        // 确保弹窗显示
        showPopover()
    }
}

/// 菜单栏拖拽接收视图 - 使用 NSButton 子类确保能接收拖拽
class MenuBarDropView: NSView {
    var onDropFiles: (([URL]) -> Void)?
    var onDragEntered: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragTypes()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragTypes()
    }
    
    private func setupDragTypes() {
        // 注册支持的拖拽类型
        registerForDraggedTypes([
            NSPasteboard.PasteboardType.fileURL,
            NSPasteboard.PasteboardType.URL,
            NSPasteboard.PasteboardType.string
        ])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // 检查是否包含文件
        if hasFiles(in: sender.draggingPasteboard) {
            onDragEntered?()
            return .copy
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return hasFiles(in: sender.draggingPasteboard) ? .copy : []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        // 尝试多种方式获取文件 URL
        var urls: [URL] = []
        
        // 方式1: 直接读取 fileURL
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] {
            urls = fileURLs
        }
        
        // 方式2: 从字符串解析
        if urls.isEmpty, let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String] {
            for str in strings {
                if str.hasPrefix("file://") {
                    if let url = URL(string: str) {
                        urls.append(url)
                    }
                }
            }
        }
        
        if !urls.isEmpty {
            onDropFiles?(urls)
            return true
        }
        return false
    }
    
    private func hasFiles(in pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        
        // 检查是否有文件 URL
        if types.contains(NSPasteboard.PasteboardType.fileURL) {
            return true
        }
        
        // 检查是否有 NSURL
        if types.contains(NSPasteboard.PasteboardType.URL) {
            return true
        }
        
        return false
    }
}

/// 全局事件监听器
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
