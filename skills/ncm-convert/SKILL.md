---
name: ncm-convert
version: 1.0.0
description: Decrypt NetEase Cloud Music .ncm files to MP3/FLAC using ncmdump
description_zh: 解密网易云音乐 .ncm 加密文件为 MP3/FLAC 格式，支持单文件和批量目录转换
user-invocable: true
argument-hint: <.ncm 文件路径或目录>
---

# NCM 加密音乐解密 & 转换

## 功能说明

通过 `ncmdump` 解密网易云音乐 `.ncm` 加密文件，还原为原始音频（MP3/FLAC）。

1. **单文件解密**：解密单个 `.ncm` 文件
2. **批量解密**：传入目录，自动解密所有 `.ncm` 文件

## 环境前置条件

```bash
brew install ncmdump    # macOS
# Linux: 从源码编译 https://github.com/AsakuraMizu/ncmdump
```

## 使用方式

### 1. 单文件解密

当用户提供一个 `.ncm` 文件路径时：

```bash
python3 SKILL_DIR/scripts/ncm_convert.py "<文件路径.ncm>" \
  --output "./output"
```

参数说明：
- `<文件路径.ncm>`：NCM 加密文件路径
- `--output`：输出目录，默认与源文件同目录

### 2. 批量解密目录

当用户提供一个目录路径时（自动识别为批量模式）：

```bash
python3 SKILL_DIR/scripts/ncm_convert.py "<目录路径>"
```

或显式指定批量模式：

```bash
python3 SKILL_DIR/scripts/ncm_convert.py --batch "<目录路径>" \
  --output "./output"
```

### 3. 检查依赖

```bash
python3 SKILL_DIR/scripts/ncm_convert.py --check
```

## 输出格式

成功后脚本会输出 JSON：

```json
{
  "success": true,
  "file": "/absolute/path/to/song.mp3",
  "title": "歌曲标题",
  "format": "mp3",
  "size_mb": 8.52
}
```

批量模式输出：

```json
{
  "total": 28,
  "success": 28,
  "failed": 0,
  "results": [...]
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

- `ncmdump` 未安装 → 见"环境前置条件"
- 文件不存在或非 `.ncm` → 检查路径和格式
- 解密超时（120s）

## 注意事项

- `.ncm` 仅通过会员下载获得；解密后格式取决于原始上传格式（MP3/FLAC）
- 本工具仅用于个人已购买音乐的格式转换，请尊重版权
