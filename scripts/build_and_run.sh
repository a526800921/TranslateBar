#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/TranslateBar.app"

echo "[INFO] 正在退出运行中的 TranslateBar..."
pkill -f TranslateBar 2>/dev/null || true
sleep 1

echo "[INFO] 清理多余 App 注册..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
# 遍历所有已注册的 TranslateBar，只保留 dist/
$LSREGISTER -dump 2>/dev/null | awk '/bundle id:.*TranslateBar/{found=1} found && /path:/{print $2; found=0}' | while read -r p; do
    case "$p" in
        "$PROJECT_ROOT/dist/TranslateBar.app") ;;
        *) echo "  注销: $p"; $LSREGISTER -u "$p" 2>/dev/null || true ;;
    esac
done

# 清理默认 DerivedData 里的过期 Debug App（避免残留注册）
DERIVED_APP="$HOME/Library/Developer/Xcode/DerivedData/TranslateBar-"*"/Build/Products/Debug/TranslateBar.app"
for f in $DERIVED_APP; do
    [ -e "$f" ] && rm -rf "$f" && echo "  清理文件: $f" || true
done

echo "[INFO] 开始 Release 构建..."
xcodebuild \
    -project "$PROJECT_ROOT/TranslateBar.xcodeproj" \
    -scheme TranslateBar \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

echo "[INFO] 更新 dist/TranslateBar.app..."
rm -rf "$PROJECT_ROOT/dist/TranslateBar.app"
cp -r "$APP_BUNDLE" "$PROJECT_ROOT/dist/TranslateBar.app"

echo "[INFO] 启动：$PROJECT_ROOT/dist/TranslateBar.app"
open "$PROJECT_ROOT/dist/TranslateBar.app"
echo "[INFO] 完成"
echo "[INFO] 完成"
