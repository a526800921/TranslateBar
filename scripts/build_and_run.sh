#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/TranslateBar.app"

echo "[INFO] 正在退出运行中的 TranslateBar..."
pkill -f TranslateBar 2>/dev/null || true
sleep 1

echo "[INFO] 开始 Release 构建..."
xcodebuild \
    -project "$PROJECT_ROOT/TranslateBar.xcodeproj" \
    -scheme TranslateBar \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

echo "[INFO] 更新 dist/TranslateBar.app（git 分发用）..."
rm -rf "$PROJECT_ROOT/dist/TranslateBar.app"
cp -r "$APP_BUNDLE" "$PROJECT_ROOT/dist/TranslateBar.app"
# dist 只用于 git 分发，不注册
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$PROJECT_ROOT/dist/TranslateBar.app" 2>/dev/null

echo "[INFO] 安装到 ~/Applications/TranslateBar.app..."
rm -rf "$HOME/Applications/TranslateBar.app"
cp -r "$APP_BUNDLE" "$HOME/Applications/TranslateBar.app"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$HOME/Applications/TranslateBar.app" 2>/dev/null

echo "[INFO] 启动：$HOME/Applications/TranslateBar.app"
open "$HOME/Applications/TranslateBar.app"
echo "[INFO] 完成"
echo "[INFO] 完成"
