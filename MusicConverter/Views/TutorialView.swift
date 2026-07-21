import SwiftUI

/// 使用教程 - 纯文字说明 Sheet
struct TutorialView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("使用教程")
                    .font(.title2.bold())
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // 内容
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    tutorialSection(
                        icon: "arrow.down.circle.fill",
                        color: Bauhaus.blue,
                        title: "下载",
                        items: [
                            "1. 复制音视频链接或视频直链（YouTube、Bilibili、网易云，或 .mp4 直链）",
                            "2. 粘贴到输入框，点击「下载」",
                            "3. 选择格式：仅音频 MP3 / 原画视频 / 最佳画质 MP4",
                            "4. 完成后自动保存到输出目录，并收录到音乐库/影音",
                            "❗ 暂不支持 BT / 磁力链接（magnet、.torrent）",
                        ]
                    )

                    tutorialSection(
                        icon: "arrow.triangle.2.circlepath.fill",
                        color: Bauhaus.yellow,
                        title: "转换（音频格式 + NCM 解密）",
                        items: [
                            "1. 将音频或 .ncm 文件/文件夹拖入虚线框，或点击选择",
                            "2. 音频（MP3/WAV/FLAC/AAC/OGG/M4A…）自动转为 MP3",
                            "3. 网易云 .ncm 自动解密还原，支持拖入整个文件夹批量",
                            "4. 结果自动收录到音乐库",
                        ]
                    )

                    tutorialSection(
                        icon: "film.fill",
                        color: Bauhaus.red,
                        title: "影音",
                        items: [
                            "• 下载的视频自动进入「影音」页",
                            "• 点击即以复古电视框小窗播放",
                            "• 支持播放/暂停、进度拖拽",
                        ]
                    )

                    tutorialSection(
                        icon: "music.note.list",
                        color: Bauhaus.blue,
                        title: "音乐库",
                        items: [
                            "• 所有转换/下载完成的音乐自动收录到音乐库",
                            "• 支持搜索、排序、按艺人/专辑分组浏览",
                            "• 点击播放按钮可直接试听（含音量/随机/循环）",
                        ]
                    )

                    tutorialSection(
                        icon: "menubar.rectangle",
                        color: Bauhaus.inkSecondary,
                        title: "菜单栏快捷操作",
                        items: [
                            "• 在「设置」中开启菜单栏图标",
                            "• 直接拖拽音频文件到菜单栏图标即可快速转换",
                        ]
                    )

                    tutorialSection(
                        icon: "key.fill",
                        color: Bauhaus.yellow,
                        title: "Cookie 与提示",
                        items: [
                            "• B 站会员/受限视频、或遇到 412：在设置开启「从浏览器读取 Cookie」，选已登录 B 站的浏览器",
                            "• 网易云/QQ音乐可在「歌单」页登录，或在设置配置 Cookie 文件",
                            "• 输出目录与比特率在设置 (⌘,) 中修改",
                            "• 部分平台（Spotify / Apple Music）有 DRM 保护，无法下载",
                        ]
                    )
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 560)
    }

    @ViewBuilder
    private func tutorialSection(icon: String, color: Color, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
            }

            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
