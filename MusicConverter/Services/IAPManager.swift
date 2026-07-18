import SwiftUI
import IOKit
import CryptoKit

/// 本地激活码管理器 - 一次付款绑定一台电脑
@MainActor
class ActivationManager: ObservableObject {

    static let shared = ActivationManager()

    @Published var isPro: Bool = false
    @Published var machineCode: String = ""
    @Published var activationCode: String = ""
    @Published var activationResult: String?
    @Published var activationSuccess: Bool = false

    /// 用于生成激活码的密钥（开发者持有）
    private static let secretKey = "MusicConverter2026Pro"

    private init() {
        machineCode = Self.getHardwareUUID()
        isPro = UserDefaults.standard.bool(forKey: "isPro")
        activationCode = UserDefaults.standard.string(forKey: "activationCode") ?? ""
    }

    // MARK: - 获取本机硬件 UUID

    /// 获取稳定的硬件 UUID 作为机器码
    static func getHardwareUUID() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return "UNKNOWN" }
        defer { IOObjectRelease(platformExpert) }

        guard let serialNumber = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return "UNKNOWN"
        }
        return serialNumber
    }

    // MARK: - 生成激活码（开发者用）

    /// 根据机器码生成对应的激活码
    static func generateActivationCode(for machineCode: String) -> String {
        let raw = "\(machineCode)-\(secretKey)"
        let hash = Self.sha256(raw)
        // 取前 24 位，格式化为 XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
        let chars = Array(hash.prefix(24).uppercased())
        return stride(from: 0, to: chars.count, by: 4).map {
            String(chars[$0..<min($0 + 4, chars.count)])
        }.joined(separator: "-")
    }

    // MARK: - 验证激活码

    func activate(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            activationResult = "请输入激活码"
            return
        }

        let expected = Self.generateActivationCode(for: machineCode)
        if trimmed.uppercased() == expected {
            isPro = true
            activationCode = trimmed
            activationSuccess = true
            activationResult = nil
            UserDefaults.standard.set(true, forKey: "isPro")
            UserDefaults.standard.set(trimmed, forKey: "activationCode")
        } else {
            activationResult = "激活码无效，请确认是否为本机生成的激活码"
        }
    }

    // MARK: - SHA256

    private static func sha256(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
