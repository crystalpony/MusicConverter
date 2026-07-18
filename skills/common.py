#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""共享工具函数：PATH 扩展 & 依赖检查"""

import os
import shutil
from typing import Optional

# 扩展 PATH，覆盖常见的用户安装路径（pip --user 安装位置）
_EXTRA_PATHS = [
    os.path.expanduser("~/Library/Python/3.9/bin"),
    os.path.expanduser("~/Library/Python/3.10/bin"),
    os.path.expanduser("~/Library/Python/3.11/bin"),
    os.path.expanduser("~/Library/Python/3.12/bin"),
    os.path.expanduser("~/.local/bin"),
    "/opt/homebrew/bin",
    "/usr/local/bin",
]
os.environ["PATH"] = os.pathsep.join(_EXTRA_PATHS) + os.pathsep + os.environ.get("PATH", "")


def which(name: str) -> Optional[str]:
    """查找可执行文件"""
    return shutil.which(name)


def check_deps(*names: str) -> dict:
    """检查指定依赖是否安装，返回 {name: bool}"""
    return {name: which(name) is not None for name in names}
