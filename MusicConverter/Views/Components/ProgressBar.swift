import SwiftUI

/// 进度条组件：显示下载/转换进度
struct ProgressBar: View {
    var progress: Double
    var showPercentage: Bool = true

    var body: some View {
        VStack(spacing: 2) {
            ProgressView(value: min(max(progress, 0), 1.0))
                .progressViewStyle(.linear)

            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
