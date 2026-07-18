#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""音乐下载 & MP3 转换脚本（yt-dlp + ffmpeg）"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

# 导入共享模块
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from common import which, check_deps

# ── 平台识别 ─────────────────────────────────────────────────────────────────
PLATFORM_PATTERNS = {
    "YouTube":    r"(youtube\.com|youtu\.be)",
    "Bilibili":   r"(bilibili\.com|b23\.tv)",
    "网易云音乐":  r"music\.163\.com",
    "QQ音乐":     r"y\.qq\.com",
    "酷狗音乐":   r"kugou\.com",
    "酷我音乐":   r"kuwo\.cn",
    "SoundCloud": r"soundcloud\.com",
    "Spotify":    r"spotify\.com",
}


def detect_platform(url: str) -> str:
    for platform, pattern in PLATFORM_PATTERNS.items():
        if re.search(pattern, url, re.IGNORECASE):
            return platform
    return "其他平台"


# ── 核心：下载并转换 ─────────────────────────────────────────────────────────
def download_and_convert(
    url: str,
    output_dir: str = "./downloads",
    bitrate: str = "320k",
    cookie_file: str = None,
    proxy: str = None,
) -> dict:
    """下载 URL 对应音频并转为 MP3，返回结果 dict"""
    out = Path(output_dir).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)

    platform = detect_platform(url)

    ytdlp_bin = which("yt-dlp") or "yt-dlp"

    cmd = [
        ytdlp_bin,
        "-x",                        # 仅提取音频
        "--audio-format", "mp3",
        "--audio-quality", bitrate,
        "-o", str(out / "%(title)s.%(ext)s"),
        "--embed-thumbnail",
        "--add-metadata",
        "--restrict-filenames",
        "--no-warnings",
        "--newline",
        "--no-colors",
    ]

    # 平台特殊处理
    if platform == "Bilibili":
        cmd += ["--referer", "https://www.bilibili.com"]

    if cookie_file:
        cp = Path(cookie_file).expanduser().resolve()
        if cp.exists():
            cmd += ["--cookies", str(cp)]

    if proxy:
        cmd += ["--proxy", proxy]

    cmd.append(url)

    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=600
        )
    except FileNotFoundError:
        return {"success": False, "error": "yt-dlp 未安装，请运行: brew install yt-dlp 或 pip install yt-dlp"}
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "下载超时（600s），请检查网络或使用 --proxy"}

    if proc.returncode != 0:
        stderr = (proc.stderr or proc.stdout or "")[-500:]
        return {"success": False, "error": f"yt-dlp 退出码 {proc.returncode}: {stderr.strip()}"}

    # 查找最新生成的 mp3
    mp3s = list(out.glob("*.mp3"))
    if not mp3s:
        return {"success": False, "error": "下载完成但未找到 MP3 文件"}

    latest = max(mp3s, key=lambda f: f.stat().st_mtime)
    size_mb = round(latest.stat().st_size / (1024 * 1024), 2)

    return {
        "success": True,
        "file": str(latest),
        "title": latest.stem,
        "size_mb": size_mb,
        "bitrate": bitrate,
        "platform": platform,
    }


# ── 批量下载 ─────────────────────────────────────────────────────────────────
def batch_download(
    url_file: str,
    output_dir: str = "./downloads",
    bitrate: str = "320k",
    cookie_file: str = None,
    proxy: str = None,
) -> list:
    fp = Path(url_file).expanduser().resolve()
    if not fp.exists():
        return [{"success": False, "error": f"URL 文件不存在: {fp}"}]

    urls = [
        line.strip()
        for line in fp.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]
    if not urls:
        return [{"success": False, "error": "URL 文件为空"}]

    results = []
    for i, url in enumerate(urls, 1):
        print(f"[{i}/{len(urls)}] {url}", flush=True)
        r = download_and_convert(url, output_dir, bitrate, cookie_file, proxy)
        results.append({"url": url, **r})
        status = "✅" if r["success"] else "❌"
        print(f"  {status} {r.get('title') or r.get('error')}", flush=True)

    return results


# ── 本地文件转换 ─────────────────────────────────────────────────────────────
def convert_local(
    input_file: str,
    output_dir: str = None,
    bitrate: str = "320k",
) -> dict:
    inp = Path(input_file).expanduser().resolve()
    if not inp.exists():
        return {"success": False, "error": f"文件不存在: {inp}"}

    out_dir = Path(output_dir or str(inp.parent)).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"{inp.stem}.mp3"

    cmd = [
        "ffmpeg", "-i", str(inp),
        "-vn", "-acodec", "libmp3lame",
        "-ab", bitrate, "-y",
        str(out_file),
    ]

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except FileNotFoundError:
        return {"success": False, "error": "ffmpeg 未安装，请运行: brew install ffmpeg"}

    if res.returncode == 0 and out_file.exists():
        size_mb = round(out_file.stat().st_size / (1024 * 1024), 2)
        return {
            "success": True,
            "file": str(out_file),
            "title": out_file.stem,
            "size_mb": size_mb,
            "bitrate": bitrate,
        }
    else:
        err = (res.stderr or "")[-300:]
        return {"success": False, "error": f"ffmpeg 转换失败: {err}"}


# ── 入口 ─────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="🎵 音乐下载 & MP3 转换工具")
    parser.add_argument("url", nargs="?", help="音频/视频 URL")
    parser.add_argument("-o", "--output", default="./downloads", help="输出目录")
    parser.add_argument("-b", "--bitrate", default="320k",
                        choices=["128k", "192k", "256k", "320k"],
                        help="MP3 比特率（默认 320k）")
    parser.add_argument("--cookie", default=None, help="cookie 文件路径")
    parser.add_argument("--proxy", default=None, help="代理地址")
    parser.add_argument("--batch", default=None, help="批量 URL 文件路径")
    parser.add_argument("--convert", default=None, help="本地音频文件转 MP3")

    args = parser.parse_args()

    # 环境检查
    deps = check_deps("yt-dlp", "ffmpeg")
    if not args.convert and not deps["yt-dlp"]:
        out = {"success": False, "error": "yt-dlp 未安装。请运行: brew install yt-dlp 或 pip install yt-dlp"}
        print(json.dumps(out, ensure_ascii=False, indent=2))
        sys.exit(1)
    if not deps["ffmpeg"]:
        out = {"success": False, "error": "ffmpeg 未安装。请运行: brew install ffmpeg"}
        print(json.dumps(out, ensure_ascii=False, indent=2))
        sys.exit(1)

    # 本地转换
    if args.convert:
        result = convert_local(args.convert, args.output, args.bitrate)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        sys.exit(0 if result["success"] else 1)

    # 批量下载
    if args.batch:
        results = batch_download(args.batch, args.output, args.bitrate,
                                 args.cookie, args.proxy)
        ok = sum(1 for r in results if r.get("success"))
        fail = len(results) - ok
        summary = {
            "total": len(results),
            "success": ok,
            "failed": fail,
            "results": results,
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        sys.exit(0 if fail == 0 else 1)

    # 单链接下载
    if not args.url:
        parser.print_help()
        sys.exit(0)

    result = download_and_convert(
        args.url, args.output, args.bitrate, args.cookie, args.proxy
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()
