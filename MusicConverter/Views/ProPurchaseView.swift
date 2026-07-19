import SwiftUI

/// Pro 激活页面 - 在线购买 + 手动激活码
struct ProPurchaseView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var activation = ActivationManager.shared
    @ObservedObject private var paymentService = PaymentService.shared

    @State private var inputCode: String = ""
    @State private var eggMessage: String?
    @State private var showManualEntry: Bool = false
    @State private var isCreatingOrder: Bool = false
    @State private var showPayQRCode: Bool = false

    /// 隐藏彩蛋暗号：输入后免费赠送一次转换机会
    private static let secretPassphrase = "夏家驹真帅"

    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Spacer()
                Button {
                    paymentService.stopPolling()
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
                        Text("免费版每次最多转换 \(settings.effectiveConvertLimit) 个文件，升级 Pro 后可无限制批量转换、歌单下载。")
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
                featureRow(icon: "music.note.list", text: "歌单批量下载", detail: "一键备份网易云/QQ音乐歌单")
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

            // 在线购买按钮（主 CTA）
            if !settings.isPro {
                Button {
                    startOnlinePurchase()
                } label: {
                    HStack {
                        if isCreatingOrder {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "qrcode")
                        }
                        Text(isCreatingOrder ? "创建订单中..." : "立即扫码购买")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .disabled(isCreatingOrder || paymentService.isPolling)
                .padding(.horizontal, 32)

                // 轮询状态提示
                if paymentService.isPolling {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("等待支付确认...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 错误提示
                if let error = paymentService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 32)
                }

                // 手动激活码入口
                Button(showManualEntry ? "收起手动激活" : "已有激活码？手动输入") {
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

            Text("付款后自动获取激活码，无需等待人工处理")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
        .frame(width: 440, height: 700)
        .onChange(of: activation.isPro) { _, isPro in
            if isPro {
                settings.isPro = true
            }
        }
        .sheet(isPresented: $showPayQRCode) {
            PayQRCodeSheet()
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

    // MARK: - 在线购买

    private func startOnlinePurchase() {
        isCreatingOrder = true
        paymentService.errorMessage = nil

        Task {
            do {
                let order = try await paymentService.createOrder(machineCode: activation.machineCode)
                isCreatingOrder = false
                showPayQRCode = true

                // 开始轮询
                paymentService.startPolling(orderId: order.id, machineCode: activation.machineCode) { code in
                    // 支付成功，自动激活
                    activation.activate(code: code)
                    showPayQRCode = false
                }
            } catch {
                isCreatingOrder = false
                paymentService.errorMessage = error.localizedDescription
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

// MARK: - 支付二维码弹窗

struct PayQRCodeSheet: View {
    @ObservedObject private var paymentService = PaymentService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("扫码支付")
                .font(.title2)
                .fontWeight(.bold)

            Text("¥\(String(format: "%.1f", PaymentService.proPrice))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)

            // 二维码区域
            if let payURL = paymentService.currentOrder?.payURL {
                // 使用系统生成二维码
                QRCodeView(content: payURL)
                    .frame(width: 200, height: 200)

                Text("请使用微信或支付宝扫码")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("生成二维码中...")
                    .frame(width: 200, height: 200)
            }

            // 状态
            if paymentService.isPolling {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("等待支付...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("取消支付") {
                paymentService.stopPolling()
                dismiss()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 320)
    }
}

// MARK: - 二维码生成视图

struct QRCodeView: View {
    let content: String

    var body: some View {
        if let image = generateQRCode(from: content) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .overlay {
                    Image(systemName: "qrcode")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }
        let scale = 200.0 / ciImage.extent.size.width
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
