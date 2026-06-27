# PLAN_MAP

## 治理范围

本文件跟踪 TranslateBar 的阶段性交付。TranslateBar 是一个 macOS 菜单栏翻译 App，通过本地 OpenAI Chat Completions 兼容服务调用 Hy-MT2-7B-4bit 模型。

普通一次性修改不进入这里。以下情况需要新增或更新条目：工作跨阶段推进、改变本地 API 契约、改变 App 打包或启动行为、使现有验证证据失效。

## 计划索引

| 计划 | 状态 | 当前阶段 | 依赖 | 证据 |
|---|---|---|---|---|
| [translatebar-v1](plans/translatebar-v1.md) | 已完成 | Phase 0-2 已完成；Phase 3 候选 | `127.0.0.1:8787` 上的本地 Hy-MT2 服务 | [Step 0 证据](plans/translatebar-v1.md#step-0-证据)，[已完成证据](#已完成证据) |
| [service-settings-and-install](plans/service-settings-and-install.md) | 已完成 | Phase 1-2 已完成 | translatebar-v1 | [Step 0 证据](plans/service-settings-and-install.md#step-0-证据)，[已完成证据](#已完成证据) |
| [install-cleanup-and-login-item](plans/install-cleanup-and-login-item.md) | 已完成 | Phase 0-3 已完成 | service-settings-and-install | [Step 0 证据](plans/install-cleanup-and-login-item.md#step-0-证据)，[已完成证据](#已完成证据) |
| [model-list-selection](plans/model-list-selection.md) | 已完成 | Phase 0-3 已完成 | service-settings-and-install | [Step 0 证据](plans/model-list-selection.md#step-0-证据)，[已完成证据](#已完成证据) |
| [streaming-translation](plans/streaming-translation.md) | 候选 | Phase 0 | service-settings-and-install | [Step 0 证据待补](plans/streaming-translation.md#step-0-证据) |

允许的状态值：`候选`、`设计中`、`待实施`、`实施中`、`已完成`、`已替代`、`已合并`、`已废弃`。

## 推荐顺序

1. `translatebar-v1`
2. `service-settings-and-install`
3. `install-cleanup-and-login-item`
4. `model-list-selection`
5. `streaming-translation`

## 依赖关系

| 计划 | 依赖 | 原因 |
|---|---|---|
| translatebar-v1 | 本地服务 `http://127.0.0.1:8787` | 第一版直接调用本地模型服务，不包含服务启动或模型管理。 |
| translatebar-v1 | 模型 id `/Users/jafish/Documents/models/Hy-MT2-7B-4bit` | 服务会把短模型名当作 Hugging Face repo id 解析，因此 App 必须发送完整本地模型路径。 |
| translatebar-v1 | macOS SwiftUI/AppKit 构建环境 | App 是原生 `LSUIElement` 菜单栏应用，使用 `NSStatusBar`、`NSPopover` 和 SwiftUI。 |
| service-settings-and-install | translatebar-v1 | 配置化和安装流程建立在已完成的 v1 App 上。 |
| install-cleanup-and-login-item | service-settings-and-install | 需要基于已安装到 `~/Applications/TranslateBar.app` 的单一正式产物实现构建清理和登录项。 |
| model-list-selection | service-settings-and-install | 模型列表读取依赖已配置的服务地址，并应复用当前 endpoint/model 配置。 |
| streaming-translation | service-settings-and-install | 流式输出依赖当前翻译请求配置和错误显示基础。 |

## 替换、合并与废弃

| 计划 | 关系 | 目标 | 原因 |
|---|---|---|---|
| translatebar-v1 | 替代 | [TranslateBar.md](../TranslateBar.md) | 原始草案缺少已验证模型 id、明确响应路径、手动翻译模式和退出行为。 |
| translatebar-v1 | 来源 | [TranslateBar.fixed.md](../TranslateBar.fixed.md) | fixed 草案是当前受治理计划的实现基线。 |
| service-settings-and-install | 扩展 | [translatebar-v1](plans/translatebar-v1.md) | 将 v1 的硬编码服务配置改为用户可配置，并把 Release App 安装到用户应用目录。 |
| install-cleanup-and-login-item | 扩展 | [service-settings-and-install](plans/service-settings-and-install.md) | 规范后续构建安装流程，避免 Launchpad 重复项，并补上登录项/开机自启动。 |
| model-list-selection | 扩展 | [service-settings-and-install](plans/service-settings-and-install.md) | 将模型路径手动输入扩展为从 `/v1/models` 读取和选择。 |
| streaming-translation | 扩展 | [service-settings-and-install](plans/service-settings-and-install.md) | 将非流式翻译扩展为可选流式输出。 |

## 当前阻塞项

| 问题 | 建议处理 | 影响 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|---|
| SwiftUI `onChange` API 可用性取决于 deployment target | 已确定：macOS 15.0 target，使用两参数闭包语法 `{ _, newValue in }`，编译通过。 | 较旧 deployment target 下可能构建失败 | 否 | 已解决 |
| 草案服务代码的部分取消路径可能让 loading 状态停留为 true | 已修复：TranslationService 使用 UUID-based 任务身份校验（`currentTranslateId`），确保取消后旧任务不覆写新任务的 loading 状态。 | 取消请求后 UI 可能残留进度状态 | 否 | 已解决 |
| 模型路径绑定当前用户机器 | 第一版本地使用可继续硬编码；分发前改为配置项 | App 无法直接跨机器使用 | 否 | 暂缓 |
| 配置化会改变请求失败信息 | 已实现：错误提示展示当前配置的 endpoint，非法 endpoint 和空模型路径会提前报错。 | 配置错误时用户难以诊断 | 否 | 已解决 |
| 后续构建可能重新注册 DerivedData 中的 `TranslateBar.app` | 已解决：`install-cleanup-and-login-item` 提供了 `scripts/install_app.sh`，构建后自动清理 DerivedData 重复产物并只保留 `~/Applications/TranslateBar.app`。 | 启动台搜索可能再次出现多个同名 App | 否 | 已解决 |
| 模型列表接口的 endpoint 推导方式未验证 | 已解决：`model-list-selection` 已完成，`/v1/models` 响应为标准 OpenAI 格式（`data[].id`），`TranslationConfiguration.modelsEndpoint` 从 chat endpoint 推导。 | 模型列表可能请求到错误地址 | 否 | 已解决 |
| 流式响应格式未验证 | `streaming-translation` Phase 0 需要用 `stream: true` 固定真实 SSE 样本。 | parser 可能无法兼容服务输出 | 否 | 候选 |

## 已完成证据

| 计划 | 阶段 | 证据 |
|---|---|---|
| translatebar-v1 | Phase 0 | `TranslateBar.fixed.md` 记录了 `/v1/models` 和 `/v1/chat/completions` 探测成功、完整本地模型 id，以及响应路径 `choices[0].message.content`。 |
| translatebar-v1 | Phase 1 | 构建成功（Debug，xcodebuild，arm64）。`LSUIElement = YES` 已确认。Project 使用 macOS 15.0 deployment target，Swift 5.0。手动验收 14/14 项全部通过（2026-06-27）。防抖 300ms。 |
| translatebar-v1 | Phase 2 | Release 构建成功（arm64，378K）。`TranslateBar.app` 的 `LSUIElement = true` 已确认，`codesign --verify --deep --strict --verbose=2 TranslateBar.app` 通过。产物复制到项目根目录 `TranslateBar.app`。从项目目录启动验证通过。 |
| service-settings-and-install | Phase 0 | v1 已完成；当前硬编码 endpoint 为 `http://127.0.0.1:8787/v1/chat/completions`，模型路径为 `/Users/jafish/Documents/models/Hy-MT2-7B-4bit`；当前 App 可从项目根目录 `TranslateBar.app` 启动。 |
| service-settings-and-install | Phase 1 | 已新增 `TranslationConfiguration`，endpoint/model 通过 `UserDefaults` 配置并保留 v1 默认值。面板新增“服务设置”，支持修改服务地址、模型路径和恢复默认。Debug 和 Release 构建通过。 |
| service-settings-and-install | Phase 2 | Release App 已同步到项目根目录和 `~/Applications/TranslateBar.app`，并通过 LaunchServices 注册。安装后 `LSUIElement = true`，`codesign --verify --deep --strict --verbose=2 ~/Applications/TranslateBar.app` 通过，Spotlight 元数据显示为 `com.apple.application-bundle`。 |
| install-cleanup-and-login-item | Phase 0 | 基线确认：`find`/`mdfind` 仅一个 `~/Applications/TranslateBar.app`；DerivedData 干净；`LSUIElement = true`；签名通过；登录项状态 `notFound`（未注册）；无 LaunchAgent。 |
| install-cleanup-and-login-item | Phase 1 | `scripts/install_app.sh` 创建：Release build → 安装 `~/Applications/TranslateBar.app` → 清理 DerivedData 和项目根目录重复产物 → `lsregister` 重新注册。脚本执行后 `mdfind` 仅返回正式路径，DerivedData 无残留，签名通过。 |
| install-cleanup-and-login-item | Phase 2 | `LoginItemService.swift` 封装 `SMAppService.mainApp`（`enable`/`disable`/`refresh`/中文错误信息）。`TranslatePanelView` 设置区域新增「登录时启动」Toggle，默认关闭，错误信息可读。Release 构建通过。 |
| install-cleanup-and-login-item | Phase 3 | 脚本 → 安装 → 索引 → 登录项 → 治理全部通过。`plan-governance` 验证：`mdfind` 唯一、`LSUIElement = true`、签名通过。 |
| model-list-selection | Phase 0 | `/v1/models` 探测成功（标准 OpenAI 格式 `data[].id`），endpoint 推导规则 `chat/completions → models` 已确认。 |
| model-list-selection | Phase 1 | `Models.swift` 新增 `ModelListResponse`/`ModelItem`；`TranslationConfiguration.modelsEndpoint` 推导属性；`ModelListService` 异步拉取+可读错误。 |
| model-list-selection | Phase 2 | `TranslatePanelView` 设置区新增「刷新模型列表」按钮（含 `ProgressView` 加载态）、`Picker` 模型选择、`TextField` 手动输入 fallback、错误内联显示。 |
| model-list-selection | Phase 3 | Debug/Release 构建通过，`install_app.sh` 安装成功。 |
