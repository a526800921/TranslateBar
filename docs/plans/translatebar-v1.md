# 计划：translatebar-v1

## 背景

TranslateBar 是一个 macOS 菜单栏翻译 App。第一版应只驻留在菜单栏，点击图标后打开一个紧凑的 SwiftUI 翻译面板，并通过 OpenAI Chat Completions 兼容接口调用本地 Hy-MT2-7B-4bit 服务。

本计划基于 [TranslateBar.fixed.md](../../TranslateBar.fixed.md) 创建；该文件继续作为原始实现草案和代码草图。

## 目标

交付一个第一版可用的本地 macOS App：

- 隐藏 Dock 图标，只作为菜单栏 App 运行；
- 从菜单栏图标打开 `420x520` 翻译弹窗；
- 只支持自动、中译英、英译中三种模式；
- 默认启用自动翻译，并通过开关支持手动模式；
- 调用 `POST http://127.0.0.1:8787/v1/chat/completions`；
- 发送完整模型 id `/Users/jafish/Documents/models/Hy-MT2-7B-4bit`；
- 对服务不可用、HTTP 错误、解析失败、空输出等失败显示可诊断错误；
- 支持复制、清空、`Cmd + Return` 手动翻译和显式退出按钮。

## 非目标

- v1 不支持登录时启动或开机自启动。
- 不负责模型下载、服务启动或服务健康管理。
- 不接入云端翻译服务。
- 不支持中文和英文之外的语言。
- v1 不做流式响应 UI。
- v1 不提供面向分发的 endpoint 或模型路径配置界面。

## 不变量

- 正常使用时 App 不得出现在 Dock。
- 由于 `LSUIElement` App 没有 Dock 退出入口，面板内必须提供退出路径。
- 请求必须使用 `stream: false`，直到后续计划明确加入 Server-Sent Events 解析和增量 UI。
- chat payload 不能使用短模型名 `Hy-MT2-7B-4bit`。
- 除非新的接口探测证明服务契约改变，翻译输出必须来自 `choices[0].message.content`。
- 自动检测模式保持简单：输入中包含任意中文标量则翻译为英文，否则翻译为中文。

## 影响模块或文件

计划创建的 App 文件：

- `TranslateBar.xcodeproj`
- `TranslateBar/TranslateBarApp.swift`
- `TranslateBar/AppDelegate.swift`
- `TranslateBar/TranslatePanelView.swift`
- `TranslateBar/TranslationService.swift`
- `TranslateBar/Models.swift`
- `TranslateBar/Assets.xcassets/`
- `TranslateBar/Info.plist`

治理和来源文档：

- `docs/PLAN_MAP.md`
- `docs/plans/translatebar-v1.md`
- `TranslateBar.fixed.md`

## 公开契约变化

第一版 App 建立以下本地契约：

- 服务基础地址：`http://127.0.0.1:8787`
- Chat 端点：`POST /v1/chat/completions`
- 请求格式：OpenAI Chat Completions 兼容 JSON
- 必填模型值：`/Users/jafish/Documents/models/Hy-MT2-7B-4bit`
- 响应路径：`choices[0].message.content`
- 失败行为：在面板中显示用户可读的诊断信息，而不是静默失败。

如果 endpoint、模型 id 语义、响应路径、支持语言、启动行为或失败行为发生变化，必须先更新本计划和 `docs/PLAN_MAP.md`，再继续实现。

## 阶段路线图

| 阶段 | 目标 | 进入条件 | 验证方向 | 状态 |
|---|---|---|---|---|
| Phase 0 | 建立服务和产品基线 | 本地服务可探测 | 记录 `/v1/models` 和 chat completion 样例证据 | 已完成 |
| Phase 1 | 构建第一版原生 App | Phase 0 证据存在，且没有阻塞性开放问题 | 构建成功，手动验收清单通过 | 已完成 |
| Phase 2 | 稳定打包和本地可用性 | Phase 1 验收通过 | Release 构建可正常打开并保持 v1 行为 | 已完成 |
| Phase 3 | 可选的 v1 后增强 | v1 稳定 | 为登录项、流式输出或 endpoint/model 配置另建计划 | 候选 |

## 当前状态

Phase 0-2 已完成并验收。`translatebar-v1` 第一版已完成；后续只保留 Phase 3 作为候选增强入口。

### 已完成范围

创建 macOS SwiftUI/AppKit 工程，并实现菜单栏 UI、弹窗、翻译服务、类型化请求/响应模型、错误显示、复制、清空、手动翻译快捷键和退出行为。

### 已完成实施步骤

1. 创建 macOS SwiftUI 工程结构。
2. 配置 `LSUIElement = YES`。
3. 使用 `NSStatusBar` 和 `NSPopover` 实现 `TranslateBarApp` 与 `AppDelegate`。
4. 实现类型化请求和响应模型。
5. 实现 `TranslationService`，包含防抖、取消、完整模型 id、非流式请求、响应解析和可读错误。
6. 实现 `TranslatePanelView`，包含自动/手动翻译控制、模式选择、输入编辑器、结果展示、复制、清空和退出。
7. 处理 `docs/PLAN_MAP.md` 中记录的实现期问题，尤其是 `onChange` 兼容性和取消清理。
8. 运行构建和手动验收验证。

### Step 0 证据

基线证据记录在 [TranslateBar.fixed.md](../../TranslateBar.fixed.md)：

- `GET http://127.0.0.1:8787/v1/models` 返回模型 id `/Users/jafish/Documents/models/Hy-MT2-7B-4bit`。
- `POST http://127.0.0.1:8787/v1/chat/completions` 接受 OpenAI Chat Completions 兼容 JSON。
- 将 `hello world` 翻译为中文的请求在 `choices[0].message.content` 返回内容。
- 当前不传 `model` 也能工作，但 App 仍应发送完整本地模型 id，以避免服务配置漂移。

如果实现过程中服务响应变化，必须先暂停并更新这些证据，再改变解析行为。

### 验证

构建验证：

- 对 App target 运行 Xcode 或 `xcodebuild` 构建。

手动验收验证：

- 双击 App 后不出现 Dock 图标。
- 菜单栏显示 TranslateBar 图标。
- 点击图标可以打开和关闭翻译面板。
- 输入 `hello world` 返回中文翻译。
- 输入中文返回英文翻译。
- 自动翻译默认启用。
- 关闭自动翻译后，输入变化不会发送请求。
- 点击 `翻译` 或按 `Cmd + Return` 会发送手动请求。
- UI 只暴露 `自动`、`中译英`、`英译中`。
- 停止本地服务后显示明确诊断错误。
- 复制会把翻译结果写入系统剪贴板。
- 清空会移除输入、结果和错误状态。
- 退出会终止 App 进程。
- v1 不出现开机自启动设置。

### 完成标准

- Phase 1 的所有实施步骤完成。
- 构建验证成功。
- 手动验收验证通过；如果有例外，必须在这里记录并标注后续状态。
- `docs/PLAN_MAP.md` 更新 Phase 1 证据和当前状态。
- 实施记录：2026-06-27 完成所有源文件创建和 Debug 构建。`LSUIElement = YES` 已验证。macOS 15.0 target，Swift 5.0，使用两参数 `onChange` 闭包语法。TranslationService 加入 UUID-based 任务身份校验，解决取消与 loading 状态竞争。手动验收 14/14 项全部通过。防抖时间 300ms。
- Phase 2 记录：Release 构建完成，`TranslateBar.app` 已复制到项目根目录。2026-06-27 复核 `TranslateBar.app/Contents/Info.plist` 中 `LSUIElement = true`，并通过 `codesign --verify --deep --strict --verbose=2 TranslateBar.app`。

### 后续候选增强

Phase 3 仅作为候选入口，当前不自动开工。登录项、流式输出、endpoint/model 配置、更多语言支持等增强应先新增或更新计划，再进入实施。

## 开放问题

| 问题 | 建议处理 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|
| 工程应使用哪个 macOS deployment target？ | 已确定：macOS 15.0，`onChange` 使用两参数闭包语法。 | 否 | 已解决 |
| v1 是否要让 endpoint 和模型路径可配置？ | 本地第一版保持硬编码；如有需要，后续另建计划加入配置。 | 否 | 暂缓 |
| 长文本是否禁用自动翻译？ | v1 保持自动翻译对所有文本启用，符合 fixed 基线。 | 否 | 已决定 |

## 风险与回滚

- 本地服务不可用：显示诊断错误，并保持 App 可重试。
- 服务契约漂移：重新运行 Step 0 探测，并先更新 parser/request models。
- 取消竞争或 loading 状态残留：显式实现清理，不只依赖任务取消。
- deployment target 不匹配：使用目标 macOS 版本支持的语法。
- 硬编码本地模型路径限制可移植性：v1 本地使用可接受；回滚方式是修改常量，或在后续计划中加入配置。

Phase 1 的回滚方式：保留 `TranslateBar.fixed.md` 和这些治理文档作为基线，只回滚失败尝试中的 App 实现文件。

## 相关 ADR、迁移、规格或议题

- 来源基线：[TranslateBar.fixed.md](../../TranslateBar.fixed.md)
- 前一版草案：[TranslateBar.md](../../TranslateBar.md)
- 计划索引：[PLAN_MAP.md](../PLAN_MAP.md)
