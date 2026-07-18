import SwiftUI

/// Pro 激活页面 - 输入激活码解锁
struct ProPurchaseView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var activation = ActivationManager.shared

    @State private var inputCode: String = ""
    @State private var eggMessage: String?

    /// 隐藏彩蛋暗号：输入后免费赠送一次转换机会
    private static let secretPassphrase = "夏家驹真帅"

    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // 标题区
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)

                Text("升级到 Pro")
                    .font(.title)
                    .fontWeight(.bold)

                Text("一次购买，永久解锁全部功能")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 购买提醒横幅
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    if settings.isPro {
                        Text("你已是 Pro 用户，感谢支持！")
                            .font(.caption)
                            .fontWeight(.medium)
                    } else {
                        Text("购买提醒")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("免费版每次最多转换 \(settings.effectiveConvertLimit) 个文件，升级 Pro 后可无限制批量转换。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(8)
            .padding(.horizontal, 32)

            // 功能列表
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "infinity", text: "无限制批量转换", detail: "免费版每次最多 3 个文件")
                featureRow(icon: "sparkles", text: "优先获取新功能", detail: "未来新功能优先向 Pro 用户开放")
                featureRow(icon: "heart", text: "支持独立开发者", detail: "感谢你的支持，让项目持续更新")
            }
            .padding(.horizontal, 32)

            // 机器码展示
            VStack(alignment: .leading, spacing: 6) {
                Text("本机识别码")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(activation.machineCode)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(activation.machineCode, forType: .string)
                    }
                    .font(.caption)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.horizontal, 32)

            // 激活码输入
            VStack(alignment: .leading, spacing: 6) {
                Text("激活码")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("请输入激活码", text: $inputCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
                Text("提示：在此输入框藏着一个神秘暗号，据说能领取免费转换机会")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            // 错误/成功提示
            if let result = activation.activationResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            // 彩蛋提示
            if let egg = eggMessage {
                Text(egg)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // 激活按钮
            Button {
                let trimmed = inputCode.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == Self.secretPassphrase {
                    // 命中隐藏暗号：免费赠送一次转换机会
                    settings.bonusConversions += 1
                    eggMessage = "彩蛋触发！已赠送 1 次免费转换机会，当前免费额度：\(settings.effectiveConvertLimit) 个文件"
                    activation.activationResult = nil
                    inputCode = ""
                } else {
                    eggMessage = nil
                    activation.activate(code: inputCode)
                }
            } label: {
                Text("激活")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            // 已激活状态
            if activation.isPro {
                Label("已激活 Pro", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Text("付款后将机器码发给开发者获取激活码")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
        .frame(width: 420, height: 640)
        .onChange(of: activation.isPro) { isPro in
            if isPro {
                settings.isPro = true
            }
        }
    }

    private func featureRow(icon: String, text: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.yellow)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.body)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
