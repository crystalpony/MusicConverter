import SwiftUI

/// 设置面板
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("输出设置") {
                HStack {
                    TextField("输出目录", text: $settings.outputDirectory)
                    Button("选择...") {
                        chooseDirectory()
                    }
                }
            }

            Section("音频设置") {
                Picker("默认比特率", selection: $settings.defaultBitrate) {
                    ForEach(AppSettings.bitrateOptions, id: \.self) { rate in
                        Text(rate).tag(rate)
                    }
                }
            }

            Section("网络设置") {
                Toggle("使用代理", isOn: $settings.useProxy)
                if settings.useProxy {
                    TextField("代理地址（如 http://127.0.0.1:7890）", text: $settings.proxyAddress)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Cookie") {
                HStack {
                    TextField("Cookie 文件路径（网易云/QQ音乐需要）", text: $settings.cookieFilePath)
                    Button("选择...") {
                        chooseCookieFile()
                    }
                }
            }

            Section("快捷功能") {
                Toggle("启用菜单栏图标（可拖拽文件快速转换）", isOn: $settings.menuBarEnabled)
            }

            Section("Pro 版本") {
                if settings.isPro {
                    Label("已解锁 Pro", systemImage: "crown.fill")
                        .foregroundStyle(.yellow)
                } else {
                    Button("升级到 Pro") {
                        NotificationCenter.default.post(name: .showProPurchase, object: nil)
                    }
                }
            }

            Section("工具状态") {
                let status = ToolManager.shared.status()
                ForEach(status.sorted(by: { $0.key < $1.key }), id: \.key) { name, available in
                    HStack {
                        Text(name)
                        Spacer()
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(available ? .green : .red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 400)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url.path
        }
    }

    private func chooseCookieFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            settings.cookieFilePath = url.path
        }
    }
}
