# Tunely macOS

SwiftUI 桌面应用。构建检查：

```bash
xcodebuild -project MusicConverter.xcodeproj -scheme MusicConverter -configuration Release -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
```

Pro 购买按钮打开 `https://gettunely.cn/purchase/`，并预填本机识别码。激活码由支付服务器在确认支付宝异步通知后签发；本应用只内置 Ed25519 公钥，离线验证激活码与本机 UUID 的绑定。私钥仅在服务器环境变量 `ACTIVATION_PRIVATE_KEY` 中，不得放入应用或仓库。

推送 `v*` 标签会触发 `.github/workflows/release.yml` 构建 Universal DMG 并上传 GitHub Release。当前流程使用临时签名，尚未配置 Developer ID 签名与苹果公证。
