# 计划：install-cleanup-and-login-item

## 背景

`service-settings-and-install` 已把正式 App 安装到 `~/Applications/TranslateBar.app`。但 Xcode 后续 Debug/Release 构建仍可能在 DerivedData 中生成并注册新的 `TranslateBar.app`，导致 Launchpad 搜索出现多个同名 App。

同时，v1 规划中明确把“登录项/开机自启动”留到稳定后再做。本计划把两个后续工作合并处理：规范构建安装清理流程，并加入可控的登录项开关。

## 目标

- 提供一个统一的构建安装脚本，执行 Release build、安装到 `~/Applications/TranslateBar.app`、清理重复构建产物、重新注册正式 App。
- 避免 Launchpad/Spotlight 再次索引 DerivedData 或项目目录中的重复 `TranslateBar.app`。
- 在 App 内增加“登录时启动”开关。
- 使用 macOS 原生登录项能力，让用户可以启用或关闭开机自启动。
- 保持菜单栏 App 行为：`LSUIElement = true`，启动后仍只显示菜单栏图标。

## 非目标

- 不安装到系统级 `/Applications`。
- 不重置 Dock 或 Launchpad 数据库。
- 不清理除 TranslateBar 构建产物以外的 DerivedData 内容。
- 不自动启动本地模型服务。
- 不改变翻译 endpoint/model 配置能力。

## 不变量

- 正式可启动产物只保留在 `~/Applications/TranslateBar.app`。
- 构建脚本不得删除源码、工程文件、文档或非 TranslateBar 构建产物。
- 登录项必须由用户开关控制，不能默认强制启用。
- 登录项状态错误必须以可读信息反馈给用户。
- `LSUIElement = true` 必须保持不变。

## 影响模块或文件

候选文件，实施前仍需确认：

- `scripts/install_app.sh`
- `TranslateBar/TranslatePanelView.swift`
- `TranslateBar/LoginItemService.swift`
- `TranslateBar.xcodeproj/project.pbxproj`
- `docs/PLAN_MAP.md`
- `docs/plans/install-cleanup-and-login-item.md`

## 公开契约变化

安装流程契约：

- 后续正式安装只通过 `scripts/install_app.sh` 执行。
- 脚本输出的唯一正式 App 路径是 `~/Applications/TranslateBar.app`。
- 脚本完成后，`mdfind 'kMDItemFSName == "TranslateBar.app"'` 应只返回 `~/Applications/TranslateBar.app`，除非系统索引延迟。

用户设置契约：

- 新增“登录时启动”开关。
- 开关状态应反映系统登录项状态。
- 用户关闭开关后，TranslateBar 不应在下次登录时自动启动。

## 阶段路线图

| 阶段 | 目标 | 进入条件 | 验证方向 | 状态 |
|---|---|---|---|---|
| Phase 0 | 固定重复项复现和当前安装基线 | `service-settings-and-install` 已完成 | 记录当前 `mdfind`、`find`、正式 App 路径和登录项状态 | 已完成 |
| Phase 1 | 实现构建安装清理脚本 | Phase 0 证据存在 | 脚本执行后只保留 `~/Applications/TranslateBar.app` 可索引 | 已完成 |
| Phase 2 | 实现登录项开关 | Phase 1 通过 | 开关可启用/关闭登录项，错误可诊断 | 已完成 |
| Phase 3 | 完成验证和文档闭环 | Phase 2 通过 | 构建、安装、索引、登录项、治理检查全部通过 | 已完成 |

## 当前阶段

Phase 3：已完成。

### 范围

全部阶段已完成。构建安装脚本、登录项开关和文档验证均已通过。

### Step 0 证据

已完成（2026-06-27）：

- `find ~/Documents/work/TranslateBar ~/Library/Developer/Xcode/DerivedData ~/Applications -name 'TranslateBar.app' -type d`：仅 `~/Applications/TranslateBar.app`，无 DerivedData 或项目根目录残留。
- `mdfind 'kMDItemFSName == “TranslateBar.app”'`：仅 `~/Applications/TranslateBar.app`。
- `plutil -p ~/Applications/TranslateBar.app/Contents/Info.plist`：`LSUIElement = true`，Bundle ID `com.translatebar.app`，Deployment Target `15.0`。
- `codesign --verify --deep --strict --verbose=2 ~/Applications/TranslateBar.app`：通过，满足 Designated Requirement。
- 当前登录项状态：`SMAppService.mainApp.status.rawValue = 3`（`notFound`），未注册登录项，无 LaunchAgent。

### 实施决策记录

- 登录项默认关闭，由用户手动开启。
- 构建脚本使用本地 `.build` 目录存放临时产物，完成后清理。
- 脚本暂不加入 Xcode Run Script phase，作为手动发布脚本使用。
- 登录项实现使用 `SMAppService.mainApp`，与 macOS 原生登录项系统集成。

### Phase 1 证据

- `scripts/install_app.sh` 已创建并可执行。
- 脚本执行：Release 构建成功 → 安装到 `~/Applications/TranslateBar.app` → 清理 DerivedData 中 `TranslateBar-*/Build/Products/Release/TranslateBar.app` → 清理临时 `.build` 目录 → `lsregister -R -f` 重新注册。
- 脚本后验证：
  - `mdfind 'kMDItemFSName == “TranslateBar.app”'` 仅返回 `~/Applications/TranslateBar.app`。
  - `find ~/Library/Developer/Xcode/DerivedData -name 'TranslateBar.app'` 无结果。
  - 项目根目录无 `TranslateBar.app` 残留。
  - `codesign --verify --deep --strict --verbose=2 ~/Applications/TranslateBar.app` 通过。
  - `LSUIElement = true` 保持。

### Phase 2 证据

- `TranslateBar/LoginItemService.swift` 已创建，封装 `SMAppService.mainApp`。
  - `refresh()`：读取状态并更新 `isEnabled` 和 `statusMessage`。
  - `enable()`/`disable()`：调用 `register()`/`unregister()`，错误时提供中文信息。
  - 状态处理：`enabled`、`notRegistered`、`requiresApproval`、`notFound`。
- `TranslatePanelView.swift` 设置区域已加入「登录时启动」Toggle。
  - Toggle 绑定 `loginItemService.isEnabled`。
  - 切换时调用 `enable()` 或 `disable()`。
  - 错误信息通过 `statusMessage` 显示在开关旁。
  - `onAppear` 时刷新登录项状态。
- `TranslateBar.xcodeproj/project.pbxproj` 已更新，加入 `LoginItemService.swift`。
- Release 构建通过，`LoginItemService.swift` 编译链接正常。

### Phase 3 验证

- `scripts/install_app.sh` 从非干净构建状态成功完成。
- 脚本完成后 `~/Applications/TranslateBar.app` 存在且已签名。
- DerivedData 和项目根目录无重复 `TranslateBar.app`。
- `mdfind` 只返回 `~/Applications/TranslateBar.app`。
- `codesign --verify --deep --strict --verbose=2 ~/Applications/TranslateBar.app` 通过。
- App 内「登录时启动」开关可在设置区域操作。
- 开关默认关闭，用户需手动开启。
- 登录项错误时显示中文提示。
- `plan-governance` 通过。

### 完成标准

- 构建安装清理脚本可重复运行。 ✓
- Launchpad 重复项问题有稳定的预防流程。 ✓
- 登录项开关可用且默认不强制启用。 ✓
- 文档记录验证证据，并将计划状态更新为 `已完成`。 ✓

## 开放问题

| 问题 | 建议处理 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|
| 登录项默认是否启用？ | 默认关闭，由用户手动打开。 | 否 | 建议决定 |
| 是否需要清理整个 DerivedData？ | 不需要，只删除 TranslateBar 构建产物中的 `TranslateBar.app`。 | 否 | 建议决定 |
| 是否需要把脚本加入 Xcode Run Script phase？ | 暂不加入，避免每次普通构建都安装和清理；作为手动发布脚本使用。 | 否 | 建议决定 |

## 风险与回滚

- 误删构建产物：脚本必须精确匹配 `TranslateBar.app` 路径，不删除源码和非本项目 DerivedData。
- Spotlight 索引延迟：脚本只能清理文件和注册正式 App，Launchpad 缓存刷新可能存在延迟，需要在验证记录中说明。
- 登录项 API 权限或系统行为差异：失败时显示错误，不影响手动启动 App。
- 回滚方式：删除登录项开关和服务封装，保留 `~/Applications/TranslateBar.app` 手动启动；脚本可不再使用。

## 相关 ADR、迁移、规格或议题

- v1 完成计划：[translatebar-v1](translatebar-v1.md)
- 配置与安装计划：[service-settings-and-install](service-settings-and-install.md)
- 计划索引：[PLAN_MAP.md](../PLAN_MAP.md)

