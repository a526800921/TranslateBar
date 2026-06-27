# 计划：service-settings-and-install

## 背景

`translatebar-v1` 已完成并验收。当前 App 可以从项目目录的 `TranslateBar.app` 启动，但服务 endpoint 和模型路径仍写死在 `TranslationService` 中，且 App 尚未安装到用户应用目录。

本计划把 Phase 3 的第一个候选增强“endpoint/model 配置化”和“加入系统 App 列表”合并处理。

## 目标

- 在 App 内提供服务地址和模型路径配置。
- 保留当前可用默认值，避免升级后破坏既有本地使用。
- 翻译请求使用用户当前配置，而不是编译期硬编码值。
- 配置错误或服务不可用时，错误提示包含当前 endpoint，便于诊断。
- 构建 Release App，并安装到 `~/Applications/TranslateBar.app`，让 Finder/LaunchServices 能识别为用户应用。

## 非目标

- 不做系统级 `/Applications` 安装，避免管理员权限要求。
- 不做登录项或开机自启动。
- 不做服务发现、模型列表选择或自动启动本地服务。
- 不改变只支持中英互译的产品范围。
- 不引入云端翻译服务。

## 不变量

- 默认 endpoint 仍为 `http://127.0.0.1:8787/v1/chat/completions`。
- 默认模型路径仍为 `/Users/jafish/Documents/models/Hy-MT2-7B-4bit`。
- 空 endpoint 或非法 URL 不能发送请求，必须显示可读错误。
- 空模型路径不能发送请求，必须显示可读错误。
- 安装到 `~/Applications` 后仍必须保持 `LSUIElement = true`。

## 影响模块或文件

- `TranslateBar/TranslationService.swift`
- `TranslateBar/TranslatePanelView.swift`
- `TranslateBar/TranslationConfiguration.swift`
- `TranslateBar.xcodeproj/project.pbxproj`
- `docs/PLAN_MAP.md`
- `docs/plans/service-settings-and-install.md`

## 公开契约变化

配置来源从编译期常量扩展为用户默认值：

- endpoint 存储在 `UserDefaults` key `translationEndpoint`。
- model 存储在 `UserDefaults` key `translationModel`。
- 未设置时使用 v1 默认值。

失败行为扩展：

- endpoint 非法时显示“服务地址无效”。
- model 为空时显示“模型路径不能为空”。
- 网络连接失败时提示当前 endpoint，而不是写死端口说明。

## 阶段路线图

| 阶段 | 目标 | 进入条件 | 验证方向 | 状态 |
|---|---|---|---|---|
| Phase 0 | 固定当前硬编码基线和安装现状 | `translatebar-v1` 已完成 | 记录默认 endpoint、model 和项目目录 App 状态 | 已完成 |
| Phase 1 | 实现配置 UI 和请求配置读取 | Phase 0 证据存在 | Debug/Release 构建成功；配置默认值可见；请求读取当前配置 | 已完成 |
| Phase 2 | 安装到用户应用目录 | Phase 1 构建成功 | `~/Applications/TranslateBar.app` 存在，`LSUIElement` 和签名验证通过 | 已完成 |

## 当前状态

Phase 1-2 已完成。App 已支持 endpoint/model 配置，并已安装到 `~/Applications/TranslateBar.app`。

### 已完成范围

在现有翻译面板内增加设置区域，允许修改 endpoint 和模型路径，支持恢复默认值，并让 `TranslationService` 每次请求读取当前配置。

### 已完成实施步骤

1. 新增 `TranslationConfiguration`，集中管理默认值、`UserDefaults` key 和当前配置读取。
2. 修改 `TranslationService`，翻译请求使用当前配置并增加配置错误。
3. 修改 `TranslatePanelView`，增加设置区、配置输入框和恢复默认按钮。
4. 更新 Xcode project，确保新增源文件参与构建。
5. 运行 Debug 和 Release 构建。
6. 复制 Release App 到 `~/Applications/TranslateBar.app`。
7. 验证安装后 App 的 `LSUIElement`、签名和 LaunchServices 注册。

### Step 0 证据

- `translatebar-v1` 已完成，`TranslateBar.app` 可从项目根目录启动。
- 当前硬编码 endpoint：`http://127.0.0.1:8787/v1/chat/completions`。
- 当前硬编码模型路径：`/Users/jafish/Documents/models/Hy-MT2-7B-4bit`。
- 当前 Release App 的 `LSUIElement = true`，签名验证通过。

### 验证

- `xcodebuild -project TranslateBar.xcodeproj -scheme TranslateBar -configuration Debug build` 成功。
- `xcodebuild -project TranslateBar.xcodeproj -scheme TranslateBar -configuration Release build` 成功。
- `~/Applications/TranslateBar.app` 存在。
- `plutil -p ~/Applications/TranslateBar.app/Contents/Info.plist` 显示 `LSUIElement => true`。
- `codesign --verify --deep --strict --verbose=2 ~/Applications/TranslateBar.app` 通过。

### 完成标准

- Phase 1 和 Phase 2 实施步骤完成。
- App 可从 `~/Applications/TranslateBar.app` 启动。
- 配置默认值与 v1 行为一致。
- 配置错误显示可读诊断。
- `docs/PLAN_MAP.md` 和本计划记录完成证据。

完成记录：

- 2026-06-27：Debug 构建通过。
- 2026-06-27：Release 构建通过。
- 2026-06-27：Release App 已复制到项目根目录 `TranslateBar.app` 和 `~/Applications/TranslateBar.app`。
- 2026-06-27：`~/Applications/TranslateBar.app` 的 `LSUIElement = true`。
- 2026-06-27：`codesign --verify --deep --strict --verbose=2 ~/Applications/TranslateBar.app` 通过。
- 2026-06-27：`mdls` 显示安装产物为 `com.apple.application-bundle`，显示名为 `TranslateBar`。

## 测试覆盖率

- 已建立 `TranslateBarTests` XCTest target，共 8 个测试文件、141 个 `func test...` 测试函数；本轮 `xcodebuild test` 实际执行 136 个测试。
- 与本计划相关的覆盖包括 `TranslationConfigurationTests.swift`、`TranslationServiceTests.swift` 和 `TranslatePanelViewTests.swift`。
- 覆盖面包括默认 endpoint/model、`UserDefaults` 配置读取、非法 endpoint、空模型路径、`modelsEndpoint` 推导基础、设置区渲染、错误信息和翻译请求配置构造。
- 安装侧仍以 Release 构建、`~/Applications/TranslateBar.app` 存在、`LSUIElement = true` 和签名验证通过作为测试通过证据。
- 测试通过证据：2026-06-27 运行 `xcodebuild test -project TranslateBar.xcodeproj -scheme TranslateBar -destination 'platform=macOS' -enableCodeCoverage YES`，136 个测试全部通过，0 失败；`xccov` 报告 `TranslateBar.app` 覆盖率为 90.20% (1242/1377)。

## 开放问题

| 问题 | 建议处理 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|
| 是否安装到系统级 `/Applications`？ | 当前只安装到 `~/Applications`，避免 sudo 和权限噪音。 | 否 | 已决定 |
| 是否从 `/v1/models` 自动选择模型？ | 暂不做，后续如需要另建计划。 | 否 | 暂缓 |

## 风险与回滚

- 配置输入错误：请求前校验并显示错误；可通过“恢复默认”回到已验证配置。
- UserDefaults 中已有错误值：设置区显示当前值，用户可恢复默认。
- 安装产物旧版本残留：使用 `ditto` 覆盖 `~/Applications/TranslateBar.app`。
- 回滚方式：恢复 `TranslationService` 的默认配置读取，删除设置 UI，并重新安装上一版 Release App。

## 相关 ADR、迁移、规格或议题

- v1 完成计划：[translatebar-v1](translatebar-v1.md)
- 计划索引：[PLAN_MAP.md](../PLAN_MAP.md)
