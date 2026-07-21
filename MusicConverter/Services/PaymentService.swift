import Foundation
import CryptoKit

/// 支付订单状态
enum PaymentStatus: String {
    case pending = "待支付"
    case paid = "已支付"
    case expired = "已过期"
    case failed = "失败"
}

/// 支付订单模型
struct PaymentOrder: Identifiable {
    let id: String
    let amount: Double
    let machineCode: String
    var status: PaymentStatus = .pending
    var activationCode: String?
    var payURL: String?       // 支付链接/二维码 URL
    var createdAt: Date = Date()
}

/// 自动发卡支付服务
/// 对接虎皮椒支付 + Cloudflare Worker 发卡
@MainActor
class PaymentService: ObservableObject {

    static let shared = PaymentService()

    @Published var currentOrder: PaymentOrder?
    @Published var isPolling: Bool = false
    @Published var errorMessage: String?

    // MARK: - 配置

    /// 发卡服务 API 地址（Cloudflare Worker）
    private static let apiBaseURL = "https://musicconverter-pay.crystalpony.workers.dev"

    /// Pro 定价（元）
    static let proPrice: Double = 5.9

    /// 原价（用于展示划线价）
    static let originalPrice: Double = 49.9

    /// 轮询间隔（秒）
    private let pollInterval: TimeInterval = 3.0

    /// 最大轮询次数（5分钟超时）
    private let maxPollCount = 100

    private var pollTask: Task<Void, Never>?

    private init() {}

    // MARK: - 创建订单

    /// 创建支付订单
    /// - Parameter machineCode: 用户机器码
    /// - Returns: 支付订单（含支付二维码 URL）
    func createOrder(machineCode: String) async throws -> PaymentOrder {
        errorMessage = nil

        guard let url = URL(string: "\(Self.apiBaseURL)/api/create-order") else {
            throw ServiceError.invalidInput("无效的 API 地址")
        }

        let body: [String: Any] = [
            "machine_code": machineCode,
            "amount": Self.proPrice,
            "product": "MusicConverter Pro",
            "version": "2.0.0"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.invalidInput("创建订单失败，请稍后重试")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let orderId = json["order_id"] as? String,
              let payURL = json["pay_url"] as? String else {
            throw ServiceError.invalidInput("解析订单数据失败")
        }

        let order = PaymentOrder(
            id: orderId,
            amount: Self.proPrice,
            machineCode: machineCode,
            status: .pending,
            payURL: payURL
        )

        currentOrder = order
        return order
    }

    // MARK: - 轮询支付状态

    /// 开始轮询支付状态
    func startPolling(orderId: String, machineCode: String, onSuccess: @escaping (String) -> Void) {
        isPolling = true
        var pollCount = 0

        pollTask = Task {
            while !Task.isCancelled && pollCount < maxPollCount {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                pollCount += 1

                do {
                    let status = try await checkPaymentStatus(orderId: orderId)

                    switch status {
                    case .paid:
                        // 获取激活码
                        if let code = try? await fetchActivationCode(orderId: orderId, machineCode: machineCode) {
                            currentOrder?.status = .paid
                            currentOrder?.activationCode = code
                            isPolling = false
                            onSuccess(code)
                            return
                        }
                    case .expired:
                        currentOrder?.status = .expired
                        errorMessage = "订单已过期，请重新创建"
                        isPolling = false
                        return
                    case .failed:
                        currentOrder?.status = .failed
                        errorMessage = "支付失败，请重试"
                        isPolling = false
                        return
                    case .pending:
                        continue
                    }
                } catch {
                    // 网络错误时继续轮询
                    continue
                }
            }

            // 超时
            if !Task.isCancelled {
                isPolling = false
                errorMessage = "支付超时，请确认是否已完成付款"
            }
        }
    }

    /// 停止轮询
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    // MARK: - API 调用

    /// 查询支付状态
    private func checkPaymentStatus(orderId: String) async throws -> PaymentStatus {
        guard let url = URL(string: "\(Self.apiBaseURL)/api/order-status?order_id=\(orderId)") else {
            throw ServiceError.invalidInput("无效的查询地址")
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusStr = json["status"] as? String else {
            return .pending
        }

        return PaymentStatus(rawValue: statusStr) ?? .pending
    }

    /// 获取激活码
    private func fetchActivationCode(orderId: String, machineCode: String) async throws -> String {
        guard let url = URL(string: "\(Self.apiBaseURL)/api/activate") else {
            throw ServiceError.invalidInput("无效的激活地址")
        }

        let body: [String: Any] = [
            "order_id": orderId,
            "machine_code": machineCode
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.invalidInput("获取激活码失败")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["activation_code"] as? String else {
            throw ServiceError.invalidInput("解析激活码失败")
        }

        return code
    }

    // MARK: - 本地激活码生成（开发者工具）

    /// 本地生成激活码（与 ActivationManager 逻辑一致，供发卡服务参考）
    static func generateActivationCode(for machineCode: String) -> String {
        let secretKey = "MusicConverter2026Pro"
        let raw = "\(machineCode)-\(secretKey)"
        guard let data = raw.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        let hashStr = hash.map { String(format: "%02x", $0) }.joined()
        let chars = Array(hashStr.prefix(24).uppercased())
        return stride(from: 0, to: chars.count, by: 4).map {
            String(chars[$0..<min($0 + 4, chars.count)])
        }.joined(separator: "-")
    }
}
