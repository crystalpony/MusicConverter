import SwiftUI
import UniformTypeIdentifiers

/// 拖拽文件区域组件（支持拖拽 + 点击选择）
struct FileDropZone: View {
    var prompt: String = "拖拽音频文件到此处，或点击选择"
    var acceptedTypes: [UTType]
    var allowsDirectories: Bool = false
    var onDrop: ([URL]) -> Void

    @State private var isTargeted: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
                )

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)

                Text(prompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 120)
        .contentShape(Rectangle())
        .onTapGesture {
            openPanel()
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleProviders(providers)
            // 有内容即接受本次拖放；实际 URL 通过异步回调收集
            return !providers.isEmpty
        }
    }

    /// 异步收集所有 provider 的文件 URL，全部完成后统一回调
    private func handleProviders(_ providers: [NSItemProvider]) {
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
                onDrop(urls)
            }
        }
    }

    /// 点击弹出系统文件选择面板
    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowsDirectories
        if !acceptedTypes.isEmpty {
            panel.allowedContentTypes = acceptedTypes
        }
        if panel.runModal() == .OK {
            let urls = panel.urls
            if !urls.isEmpty {
                onDrop(urls)
            }
        }
    }
}
