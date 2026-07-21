import SwiftUI

/// 主窗口 - 左侧包豪斯侧边栏 + 内容区
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedTab: AppTab = .download
    @State private var showTutorial: Bool = false
    @AppStorage("hasShownTutorial") private var hasShownTutorial: Bool = false

    /// 导航项
    enum AppTab: Int, CaseIterable {
        case download, playlist, convert, library, video

        var title: String {
            switch self {
            case .download: return "下载"
            case .playlist: return "歌单"
            case .convert:  return "转换"
            case .library:  return "音乐库"
            case .video:    return "影音"
            }
        }

        var icon: String {
            switch self {
            case .download: return "arrow.down.circle"
            case .playlist: return "music.note.list"
            case .convert:  return "arrow.triangle.2.circlepath"
            case .library:  return "square.stack.3d.up"
            case .video:    return "film"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            // 3pt 分隔线
            Rectangle()
                .fill(Bauhaus.ink)
                .frame(width: 3)

            // 内容区
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Bauhaus.paper)
        }
        .background(Bauhaus.paper)
        .sheet(isPresented: $showTutorial) {
            TutorialView(isPresented: $showTutorial)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showMusicLibrary)) { _ in
            selectedTab = .library
        }
        .onReceive(NotificationCenter.default.publisher(for: .showVideoLibrary)) { _ in
            selectedTab = .video
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDownload)) { _ in
            selectedTab = .download
        }
        .onAppear {
            if !hasShownTutorial {
                showTutorial = true
                hasShownTutorial = true
            }
        }
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部品牌
            HStack(spacing: 10) {
                BauhausMark(size: 22)
                Text("TUNELY")
                    .font(BauhausFont.title(20))
                    .foregroundStyle(Bauhaus.ink)
                    .lineSpacing(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 20)

            // 导航项
            VStack(spacing: 8) {
                ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                    sidebarItem(tab, accent: Bauhaus.accent(index))
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // 底部帮助
            Button {
                showTutorial = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                    Text("使用教程")
                        .font(BauhausFont.body(12))
                }
                .foregroundStyle(Bauhaus.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .frame(width: 200)
        .background(Bauhaus.paper)
    }

    private func sidebarItem(_ tab: AppTab, accent: Color) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? .white : Bauhaus.ink)
                    .frame(width: 22)
                Text(tab.title)
                    .font(BauhausFont.heading(14))
                    .foregroundStyle(isSelected ? .white : Bauhaus.ink)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? accent : Color.clear)
            )
            .bauhausBorder(isSelected ? Bauhaus.ink : Color.clear, width: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .download: DownloadView()
        case .playlist: PlaylistBrowserView()
        case .convert:  ConvertView()
        case .library:  MusicLibraryView()
        case .video:    VideoLibraryView()
        }
    }
}
