# Tunely macOS

SwiftUI 桌面应用。构建检查：

```bash
xcodebuild -project MusicConverter.xcodeproj -scheme MusicConverter -configuration Release -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
```

2.3.0 新增链接下载任务跨页面进度与状态查看，以及“下载并生成伴奏（保留原曲）”。伴奏在本机分离人声，原曲和伴奏分别保存；分离效果取决于音源。伴奏功能需要 Apple 芯片 Mac、macOS 14 或更新版本。首次使用需联网安装约 1 GB 的本机组件，后续复用；Intel Mac 仍可使用原有下载、转换等功能。网易云歌曲在应用代理关闭时直连，避免系统代理导致的歌曲信息 502 错误；完整音源仍取决于平台授权和账号权限。

改动范围、验证结果与已知限制见 [CHANGES.md](./CHANGES.md)。

Pro 购买按钮打开 `https://gettunely.cn/purchase/`，并预填本机识别码。激活码由支付服务器在确认支付宝异步通知后签发；本应用只内置 Ed25519 公钥，离线验证激活码与本机 UUID 的绑定。私钥仅在服务器环境变量 `ACTIVATION_PRIVATE_KEY` 中，不得放入应用或仓库。

推送 `v*` 标签会触发 `.github/workflows/release.yml` 构建 Universal DMG 并上传 GitHub Release。当前流程使用临时签名，尚未配置 Developer ID 签名与苹果公证。
