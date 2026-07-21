import SwiftUI

/// 首次启动引导页 - 3 步极简引导
struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int = 0
    @State private var showLoginSheet: Bool = false
    @State private var animateIn: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                platformPage.tag(1)
                readyPage.tag(2)
            }
            .tabViewStyle(.automatic)

            // 底部导航
            HStack(spacing: 16) {
                // 页面指示器
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentPage < 2 {
                    Button("跳过") {
                        completeOnboarding()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)

                    Button("下一步") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("开始使用") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 420)
        .sheet(isPresented: $showLoginSheet) {
            PlatformLoginView(platform: MusicPlatformService.shared.selectedPlatform)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
    }

    // MARK: - Page 1: 欢迎

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue.gradient)
                .scaleEffect(animateIn ? 1.0 : 0.6)
                .opacity(animateIn ? 1.0 : 0)

            Text("欢迎使用 Tunely")
                .font(.title)
                .fontWeight(.bold)

            Text("你的全能音乐管家")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                onboardingFeature(icon: "arrow.down.circle.fill", color: .blue, text: "下载 1000+ 平台音乐")
                onboardingFeature(icon: "music.note.list", color: .green, text: "一键备份歌单到本地")
                onboardingFeature(icon: "arrow.triangle.2.circlepath", color: .orange, text: "无损格式转换")
                onboardingFeature(icon: "lock.open", color: .purple, text: "NCM 加密解密")
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }

    // MARK: - Page 2: 选择平台

    private var platformPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("连接你的音乐账号")
                .font(.title2)
                .fontWeight(.bold)

            Text("扫码登录，即可浏览和下载你的歌单")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                ForEach(MusicPlatform.allCases, id: \.self) { platform in
                    Button {
                        MusicPlatformService.shared.selectedPlatform = platform
                        showLoginSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: platform.icon)
                                .font(.title2)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(platform.rawValue)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("扫码登录，读取歌单")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let account = MusicPlatformService.shared.accounts[platform],
                               account.isLoggedIn {
                                Label("已登录", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 48)

            Text("登录信息仅存储在本机，不会上传到任何服务器")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    // MARK: - Page 3: 准备就绪

    private var readyPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green.gradient)

            Text("一切就绪！")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: "1", text: "在「歌单」Tab 选择平台并登录")
                stepRow(number: "2", text: "浏览你的歌单，勾选想下载的歌曲")
                stepRow(number: "3", text: "点击「批量下载」，坐等音乐入库")
            }
            .padding(.horizontal, 48)

            // 免费版提示
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.pink)
                Text("免费版每次可下载 \(settings.effectiveConvertLimit) 首，升级 Pro 无限制")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.pink.opacity(0.08))
            .cornerRadius(8)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func onboardingFeature(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.body)
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(.body)
        }
    }

    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        dismiss()
    }
}

/// 下载完成庆祝动效视图
struct DownloadCelebrationView: View {
    let completedCount: Int
    let savedMinutes: Int
    let onDismiss: () -> Void

    @State private var showNotes: Bool = false
    @State private var scaleIn: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // 音符飘散动画
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor.opacity(showNotes ? 0 : 0.8))
                        .offset(
                            x: showNotes ? CGFloat([-60, -30, 0, 30, 60, 45][i]) : 0,
                            y: showNotes ? CGFloat(-80 - i * 15) : 0
                        )
                        .animation(
                            .easeOut(duration: 1.2).delay(Double(i) * 0.1),
                            value: showNotes
                        )
                }

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .scaleEffect(scaleIn ? 1.0 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: scaleIn)
            }
            .frame(height: 100)

            Text("已为你保存 \(completedCount) 首歌曲")
                .font(.title3)
                .fontWeight(.semibold)

            if savedMinutes > 0 {
                Text("本次为你节省了约 \(savedMinutes) 分钟手动操作时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("太棒了") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .onAppear {
            showNotes = true
            scaleIn = true
        }
    }
}

/// 成就徽章视图
struct AchievementBadge: View {
    let icon: String
    let title: String
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isUnlocked ? .yellow : .secondary.opacity(0.4))

            Text(title)
                .font(.caption2)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
        }
        .frame(width: 72)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isUnlocked ? Color.yellow.opacity(0.1) : Color.clear)
        )
    }
}

/// 成就系统
enum Achievement: String, CaseIterable {
    case firstDownload = "初次下载"
    case firstPlaylist = "歌单备份"
    case hundredSongs = "百首达成"
    case fiveHundredSongs = "音乐收藏家"

    var icon: String {
        switch self {
        case .firstDownload: return "music.note"
        case .firstPlaylist: return "music.note.list"
        case .hundredSongs: return "100.square"
        case .fiveHundredSongs: return "crown.fill"
        }
    }

    func isUnlocked(totalDownloads: Int) -> Bool {
        switch self {
        case .firstDownload: return totalDownloads >= 1
        case .firstPlaylist: return totalDownloads >= 10
        case .hundredSongs: return totalDownloads >= 100
        case .fiveHundredSongs: return totalDownloads >= 500
        }
    }
}
