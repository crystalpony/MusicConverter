import Foundation

/// 支持的音乐平台类型
enum MusicPlatform: String, CaseIterable, Codable, Hashable {
    case netease = "网易云音乐"
    case qq = "QQ音乐"

    /// 平台登录页 URL
    var loginURL: String {
        switch self {
        case .netease: return "https://music.163.com/#/login"
        case .qq:      return "https://y.qq.com/portal/profile.html#sub=other&tab=login"
        }
    }

    /// 平台首页（用于检测登录状态）
    var homeURL: String {
        switch self {
        case .netease: return "https://music.163.com"
        case .qq:      return "https://y.qq.com"
        }
    }

    /// 平台图标（SF Symbol）
    var icon: String {
        switch self {
        case .netease: return "music.note.house"
        case .qq:      return "music.quarternote.3"
        }
    }

    /// 歌曲播放页 URL 模板
    func songURL(id: String) -> String {
        switch self {
        case .netease: return "https://music.163.com/song?id=\(id)"
        case .qq:      return "https://y.qq.com/n/ryqq/songDetail/\(id)"
        }
    }

    /// Cookie 关键域名
    var cookieDomain: String {
        switch self {
        case .netease: return ".music.163.com"
        case .qq:      return ".qq.com"
        }
    }

    /// 判断登录所需的关键 Cookie 字段
    var loginCookieKeys: [String] {
        switch self {
        case .netease: return ["MUSIC_U", "__csrf"]
        case .qq:      return ["uin", "qm_keyst"]
        }
    }
}

/// 平台账号登录状态
enum AccountStatus: String, Codable {
    case loggedOut = "未登录"
    case loggedIn = "已登录"
    case expired = "已过期"
    case loggingIn = "登录中"
}

/// 歌单模型
struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let coverURL: String
    let trackCount: Int
    let creatorName: String
    let platform: MusicPlatform

    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id && lhs.platform == rhs.platform
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(platform)
    }
}

/// 歌曲模型
struct PlatformSong: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval  // 秒
    let coverURL: String
    let platform: MusicPlatform

    /// 格式化时长 mm:ss
    var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// 构造下载用 URL
    var downloadURL: String {
        platform.songURL(id: id)
    }

    static func == (lhs: PlatformSong, rhs: PlatformSong) -> Bool {
        lhs.id == rhs.id && lhs.platform == rhs.platform
    }
}

/// 平台账号模型
struct MusicPlatformAccount: Codable {
    var platform: MusicPlatform
    var status: AccountStatus = .loggedOut
    var uid: String = ""
    var nickname: String = ""
    var avatarURL: String = ""
    var loginTime: Date?

    /// 是否已登录
    var isLoggedIn: Bool {
        status == .loggedIn
    }
}
