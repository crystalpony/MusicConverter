import SwiftUI

/// Pro 激活页面 - 在线购买 + 手动激活码
struct ProPurchaseView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var activation = ActivationManager.shared

    @State private var inputCode: String = ""
    @State private var eggMessage: String?
    @State private var showManualEntry: Bool = false

    /// 隐藏彩蛋暗号：输入后免费赠送一次转换机会
    private static let secretPassphrase = "夏家驹真帅"

    /// 官网购买页地址（部署后替换为正式域名）
    private static let purchaseURLString = "https://music-converter-web.vercel.app/purchase"

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

            // 价格展示
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("¥\(String(format: "%.1f", PaymentService.proPrice))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("¥\(String(format: "%.1f", PaymentService.originalPrice))")
                    .font(.title3)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Text("限时优惠")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .cornerRadius(4)
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
                        Text("免费版每次最多转换 \(settings.effectiveConvertLimit) 个文件、试下载 \(AppSettings.freeDownloadLimit) 首歌，升级 Pro 后可无限制批量转换、歌单下载。")
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
                featureRow(icon: "music.note.list", text: "歌单批量下载", detail: "免费版试下载 \(AppSettings.freeDownloadLimit) 首，Pro 无限制")
                featureRow(icon: "sparkles", text: "优先获取新功能", detail: "未来新功能优先向 Pro 用户开放")
                featureRow(icon: "heart", text: "支持独立开发者", detail: "感谢你的支持，让项目持续更新")
            }
            .padding(.horizontal, 32)

            // 效率统计（情绪价值）
            if settings.totalDownloadCount > 0 {
                HStack(spacing: 16) {
                    StatBadge(value: "\(settings.totalDownloadCount)", label: "已下载歌曲")
                    StatBadge(value: "\(settings.totalSavedMinutes) 分钟", label: "已节省时间")
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            // 前往官网购买（主 CTA）
            if !settings.isPro {
                Button {
                    openPurchasePage()
                } label: {
                    HStack {
                        Image(systemName: "safari")
                        Text("前往购买页面")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .padding(.horizontal, 32)

                // 购买指引
                VStack(alignment: .leading, spacing: 6) {
                    purchaseStep(number: "1", text: "点击上方按钮打开购买页面，扫码支付")
                    purchaseStep(number: "2", text: "在页面粘贴下方「本机识别码」，生成激活码")
                    purchaseStep(number: "3", text: "复制激活码，回到 App 手动输入激活")
                }
                .padding(.horizontal, 40)

                // 手动激活码入口
                Button(showManualEntry ? "收起激活码输入" : "已获取激活码？点此输入") {
                    withAnimation { showManualEntry.toggle() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if showManualEntry {
                    manualActivationSection
                }
            }

            // 已激活状态
            if activation.isPro {
                Label("已激活 Pro", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            // 机器码（折叠显示）
            DisclosureGroup("本机识别码") {
                HStack {
                    Text(activation.machineCode)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(activation.machineCode, forType: .string)
                    }
                    .font(.caption2)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 32)

            Text("在购买页输入本机识别码即可即时获取激活码")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
        .frame(width: 440, height: 700)
        .onChange(of: activation.isPro) { isPro in
            if isPro {
                settings.isPro = true
            }
        }
    }

    // MARK: - 手动激活码区域

    private var manualActivationSection: some View {
        VStack(spacing: 8) {
            TextField("请输入激活码", text: $inputCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .disableAutocorrection(true)

            Text("提示：在此输入框藏着一个神秘暗号，据说能领取免费转换机会")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let result = activation.activationResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let egg = eggMessage {
                Text(egg)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button("激活") {
                let trimmed = inputCode.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == Self.secretPassphrase {
                    settings.bonusConversions += 1
                    eggMessage = "彩蛋触发！已赠送 1 次免费转换机会"
                    activation.activationResult = nil
                    inputCode = ""
                } else {
                    eggMessage = nil
                    activation.activate(code: inputCode)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.horizontal, 32)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - 前往官网购买

    private func openPurchasePage() {
        let machine = activation.machineCode
        let encoded = machine.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? machine
        let urlString = "\(Self.purchaseURLString)?machine=\(encoded)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func purchaseStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2)
                .fontWeight(.bold)
                .frame(width: 18, height: 18)
                .background(Color.orange.opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
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

// MARK: - 统计徽章

struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.orange)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
    }
}
