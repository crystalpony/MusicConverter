import SwiftUI

/// 主窗口 - TabView 容器
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedTab: Int = 0
    @State private var showTutorial: Bool = false
    @AppStorage("hasShownTutorial") private var hasShownTutorial: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DownloadView()
                .tabItem {
                    Label("下载", systemImage: "arrow.down.circle")
                }
                .tag(0)

            ConvertView()
                .tabItem {
                    Label("转换", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(1)

            NCMView()
                .tabItem {
                    Label("NCM 解密", systemImage: "lock.open")
                }
                .tag(2)

            MusicLibraryView()
                .tabItem {
                    Label("音乐库", systemImage: "music.note.list")
                }
                .tag(3)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showTutorial = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("使用教程")
            }
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView(isPresented: $showTutorial)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showMusicLibrary)) { _ in
            selectedTab = 3
        }
        .onAppear {
            if !hasShownTutorial {
                showTutorial = true
                hasShownTutorial = true
            }
        }
    }
}
