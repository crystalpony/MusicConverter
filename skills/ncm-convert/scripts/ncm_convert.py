#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""NCM 加密音乐解密 & 转换工具（依赖 ncmdump）"""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import List

# 导入共享模块
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from common import which, check_deps


# ── 单文件解密 ───────────────────────────────────────────────────────────────
def decrypt_ncm(
    input_file: str,
    output_dir: str = None,
) -> dict:
    """解密单个 .ncm 文件，返回结果 dict"""
    inp = Path(input_file).expanduser().resolve()
    if not inp.exists():
        return {"success": False, "error": f"文件不存在: {inp}"}

    if inp.suffix.lower() != ".ncm":
        return {"success": False, "error": f"不是 .ncm 文件: {inp.name}"}

    out_dir = Path(output_dir).expanduser().resolve() if output_dir else inp.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    ncmdump_bin = which("ncmdump") or "ncmdump"
    cmd = [ncmdump_bin, str(inp)]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120, cwd=str(out_dir))
    except FileNotFoundError:
        return {"success": False, "error": "ncmdump 未安装，请运行: brew install ncmdump"}
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "解密超时（120s）"}

    if proc.returncode != 0:
        stderr = (proc.stderr or proc.stdout or "")[-500:]
        return {"success": False, "error": f"ncmdump 退出码 {proc.returncode}: {stderr.strip()}"}

    # 查找解密后的文件（ncmdump 输出到同目录，文件名相同但后缀变为 mp3/flac）
    decrypted = list(out_dir.glob(f"{inp.stem}.*"))
    decrypted = [f for f in decrypted if f.suffix.lower() in (".mp3", ".flac", ".ogg", ".m4a", ".wav")]

    if not decrypted:
        return {"success": False, "error": "解密完成但未找到输出文件"}

    latest = max(decrypted, key=lambda f: f.stat().st_mtime)
    size_mb = round(latest.stat().st_size / (1024 * 1024), 2)

    return {
        "success": True,
        "file": str(latest),
        "title": inp.stem,
        "format": latest.suffix.lstrip("."),
        "size_mb": size_mb,
    }


# ── 批量解密目录 ─────────────────────────────────────────────────────────────
def batch_decrypt(
    input_dir: str,
    output_dir: str = None,
) -> list:
    """批量解密目录下所有 .ncm 文件"""
    src = Path(input_dir).expanduser().resolve()
    if not src.is_dir():
        return [{"success": False, "error": f"目录不存在: {src}"}]

    ncm_files = sorted(src.glob("*.ncm"))
    if not ncm_files:
        return [{"success": False, "error": f"目录下未找到 .ncm 文件: {src}"}]

    results = []
    for i, ncm in enumerate(ncm_files, 1):
        print(f"[{i}/{len(ncm_files)}] {ncm.name}", flush=True)
        r = decrypt_ncm(str(ncm), output_dir)
        results.append({"source": ncm.name, **r})
        status = "✅" if r["success"] else "❌"
        print(f"  {status} {r.get('title') or r.get('error')}", flush=True)

    return results


# ── 入口 ─────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="🔓 NCM 加密音乐解密 & 转换工具")
    parser.add_argument("input", nargs="?", help=".ncm 文件路径 或 包含 .ncm 文件的目录")
    parser.add_argument("-o", "--output", default=None, help="输出目录（默认与源文件同目录）")
    parser.add_argument("--batch", action="store_true", help="批量模式：解密目录下所有 .ncm 文件")
    parser.add_argument("--check", action="store_true", help="仅检查依赖是否安装")

    args = parser.parse_args()

    # 环境检查
    deps = check_deps("ncmdump", "ffmpeg")

    if args.check:
        print(json.dumps(deps, ensure_ascii=False, indent=2))
        sys.exit(0 if deps["ncmdump"] else 1)

    if not deps["ncmdump"]:
        out = {"success": False, "error": "ncmdump 未安装。请运行: brew install ncmdump"}
        print(json.dumps(out, ensure_ascii=False, indent=2))
        sys.exit(1)

    # 批量模式（显式 --batch 或传入目录自动识别）
    if args.batch:
        if not args.input:
            parser.error("批量模式需要指定目录路径")

    if args.input:
        inp = Path(args.input).expanduser().resolve()
        if args.batch or inp.is_dir():
            results = batch_decrypt(str(inp), args.output)
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

    if not args.input:
        parser.print_help()
        sys.exit(0)

    result = decrypt_ncm(args.input, args.output)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()
