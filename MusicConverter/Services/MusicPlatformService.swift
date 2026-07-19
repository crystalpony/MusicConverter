import Foundation
import WebKit
import Security

/// 统一音乐平台服务：登录、Cookie 管理、歌单/歌曲 API
@MainActor
class MusicPlatformService: ObservableObject {

    static let shared = MusicPlatformService()

    // MARK: - Published State

    @Published var accounts: [MusicPlatform: MusicPlatformAccount] = [:]
    @Published var playlists: [Playlist] = []
    @Published var currentSongs: [PlatformSong] = []
    @Published var isLoadingPlaylists: Bool = false
    @Published var isLoadingSongs: Bool = false
    @Published var errorMessage: String?

    /// 当前选中的平台
    @Published var selectedPlatform: MusicPlatform = .netease

    // MARK: - Keychain Keys

    private static let keychainService = "com.musicconverter.platform-cookies"

    // MARK: - Init

    private init() {
        // 初始化各平台账号
        for platform in MusicPlatform.allCases {
            accounts[platform] = MusicPlatformAccount(platform: platform)
        }
        // 尝试从 Keychain 恢复登录状态
        restoreLoginState()
    }

    // MARK: - Cookie 管理

    /// 从 WKWebView 的 CookieStore 捕获指定平台的 Cookie
    func captureCookies(from webView: WKWebView, for platform: MusicPlatform) async -> Bool {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await cookieStore.allCookies()

        // 筛选平台域名下的 Cookie
        let platformCookies = cookies.filter {
            $0.domain.contains(platform.cookieDomain.replacingOccurrences(of: ".", with: ""))
            || $0.domain == platform.cookieDomain
        }

        guard !platformCookies.isEmpty else { return false }

        // 检查是否包含登录关键 Cookie
        let cookieNames = Set(platformCookies.map { $0.name })
        let hasLoginCookies = platform.loginCookieKeys.allSatisfy { cookieNames.contains($0) }

        guard hasLoginCookies else { return false }

        // 序列化 Cookie 并存入 Keychain
        let cookieData = serializeCookies(platformCookies)
        saveCookiesToKeychain(data: cookieData, for: platform)

        // 保存 Netscape 格式 Cookie 文件（供 yt-dlp 使用）
        saveNetscapeCookieFile(platformCookies, for: platform)

        // 更新账号状态
        accounts[platform]?.status = .loggedIn
        accounts[platform]?.loginTime = Date()

        // 获取用户信息
        await fetchUserInfo(for: platform)

        return true
    }

    /// 获取平台对应的 Cookie 文件路径（供 yt-dlp 使用）
    func cookieFilePath(for platform: MusicPlatform) -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MusicConverter/Cookies", isDirectory: true)
        let file = dir.appendingPathComponent("\(platform.rawValue)_cookies.txt")
        return FileManager.default.fileExists(atPath: file.path) ? file.path : nil
    }

    /// 获取所有已登录平台的合并 Cookie 文件路径
    func mergedCookieFilePath() -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MusicConverter/Cookies", isDirectory: true)
        let mergedFile = dir.appendingPathComponent("merged_cookies.txt")

        var content = "# Netscape HTTP Cookie File\n"
        var hasContent = false

        for platform in MusicPlatform.allCases {
            if let path = cookieFilePath(for: platform),
               let data = try? String(contentsOfFile: path, encoding: .utf8) {
                content += data + "\n"
                hasContent = true
            }
        }

        guard hasContent else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? content.write(to: mergedFile, atomically: true, encoding: .utf8)
        return mergedFile.path
    }

    /// 登出指定平台
    func logout(platform: MusicPlatform) {
        accounts[platform]?.status = .loggedOut
        accounts[platform]?.uid = ""
        accounts[platform]?.nickname = ""
        accounts[platform]?.avatarURL = ""
        accounts[platform]?.loginTime = nil
        deleteCookiesFromKeychain(for: platform)

        // 删除 Cookie 文件
        if let path = cookieFilePath(for: platform) {
            try? FileManager.default.removeItem(atPath: path)
        }

        if selectedPlatform == platform {
            playlists = []
            currentSongs = []
        }
    }

    // MARK: - 网易云 API

    /// 获取网易云用户歌单
    func fetchNeteasePlaylists(uid: String) async throws -> [Playlist] {
        let urlString = "https://music.163.com/api/user/playlist?uid=\(uid)&limit=100&offset=0"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidInput("无效的歌单请求 URL")
        }

        var request = URLRequest(url: url)
        request.setValue(cookieHeaderString(for: .netease), forHTTPHeaderField: "Cookie")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playlistArray = json["playlist"] as? [[String: Any]] else {
            throw ServiceError.invalidInput("解析歌单数据失败")
        }

        return playlistArray.map { item in
            Playlist(
                id: "\(item["id"] as? Int ?? 0)",
                name: item["name"] as? String ?? "未知歌单",
                coverURL: item["coverImgUrl"] as? String ?? "",
                trackCount: item["trackCount"] as? Int ?? 0,
                creatorName: (item["creator"] as? [String: Any])?["nickname"] as? String ?? "",
                platform: .netease
            )
        }
    }

    /// 获取网易云歌单内歌曲
    func fetchNeteaseSongs(playlistId: String) async throws -> [PlatformSong] {
        let urlString = "https://music.163.com/api/v6/playlist/detail?id=\(playlistId)&n=1000"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidInput("无效的歌单详情 URL")
        }

        var request = URLRequest(url: url)
        request.setValue(cookieHeaderString(for: .netease), forHTTPHeaderField: "Cookie")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playlistData = json["playlist"] as? [String: Any],
              let trackIds = playlistData["trackIds"] as? [[String: Any]] else {
            throw ServiceError.invalidInput("解析歌单歌曲失败")
        }

        // 批量获取歌曲详情（每次最多 500 首）
        let ids = trackIds.compactMap { $0["id"] as? Int }
        var songs: [PlatformSong] = []

        for chunk in ids.chunked(into: 500) {
            let chunkSongs = try await fetchNeteaseSongDetails(ids: chunk)
            songs.append(contentsOf: chunkSongs)
        }

        return songs
    }

    /// 批量获取网易云歌曲详情
    private func fetchNeteaseSongDetails(ids: [Int]) async throws -> [PlatformSong] {
        let urlString = "https://music.163.com/api/v3/song/detail"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidInput("无效的歌曲详情 URL")
        }

        let cParam = ids.map { "{\"id\":\($0)}" }.joined(separator: ",")
        let body = "c=[\(cParam)]"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(cookieHeaderString(for: .netease), forHTTPHeaderField: "Cookie")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songArray = json["songs"] as? [[String: Any]] else {
            throw ServiceError.invalidInput("解析歌曲详情失败")
        }

        return songArray.map { item in
            let artists = (item["ar"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: "/") ?? "未知艺人"
            let album = (item["al"] as? [String: Any])?["name"] as? String ?? "未知专辑"
            let coverURL = (item["al"] as? [String: Any])?["picUrl"] as? String ?? ""
            let durationMs = item["dt"] as? Double ?? 0

            return PlatformSong(
                id: "\(item["id"] as? Int ?? 0)",
                title: item["name"] as? String ?? "未知歌曲",
                artist: artists,
                album: album,
                duration: durationMs / 1000.0,
                coverURL: coverURL,
                platform: .netease
            )
        }
    }

    // MARK: - QQ 音乐 API

    /// 获取 QQ 音乐用户歌单
    func fetchQQPlaylists(uin: String) async throws -> [Playlist] {
        // 注意：URL 中已含 percent-encoding，不可再次 encode
        let urlString = "https://u.y.qq.com/cgi-bin/musicu.fcg?data=%7B%22req%22%3A%7B%22module%22%3A%22music.web_diss_info_svr%22%2C%22method%22%3A%22get_diss_info_list%22%2C%22param%22%3A%7B%22host_uin%22%3A\(uin)%2C%22sin%22%3A0%2C%22size%22%3A100%2C%22dir_id%22%3A0%7D%7D%7D"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidInput("无效的 QQ 歌单请求 URL")
        }

        var request = URLRequest(url: url)
        request.setValue(cookieHeaderString(for: .qq), forHTTPHeaderField: "Cookie")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let req = json["req"] as? [String: Any],
              let reqData = req["data"] as? [String: Any],
              let list = reqData["list"] as? [[String: Any]] else {
            throw ServiceError.invalidInput("解析 QQ 歌单数据失败")
        }

        return list.map { item in
            Playlist(
                id: "\(item["dissid"] as? Int ?? 0)",
                name: item["dissname"] as? String ?? "未知歌单",
                coverURL: item["imgurl"] as? String ?? "",
                trackCount: item["listennum"] as? Int ?? 0,
                creatorName: (item["creator"] as? [String: Any])?["name"] as? String ?? "",
                platform: .qq
            )
        }
    }

    /// 获取 QQ 音乐歌单内歌曲
    func fetchQQSongs(playlistId: String) async throws -> [PlatformSong] {
        // 注意：URL 中已含 percent-encoding，不可再次 encode
        let urlString = "https://u.y.qq.com/cgi-bin/musicu.fcg?data=%7B%22req%22%3A%7B%22module%22%3A%22music.musichallSong.PlaylistSongListServer%22%2C%22method%22%3A%22GetPlaylistSongList%22%2C%22param%22%3A%7B%22disstid%22%3A\(playlistId)%2C%22begin%22%3A0%2C%22num%22%3A1000%2C%22order%22%3A0%7D%7D%7D"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidInput("无效的 QQ 歌曲请求 URL")
        }

        var request = URLRequest(url: url)
        request.setValue(cookieHeaderString(for: .qq), forHTTPHeaderField: "Cookie")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let req = json["req"] as? [String: Any],
              let reqData = req["data"] as? [String: Any],
              let songList = reqData["songList"] as? [[String: Any]] else {
            throw ServiceError.invalidInput("解析 QQ 歌曲数据失败")
        }

        return songList.compactMap { item in
            guard let songInfo = item["songInfo"] as? [String: Any] else { return nil }
            let singerArray = songInfo["singer"] as? [[String: Any]] ?? []
            let artists = singerArray.compactMap { $0["name"] as? String }.joined(separator: "/")
            let albumInfo = songInfo["album"] as? [String: Any] ?? [:]
            let timePublic = songInfo["timePublic"] as? String ?? ""
            let durationSec = parseQQDuration(timePublic)

            return PlatformSong(
                id: songInfo["mid"] as? String ?? "",
                title: songInfo["name"] as? String ?? "未知歌曲",
                artist: artists.isEmpty ? "未知艺人" : artists,
                album: albumInfo["name"] as? String ?? "未知专辑",
                duration: durationSec,
                coverURL: "https://y.qq.com/music/photo_new/T002R300x300M000\(albumInfo["mid"] as? String ?? "").jpg",
                platform: .qq
            )
        }
    }

    // MARK: - 统一入口

    /// 加载当前平台的歌单
    func loadPlaylists() async {
        guard let account = accounts[selectedPlatform], account.isLoggedIn else {
            errorMessage = "请先登录\(selectedPlatform.rawValue)"
            return
        }

        isLoadingPlaylists = true
        errorMessage = nil

        do {
            switch selectedPlatform {
            case .netease:
                playlists = try await fetchNeteasePlaylists(uid: account.uid)
            case .qq:
                playlists = try await fetchQQPlaylists(uin: account.uid)
            }
        } catch {
            errorMessage = "加载歌单失败：\(error.localizedDescription)"
            playlists = []
        }

        isLoadingPlaylists = false
    }

    /// 加载指定歌单的歌曲
    func loadSongs(for playlist: Playlist) async {
        isLoadingSongs = true
        errorMessage = nil
        currentSongs = []

        do {
            switch playlist.platform {
            case .netease:
                currentSongs = try await fetchNeteaseSongs(playlistId: playlist.id)
            case .qq:
                currentSongs = try await fetchQQSongs(playlistId: playlist.id)
            }
        } catch {
            errorMessage = "加载歌曲失败：\(error.localizedDescription)"
        }

        isLoadingSongs = false
    }

    // MARK: - 用户信息

    /// 获取用户信息（昵称、UID、头像）
    private func fetchUserInfo(for platform: MusicPlatform) async {
        switch platform {
        case .netease:
            await fetchNeteaseUserInfo()
        case .qq:
            await fetchQQUserInfo()
        }
    }

    private func fetchNeteaseUserInfo() async {
        guard let url = URL(string: "https://music.163.com/api/nuser/account/get") else { return }
        var request = URLRequest(url: url)
        request.setValue(cookieHeaderString(for: .netease), forHTTPHeaderField: "Cookie")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any] else { return }

        accounts[.netease]?.uid = "\(profile["userId"] as? Int ?? 0)"
        accounts[.netease]?.nickname = profile["nickname"] as? String ?? "网易云用户"
        accounts[.netease]?.avatarURL = profile["avatarUrl"] as? String ?? ""
    }

    private func fetchQQUserInfo() async {
        // QQ 音乐用户信息从 Cookie 中的 uin 获取
        if let cookies = loadCookiesFromKeychain(for: .qq) {
            let cookieArray = deserializeCookies(cookies)
            if let uinCookie = cookieArray.first(where: { $0.name == "uin" }) {
                accounts[.qq]?.uid = uinCookie.value.replacingOccurrences(of: "o", with: "")
            }
            if cookieArray.first(where: { $0.name == "qqmusic_key" }) != nil {
                accounts[.qq]?.nickname = "QQ音乐用户"
            }
        }
        if accounts[.qq]?.nickname.isEmpty == true {
            accounts[.qq]?.nickname = "QQ音乐用户"
        }
    }

    // MARK: - Cookie 序列化

    private func serializeCookies(_ cookies: [HTTPCookie]) -> Data {
        // 将 HTTPCookiePropertyKey 转为 String key 以确保归档/解档一致性
        let dicts: [[String: Any]] = cookies.compactMap { cookie in
            guard let props = cookie.properties else { return nil }
            return props.reduce(into: [String: Any]()) { result, pair in
                result[pair.key.rawValue] = pair.value
            }
        }
        return (try? NSKeyedArchiver.archivedData(withRootObject: dicts, requiringSecureCoding: false)) ?? Data()
    }

    private func deserializeCookies(_ data: Data) -> [HTTPCookie] {
        guard let dicts = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSArray.self, NSDictionary.self, NSString.self, NSNumber.self, NSDate.self],
            from: data
        ) as? [[String: Any]] else {
            return []
        }
        return dicts.compactMap { dict in
            // 将 [String: Any] 转换为 [HTTPCookiePropertyKey: Any]
            let props = dict.reduce(into: [HTTPCookiePropertyKey: Any]()) { result, pair in
                result[HTTPCookiePropertyKey(pair.key)] = pair.value
            }
            return HTTPCookie(properties: props)
        }
    }

    /// 构造 Cookie 请求头字符串
    private func cookieHeaderString(for platform: MusicPlatform) -> String {
        guard let data = loadCookiesFromKeychain(for: platform) else { return "" }
        let cookies = deserializeCookies(data)
        return cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    /// 保存 Netscape 格式 Cookie 文件（yt-dlp 兼容）
    private func saveNetscapeCookieFile(_ cookies: [HTTPCookie], for platform: MusicPlatform) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MusicConverter/Cookies", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(platform.rawValue)_cookies.txt")

        var content = "# Netscape HTTP Cookie File\n# This file was generated by MusicConverter\n\n"
        for cookie in cookies {
            let domain = cookie.domain
            let flag = domain.hasPrefix(".") ? "TRUE" : "FALSE"
            let path = cookie.path.isEmpty ? "/" : cookie.path
            let secure = cookie.isSecure ? "TRUE" : "FALSE"
            let expiry = cookie.expiresDate.map { Int($0.timeIntervalSince1970) } ?? 0
            content += "\(domain)\t\(flag)\t\(path)\t\(secure)\t\(expiry)\t\(cookie.name)\t\(cookie.value)\n"
        }

        try? content.write(to: file, atomically: true, encoding: .utf8)
    }

    // MARK: - Keychain 操作

    private func saveCookiesToKeychain(data: Data, for platform: MusicPlatform) {
        let key = "cookies_\(platform.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
        ]

        // 先删除旧数据
        SecItemDelete(query as CFDictionary)

        // 添加新数据
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadCookiesFromKeychain(for platform: MusicPlatform) -> Data? {
        let key = "cookies_\(platform.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteCookiesFromKeychain(for platform: MusicPlatform) {
        let key = "cookies_\(platform.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// 恢复登录状态
    private func restoreLoginState() {
        for platform in MusicPlatform.allCases {
            if let data = loadCookiesFromKeychain(for: platform) {
                let cookies = deserializeCookies(data)
                let cookieNames = Set(cookies.map { $0.name })
                let hasLogin = platform.loginCookieKeys.allSatisfy { cookieNames.contains($0) }
                if hasLogin {
                    accounts[platform]?.status = .loggedIn
                    // 异步刷新用户信息
                    Task {
                        await fetchUserInfo(for: platform)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func parseQQDuration(_ timeStr: String) -> TimeInterval {
        // 格式: "03:45" 或 "4:05"
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
              let mins = Double(parts[0]),
              let secs = Double(parts[1]) else { return 0 }
        return mins * 60 + secs
    }
}

// MARK: - Array Chunk Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
