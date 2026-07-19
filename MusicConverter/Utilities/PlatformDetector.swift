import Foundation

/// URL 平台识别
enum PlatformDetector {
    /// 支持的平台及识别模式
    private static let patterns: [(String, [String])] = [
        ("YouTube",    ["youtube\\.com", "youtu\\.be"]),
        ("Bilibili",   ["bilibili\\.com", "b23\\.tv"]),
        ("网易云音乐",  ["music\\.163\\.com"]),
        ("QQ音乐",     ["y\\.qq\\.com"]),
        ("酷狗音乐",   ["kugou\\.com"]),
        ("酷我音乐",   ["kuwo\\.cn"]),
        ("SoundCloud", ["soundcloud\\.com"]),
        ("Spotify",    ["spotify\\.com"]),
    ]

    /// yt-dlp 不支持的平台（DRM 等限制）
    private static let unsupportedPatterns: [(String, [String])] = [
        ("Apple Music", ["music\\.apple\\.com"]),
        ("Spotify",    ["spotify\\.com"]),
    ]

    /// 条件支持的平台（有 Cookie 时可下载）
    private static let conditionalPatterns: [(String, [String])] = [
        ("QQ音乐",     ["y\\.qq\\.com"]),
        ("酷狗音乐",   ["kugou\\.com"]),
        ("酷我音乐",   ["kuwo\\.cn"]),
    ]

    static func detect(url: String) -> String {
        for (platform, pats) in patterns {
            for pat in pats {
                if url.range(of: pat, options: .regularExpression) != nil {
                    return platform
                }
            }
        }
        return "其他平台"
    }

    /// 检查 URL 是否为不支持的平台，返回平台名称；nil 表示未命中
    static func unsupportedPlatform(url: String) -> String? {
        for (platform, pats) in unsupportedPatterns {
            for pat in pats {
                if url.range(of: pat, options: .regularExpression) != nil {
                    return platform
                }
            }
        }
        return nil
    }

    /// 检查 URL 是否为条件支持的平台（需要 Cookie）
    /// 返回平台名称；如果已有 Cookie 则返回 nil（表示可正常下载）
    static func conditionalPlatform(url: String, hasCookie: Bool = false) -> String? {
        for (platform, pats) in conditionalPatterns {
            for pat in pats {
                if url.range(of: pat, options: .regularExpression) != nil {
                    // 有 Cookie 时允许下载
                    return hasCookie ? nil : platform
                }
            }
        }
        return nil
    }

    /// 从混合文本中提取首个 http(s) URL
    /// 兼容用户复制粘贴时带中文前缀、方括号、空格等噪声
    /// 例：`【低俗小说】https://www.bilibili.com/bangumi/play/ep779163`
    ///      → `https://www.bilibili.com/bangumi/play/ep779163`
    static func extractURL(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 整段已是合法 URL 则直接返回
        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            return trimmed
        }
        // 用 NSDataDetector 提取首个 http(s) URL
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, range: range),
              let urlRange = Range(match.range, in: trimmed) else {
            return nil
        }
        let candidate = String(trimmed[urlRange])
        return candidate.hasPrefix("http") ? candidate : nil
    }
}
