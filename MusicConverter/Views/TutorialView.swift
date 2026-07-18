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
                        color: .blue,
                        title: "下载",
                        items: [
                            "1. 复制音视频链接（支持 YouTube、Bilibili、网易云音乐等）",
                            "2. 粘贴到输入框，点击「下载」",
                            "3. 选择想要的音频格式（MP3 / FLAC / WAV 等）",
                            "4. 等待下载完成，文件自动保存到输出目录",
                        ]
                    )

                    tutorialSection(
                        icon: "arrow.triangle.2.circlepath.fill",
                        color: .green,
                        title: "格式转换",
                        items: [
                            "1. 将本地音频文件拖拽到虚线框内，或点击选择文件",
                            "2. 支持 MP3、WAV、FLAC、AAC、OGG、M4A 等主流格式",
                            "3. 自动转换为 MP3 格式，保存到输出目录",
                        ]
                    )

                    tutorialSection(
                        icon: "lock.open.fill",
                        color: .orange,
                        title: "NCM 解密",
                        items: [
                            "1. 将网易云音乐 .ncm 加密文件拖拽到虚线框内",
                            "2. 支持拖入整个文件夹批量解密",
                            "3. 解密后自动转为标准音频格式",
                        ]
                    )

                    tutorialSection(
                        icon: "music.note.list.fill",
                        color: .purple,
                        title: "音乐库",
                        items: [
                            "• 所有转换/下载完成的音乐自动收录到音乐库",
                            "• 支持搜索、排序、按艺人/专辑分组浏览",
                            "• 点击播放按钮可直接试听",
                        ]
                    )

                    tutorialSection(
                        icon: "menubar.rectangle",
                        color: .gray,
                        title: "菜单栏快捷操作",
                        items: [
                            "• 在「设置」中开启菜单栏图标",
                            "• 直接拖拽音频文件到菜单栏图标即可快速转换",
                        ]
                    )

                    tutorialSection(
                        icon: "gearshape.fill",
                        color: .secondary,
                        title: "提示",
                        items: [
                            "• 输出目录和比特率可在「设置」(⌘,) 中修改",
                            "• 网易云/QQ音乐下载需配置 Cookie，详见设置页",
                            "• 部分平台（如 Spotify）有 DRM 保护，无法下载",
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
