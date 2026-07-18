import SwiftUI

/// URL 输入组件：带粘贴按钮和平台自动识别
struct URLInputField: View {
    @Binding var text: String
    var placeholder: String = "粘贴音视频链接"
    var onSubmit: () -> Void

    private var detectedPlatform: String? {
        guard let url = PlatformDetector.extractURL(from: text) else { return nil }
        let platform = PlatformDetector.detect(url: url)
        return platform == "其他平台" ? nil : platform
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSubmit)

            if let platform = detectedPlatform {
                Text(platform)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundStyle(.blue)
            }

            Button {
                if let string = NSPasteboard.general.string(forType: .string) {
                    text = string
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .help("从剪贴板粘贴")
        }
    }
}
