#!/bin/bash
set -euo pipefail

# ============================================================
# install_app.sh — TranslateBar 构建安装清理脚本
# ============================================================
#
# 功能：
#   1. Release 构建
#   2. 安装到 ~/Applications/TranslateBar.app
#   3. 清理 DerivedData 和临时构建产物中的重复 TranslateBar.app
#   4. 重新注册 LaunchServices，避免 Spotlight/Launchpad 保留旧索引
#
# 用法：
#   ./scripts/install_app.sh
#
# 前置条件：
#   - Xcode 已安装
#   - 从项目根目录运行
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/Applications"
INSTALL_PATH="$INSTALL_DIR/TranslateBar.app"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/TranslateBar.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---- 步骤 1: 终止运行中的 TranslateBar ----
log_info "正在检查运行中的 TranslateBar..."
if pgrep -x "TranslateBar" > /dev/null; then
    log_info "发现运行中的 TranslateBar，正在终止..."
    pkill -x "TranslateBar" || true
    sleep 1
fi

# ---- 步骤 2: Release 构建 ----
log_info "开始 Release 构建..."
cd "$PROJECT_ROOT"

xcodebuild \
    -project TranslateBar.xcodeproj \
    -scheme TranslateBar \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -quiet \
    2>&1 | tail -5

if [ ! -d "$APP_BUNDLE" ]; then
    log_error "构建失败：未找到产物 $APP_BUNDLE"
    exit 1
fi

log_info "构建成功：$APP_BUNDLE"

# ---- 步骤 3: 安装到 ~/Applications ----
log_info "正在安装到 $INSTALL_PATH..."

mkdir -p "$INSTALL_DIR"

# 移除旧版本
if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
fi

# 拷贝新版本
cp -R "$APP_BUNDLE" "$INSTALL_PATH"

log_info "安装完成：$INSTALL_PATH"

# ---- 步骤 4: 卸载并清理重复产物 ----
log_info "正在清理重复的 TranslateBar.app 产物..."

# 先用 lsregister -u 卸载所有非正式路径的 LaunchServices 注册
if [ -x "$LSREGISTER" ]; then
    # 卸载本地 .build 构建产物
    if [ -d "$APP_BUNDLE" ]; then
        "$LSREGISTER" -u "$APP_BUNDLE" 2>/dev/null || true
        log_info "已卸载 LaunchServices 注册：$APP_BUNDLE"
    fi

    # 卸载默认 DerivedData 中的所有 TranslateBar.app
    DEFAULT_DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
    if [ -d "$DEFAULT_DERIVED" ]; then
        while IFS= read -r -d '' dup; do
            "$LSREGISTER" -u "$dup" 2>/dev/null || true
            log_info "已卸载 LaunchServices 注册：$dup"
        done < <(find "$DEFAULT_DERIVED" -name 'TranslateBar.app' -type d -print0 2>/dev/null || true)
    fi

    # 卸载已不存在但仍在 LaunchServices 中的残留条目
    "$LSREGISTER" -kill -r -domain user 2>/dev/null || true
fi

# 再删除文件
if [ -d "$DEFAULT_DERIVED" ]; then
    while IFS= read -r -d '' dup; do
        log_info "清理 DerivedData 副本：$dup"
        rm -rf "$dup"
    done < <(find "$DEFAULT_DERIVED" -name 'TranslateBar.app' -type d -print0 2>/dev/null || true)
fi

# 清理项目根目录下的 TranslateBar.app（旧版可能残留）
if [ -d "$PROJECT_ROOT/TranslateBar.app" ]; then
    log_info "清理项目根目录副本：$PROJECT_ROOT/TranslateBar.app"
    rm -rf "$PROJECT_ROOT/TranslateBar.app"
fi

# ---- 步骤 5: 清理临时构建目录（保留 .app 已安装） ----
log_info "清理临时构建目录..."
rm -rf "$BUILD_DIR"

# ---- 步骤 6: 重新注册正式 App ----
log_info "正在重新注册 LaunchServices..."
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -R -f "$INSTALL_PATH" 2>/dev/null || true
    log_info "LaunchServices 注册完成"
else
    log_warn "未找到 lsregister，跳过 LaunchServices 注册"
fi

# ---- 步骤 7: 验证 ----
log_info "验证安装结果..."

VERIFY_OK=true

# 检查产物存在
if [ ! -d "$INSTALL_PATH" ]; then
    log_error "验证失败：$INSTALL_PATH 不存在"
    VERIFY_OK=false
fi

# 检查签名
if ! codesign --verify --deep --strict --verbose=2 "$INSTALL_PATH" &>/dev/null; then
    log_error "验证失败：签名验证未通过"
    codesign --verify --deep --strict --verbose=2 "$INSTALL_PATH" 2>&1 | tail -3
    VERIFY_OK=false
fi

# 检查 DerivedData 清理
DERIVED_DUPES=$(find "$DEFAULT_DERIVED" -name 'TranslateBar.app' -type d 2>/dev/null | wc -l | tr -d ' ')
if [ "$DERIVED_DUPES" -ne 0 ]; then
    log_warn "DerivedData 中仍有 $DERIVED_DUPES 个 TranslateBar.app 副本"
else
    log_info "DerivedData 清理完成，无重复产物"
fi

# 检查项目根目录无残留
if [ -d "$PROJECT_ROOT/TranslateBar.app" ]; then
    log_warn "项目根目录仍有 TranslateBar.app 残留"
else
    log_info "项目根目录无残留"
fi

if [ "$VERIFY_OK" = true ]; then
    log_info "============================================"
    log_info "安装成功！"
    log_info "产物路径：$INSTALL_PATH"
    log_info "启动 App：  open $INSTALL_PATH"
    log_info "============================================"
else
    log_error "安装过程中出现错误，请查看上述日志。"
    exit 1
fi
