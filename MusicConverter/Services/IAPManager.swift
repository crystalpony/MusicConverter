import SwiftUI
import IOKit
import CryptoKit

/// Pro 授权由服务器签发，App 只保存和验证签名。
@MainActor
class ActivationManager: ObservableObject {
    static let shared = ActivationManager()

    @Published var isPro: Bool = false
    @Published var machineCode: String = ""
    @Published var activationCode: String = ""
    @Published var activationResult: String?
    @Published var activationSuccess: Bool = false

    private static let publicKeyBase64 = "7w4E8M500cr5rruQlR/g6Eogn1tP2UzfnHL/z4tHxWw="

    private init() {
        machineCode = Self.getHardwareUUID()
        activationCode = UserDefaults.standard.string(forKey: "activationCode") ?? ""
        isPro = Self.isValid(code: activationCode, machineCode: machineCode)
        UserDefaults.standard.set(isPro, forKey: "isPro")
    }

    static func getHardwareUUID() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return "UNKNOWN" }
        defer { IOObjectRelease(platformExpert) }

        guard let uuid = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return "UNKNOWN"
        }
        return uuid
    }

    private static func isValid(code: String, machineCode: String) -> Bool {
        guard code.hasPrefix("TLY1."),
              let publicKeyData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else {
            return false
        }

        var encodedSignature = String(code.dropFirst(5))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encodedSignature += String(repeating: "=", count: (4 - encodedSignature.count % 4) % 4)
        guard let signature = Data(base64Encoded: encodedSignature), signature.count == 64 else {
            return false
        }

        let message = Data("TunelyPro:v1:\(machineCode.uppercased())".utf8)
        return publicKey.isValidSignature(signature, for: message)
    }

    func activate(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            activationResult = "请输入激活码"
            return
        }

        if Self.isValid(code: trimmed, machineCode: machineCode) {
            isPro = true
            activationCode = trimmed
            activationSuccess = true
            activationResult = nil
            UserDefaults.standard.set(trimmed, forKey: "activationCode")
            UserDefaults.standard.set(true, forKey: "isPro")
        } else {
            activationResult = "激活码无效，请确认是本机购买后获得的完整激活码"
        }
    }
}
