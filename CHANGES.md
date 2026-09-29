# Mac 客户端改动声明

## 2026-09-29 v2.3.0 网易云歌曲信息请求修复

- 修改范围：`Services/YtDlpService.swift`、`Resources/yt-dlp`、项目 README。
- 原因：macOS 系统代理将网易云的 HTTP 元数据请求转到本机代理后返回 502；旧内置 yt-dlp 还提示 Python 3.9 兼容性警告。
- 改动：未在 App 中启用代理时，网易云下载明确直连；用户手动配置的代理仍优先。内置 yt-dlp 更新为官方稳定版 2026.08.19。
- 已验证：同一歌曲在系统代理下可复现 502；明确直连后，独立测试版 App 已下载完整 119 秒音频并一键生成 119 秒伴奏，两个任务均显示完成；新版 yt-dlp 没有 Python 3.9 警告。无 Cookie 的命令行请求只返回 30 秒试听，有效的 App 平台 Cookie 可取得完整音源。
- 未验证：其他网易云歌曲的完整音源可用性、不同网络和代理环境。
- 对现有功能的影响：仅改变网易云在 App 代理关闭时的连接方式；其他平台沿用原连接方式。

## 2026-09-29 v2.3.0 下载任务稳定性与伴奏生成

- 修改范围：`Views/DownloadView.swift`、`Views/DownloadStatusView.swift`、`Services/DirectDownloadManager.swift`、`Services/AudioSeparatorService.swift`、`Services/ProcessRunner.swift`、`Services/YtDlpService.swift`、`MusicConverter.xcodeproj/project.pbxproj`、`Resources/uv*`，以及项目 README。
- 原因：链接下载状态随页面重建丢失；子进程输出按数据块解析可能漏掉进度；用户需要下载歌曲后在本机生成伴奏。
- 改动：链接下载状态迁至应用级管理器；状态窗口同时显示链接和歌单任务；按完整输出行解析进度，限制日志刷新；使用 yt-dlp 的最终文件路径；新增“下载并生成伴奏”，首次使用自动安装本机分离组件，保留原曲并另存伴奏。
- 已验证：Mac Universal Release 构建包含 arm64 与 x86_64；本地签名 DMG 已完成校验、挂载、版本号及双架构检查；本地 HTTP 下载过程中切到转换页再返回，进度条仍实时显示 25% 并继续下载，统一状态窗口也显示完成记录；打包的 uv 能自动安装分离环境；测试版 App 对 12 秒合成音频执行一键下载并生成伴奏，原曲与伴奏分别保存，两者均为 12 秒 MP3，伴奏输出约 320 kbps。
- 未验证：真实歌曲的人声分离听感、Intel Mac 上原有功能的实际运行、不同 macOS 版本的实际运行。伴奏功能仅在 Apple 芯片 Mac 的 macOS 14 及以上开放。
- 对现有功能的影响：原下载和歌单下载入口保留；链接任务的会话历史限制为最近 200 条；首次生成伴奏约需 1 GB 本地空间和网络下载。
