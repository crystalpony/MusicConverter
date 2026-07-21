#!/bin/bash
# DMG 打包脚本
# 用法: ./scripts/build-dmg.sh [Debug|Release]

set -e

CONFIG="${1:-Release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# 使用 /tmp 避免 iCloud Drive 权限问题
BUILD_DIR="/tmp/MusicConverter_build"
SCHEME_NAME="MusicConverter"
APP_NAME="Tunely"

# 从 git tag 或 MARKETING_VERSION 获取版本号
VERSION=$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null || \
    grep -m1 'MARKETING_VERSION' "$PROJECT_DIR/${SCHEME_NAME}.xcodeproj/project.pbxproj" | sed 's/.*= //;s/;//' | tr -d ' ')
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "=== 构建 $CONFIG (${APP_NAME} ${VERSION}) ==="
cd "$PROJECT_DIR"

# 清理旧构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 清理 iCloud Drive 扩展属性（避免签名失败）
xattr -cr "$PROJECT_DIR" 2>/dev/null || true

# 构建 .app（Universal Binary: arm64 + x86_64）
xcodebuild \
    -project "${SCHEME_NAME}.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIG" \
    -arch arm64 -arch x86_64 \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    build

# 签名（ad-hoc）
APP_PATH=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -type d | head -1)
if [ -n "$APP_PATH" ]; then
    codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || true
fi

# 查找 .app
APP_PATH=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "错误: 未找到 ${APP_NAME}.app 文件"
    exit 1
fi

echo "=== 找到 .app: $APP_PATH ==="

# 创建 DMG 临时目录
DMG_TEMP="$BUILD_DIR/dmg_temp"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# 生成 DMG
DMG_PATH="$BUILD_DIR/$DMG_NAME"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "=== DMG 已生成: $DMG_PATH ==="

# 清理临时目录
rm -rf "$DMG_TEMP"

echo "=== 完成 ==="
echo "DMG 路径: $DMG_PATH"
echo "大小: $(du -h "$DMG_PATH" | cut -f1)"
