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

echo "[INFO] 更新根目录 TranslateBar.app..."
cp -r "$APP_BUNDLE" "$PROJECT_ROOT/TranslateBar.app"
echo "[INFO] 启动：$APP_BUNDLE"
open "$APP_BUNDLE"
echo "[INFO] 完成"
