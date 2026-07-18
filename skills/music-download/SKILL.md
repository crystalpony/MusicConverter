---
name: music-download
version: 1.0.0
description: Download audio/video from mainstream platforms and convert to MP3 format using yt-dlp
description_zh: 使用 yt-dlp 从主流平台（YouTube、Bilibili、网易云等）下载音视频并转换为 MP3 格式
user-invocable: true
argument-hint: <URL 或本地文件路径>
---

# 音乐下载 & MP3 转换

## 功能说明

通过 `yt-dlp` + `ffmpeg` 实现：

1. **单链接下载**：从 URL 下载并转换为 MP3（支持 1000+ 平台）
2. **批量下载**：从文本文件读取多个 URL
3. **本地转换**：将本地音频（flac/wav/m4a/ogg）转换为 MP3

## 环境前置条件

```bash
brew install yt-dlp ffmpeg    # macOS
# 或：pip install yt-dlp && brew install ffmpeg
```

## 使用方式

### 1. 单链接下载转 MP3

当用户提供一个 URL 时，执行脚本：

```bash
python3 SKILL_DIR/scripts/music_download.py "<URL>" \
  --output "./downloads" \
  --bitrate 320k
```

参数说明：
- `<URL>`：音频/视频页面地址
- `--output`：输出目录，默认 `./downloads`
- `--bitrate`：MP3 比特率，可选 `128k` / `192k` / `256k` / `320k`，默认 `320k`
- `--cookie <path>`：cookie 文件路径（网易云、QQ音乐等需要登录的平台使用）
- `--proxy <addr>`：代理地址，如 `http://127.0.0.1:7890`（访问 YouTube 等境外平台时使用）

### 2. 批量下载

当用户提供一个包含多个 URL 的文本文件（每行一个 URL，`#` 开头为注释）时：

```bash
python3 SKILL_DIR/scripts/music_download.py --batch "<url_list.txt>" \
  --output "./downloads" \
  --bitrate 320k
```

### 3. 本地文件转换 MP3

当用户提供一个本地音频文件路径（非 URL）时：

```bash
python3 SKILL_DIR/scripts/music_download.py --convert "<本地文件路径>" \
  --output "./downloads" \
  --bitrate 320k
```

支持输入格式：flac、wav、m4a、ogg、aac、wma、opus 等 ffmpeg 支持的格式。

## 平台说明

| 平台 | Cookie 必需 | 备注 |
|------|:---:|------|
| 网易云音乐 / QQ音乐 | ✅ | 需导出浏览器 cookie（Netscape 格式） |
| Bilibili | 部分 | 部分视频需要登录态 |
| YouTube / SoundCloud / Spotify | ❌ | 可能需代理（`--proxy`） |

## Cookie 文件获取

登录目标平台 → 安装浏览器扩展「Get cookies.txt LOCALLY」→ 导出 Netscape 格式 → 传入 `--cookie`

## 输出格式

成功后脚本会输出 JSON：

```json
{
  "success": true,
  "file": "/absolute/path/to/song.mp3",
  "title": "歌曲标题",
  "size_mb": 8.52,
  "bitrate": "320k"
}
```

失败时：

```json
{
  "success": false,
  "error": "错误描述"
}
```

## 错误处理

- 工具未安装 → 见"环境前置条件"
- 网络超时 → 使用 `--proxy` 或检查网络
- 需要登录 → 使用 `--cookie` 参数
