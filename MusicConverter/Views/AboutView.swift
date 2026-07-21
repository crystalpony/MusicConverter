import SwiftUI
import AppKit

/// 关于面板 —— 参考 IINA 布局：左侧图标/版本/引擎，右侧简介/版权/链接
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var ytDlpVersion: String = "…"
    @State private var ffmpegVersion: String = "…"

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Tunely"
    }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftColumn
                .frame(width: 240)
                .padding(24)
                .background(Bauhaus.surface)

            Rectangle().fill(Bauhaus.ink).frame(width: 2)

            rightColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .frame(width: 640, height: 380)
        .background(Bauhaus.paper)
        .task { await loadEngineVersions() }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Bauhaus.inkSecondary)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    // MARK: - 左列

    private var leftColumn: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text(appName)
                .font(BauhausFont.title(22))
                .foregroundStyle(Bauhaus.ink)

            Text("版本 \(version) (\(build))")
                .font(BauhausFont.body(12).monospacedDigit())
                .foregroundStyle(Bauhaus.inkSecondary)

            Rectangle().fill(Bauhaus.ink.opacity(0.15)).frame(height: 1).padding(.vertical, 4)

            // 引擎版本
            VStack(spacing: 4) {
                engineRow("yt-dlp", ytDlpVersion)
                engineRow("FFmpeg", ffmpegVersion)
            }

            Spacer()

            BauhausMark(size: 22)
        }
        .frame(maxHeight: .infinity)
    }

    private func engineRow(_ name: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(BauhausFont.body(11))
                .foregroundStyle(Bauhaus.inkSecondary)
            Spacer()
            Text(value)
                .font(BauhausFont.body(11).monospacedDigit())
                .foregroundStyle(Bauhaus.ink)
        }
    }

    // MARK: - 右列

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TUNELY")
                .font(BauhausFont.heading(16))
                .foregroundStyle(Bauhaus.ink)

            Text("面向 macOS 的音视频下载与格式转换工具。支持 1000+ 平台下载、本地格式转换、网易云 NCM 解密，内置复古电视框影音播放。")
                .font(BauhausFont.body(13))
                .foregroundStyle(Bauhaus.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 链接
            VStack(alignment: .leading, spacing: 8) {
                linkRow(icon: "chevron.left.forwardslash.chevron.right", label: "GitHub",
                        url: "https://github.com/crystalpony/MusicConverter")
                linkRow(icon: "cube.box", label: "内置引擎", url: "https://github.com/yt-dlp/yt-dlp")
            }
            .padding(.top, 2)

            Spacer()

            // 版权
            VStack(alignment: .leading, spacing: 4) {
                Text("基于 yt-dlp、FFmpeg、ncmdump 构建。")
                    .font(BauhausFont.body(11))
                    .foregroundStyle(Bauhaus.inkSecondary)
                Text("Copyright © 2026 Tunely. 保留所有权利。")
                    .font(BauhausFont.body(11))
                    .foregroundStyle(Bauhaus.inkSecondary)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func linkRow(icon: String, label: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Bauhaus.blue)
                    .bauhausBorder(width: 1.5, cornerRadius: 2)
                Text(label)
                    .font(BauhausFont.body(13))
                    .foregroundStyle(Bauhaus.blue)
                    .underline()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 引擎版本探测

    private func loadEngineVersions() async {
        ytDlpVersion = await firstLine(tool: "yt-dlp", args: ["--version"]) ?? "未检测到"
        if let ff = await firstLine(tool: "ffmpeg", args: ["-version"]) {
            // 形如 "ffmpeg version 8.1.1 Copyright ..." → 提取版本号
            let parts = ff.split(separator: " ")
            if parts.count >= 3, parts[0] == "ffmpeg", parts[1] == "version" {
                ffmpegVersion = String(parts[2])
            } else {
                ffmpegVersion = ff
            }
        } else {
            ffmpegVersion = "未检测到"
        }
    }

    /// 运行工具并返回首行输出
    private func firstLine(tool: String, args: [String]) async -> String? {
        let runner = ProcessRunner()
        let path = ToolManager.shared.toolPath(tool)
        var captured: String?
        for await line in runner.run(launchPath: path, arguments: args) {
            let clean = line.replacingOccurrences(of: "[stderr] ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                captured = clean
                break
            }
        }
        _ = await runner.waitUntilExit()
        return captured
    }
}
