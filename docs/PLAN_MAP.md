# PLAN_MAP

## 治理范围

本文件跟踪 TranslateBar 的阶段性交付。TranslateBar 是一个 macOS 菜单栏翻译 App，通过本地 OpenAI Chat Completions 兼容服务调用 Hy-MT2-7B-4bit 模型。

普通一次性修改不进入这里。以下情况需要新增或更新条目：工作跨阶段推进、改变本地 API 契约、改变 App 打包或启动行为、使现有验证证据失效。

## 文档权责

- 本文件是状态、依赖、替代/合并/废弃关系、推荐顺序、当前阻塞项和证据链接的事实源。
- `docs/plans/*.md` 是专项计划实施细节的事实源，包括字段方案、Schema、枚举、Step 0 证据、验证方式、完成条件、风险和回滚。
- 总路线图、优先级计划和索引只记录顺序、状态摘要和专项计划链接，不复制字段级方案、枚举、Step 0 细节或完成定义。
- 当专项计划状态、字段方案、完成条件或验证结果变化时，必须同步本文件和所有引用该计划的路线图、优先级计划、索引文档。
- 验收治理文档时，必须用 `rg` 搜索同名计划、P 编号、状态名和关键字段，检查重复定义或漂移。

## 计划索引

| 计划 | 状态 | 当前阶段 | 依赖 | 证据 |
|---|---|---|---|---|
| [translatebar-v1](plans/translatebar-v1.md) | 已完成 | Phase 0-2 已完成；Phase 3 候选 | `127.0.0.1:8787` 上的本地 Hy-MT2 服务 | [Step 0](plans/translatebar-v1.md#step-0-证据)，[完成标准](plans/translatebar-v1.md#完成标准)，[测试覆盖率](plans/translatebar-v1.md#测试覆盖率) |
| [service-settings-and-install](plans/service-settings-and-install.md) | 已完成 | Phase 1-2 已完成 | translatebar-v1 | [Step 0](plans/service-settings-and-install.md#step-0-证据)，[完成标准](plans/service-settings-and-install.md#完成标准)，[测试覆盖率](plans/service-settings-and-install.md#测试覆盖率) |
| [install-cleanup-and-login-item](plans/install-cleanup-and-login-item.md) | 已完成 | Phase 0-3 已完成 | service-settings-and-install | [Step 0](plans/install-cleanup-and-login-item.md#step-0-证据)，[完成标准](plans/install-cleanup-and-login-item.md#完成标准)，[测试覆盖率](plans/install-cleanup-and-login-item.md#测试覆盖率) |
| [model-list-selection](plans/model-list-selection.md) | 已完成 | Phase 0-3 已完成 | service-settings-and-install | [Step 0](plans/model-list-selection.md#step-0-证据)，[完成标准](plans/model-list-selection.md#完成标准)，[测试覆盖率](plans/model-list-selection.md#测试覆盖率) |
| [streaming-translation](plans/streaming-translation.md) | 已完成 | Phase 0-3 已完成 | service-settings-and-install | [Step 0](plans/streaming-translation.md#step-0-证据)，[完成标准](plans/streaming-translation.md#完成标准)，[测试覆盖率](plans/streaming-translation.md#测试覆盖率) |
| [deepseek-cloud-support-implementation](plans/deepseek-cloud-support-implementation.md) | 已完成 | 全部实施完成 | streaming-translation, model-list-selection | [Step 0](plans/deepseek-cloud-support-implementation.md#实施目标)，[完成条件](plans/deepseek-cloud-support-implementation.md#完成条件)，[测试 15 用例全部通过](#验证命令) |
| [auto-language-detection](plans/auto-language-detection.md) | 已完成 | 主语言占比规则 | translatebar-v1, unit-test-coverage | [Step 0](plans/auto-language-detection.md#step-0-证据)，[完成条件](plans/auto-language-detection.md#完成条件)，[验证方式](plans/auto-language-detection.md#验证方式) |
| [unit-test-coverage](plans/unit-test-coverage.md) | 已完成 | Phase 0-3 已完成 | translatebar-v1, service-settings-and-install, install-cleanup-and-login-item, model-list-selection, streaming-translation | [Step 0](plans/unit-test-coverage.md#step-0-证据)，[完成标准](plans/unit-test-coverage.md#完成标准)，[测试覆盖率](plans/unit-test-coverage.md#测试覆盖率) |

允许的状态值：`候选`、`设计中`、`待实施`、`实施中`、`已完成`、`已替代`、`已合并`、`已废弃`。

## 推荐顺序

1. `translatebar-v1`
2. `service-settings-and-install`
3. `install-cleanup-and-login-item`
4. `model-list-selection`
5. `streaming-translation`
6. `unit-test-coverage`
7. `deepseek-cloud-support-implementation`
8. `auto-language-detection`

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
| unit-test-coverage | translatebar-v1 | 测试覆盖需要覆盖 v1 的模型、翻译服务、菜单栏启动和面板基础行为。 |
| unit-test-coverage | service-settings-and-install | 测试覆盖需要覆盖 endpoint/model 配置读取和请求配置构造。 |
| unit-test-coverage | install-cleanup-and-login-item | 测试覆盖需要覆盖登录项服务和设置区开关行为。 |
| unit-test-coverage | model-list-selection | 测试覆盖需要覆盖 `/v1/models` 解析、错误路径和模型选择相关状态。 |
| unit-test-coverage | streaming-translation | 测试覆盖需要覆盖 SSE chunk 解码、流式成功路径、keepalive 跳过和非流式 fallback。 |
| deepseek-cloud-support-implementation | streaming-translation | DeepSeek 支持复用已实现的流式/非流式双路径、模型列表服务和错误显示框架。 |
| deepseek-cloud-support-implementation | model-list-selection | DeepSeek 模型列表读取依赖已实现的 `/v1/models` 解析和 Picker 选择组件。 |
| auto-language-detection | translatebar-v1 | 自动模式是 v1 的核心翻译模式，需要保留显式中译英/英译中行为不变。 |
| auto-language-detection | unit-test-coverage | 主语言占比规则需要通过 `ModelsTests` 和必要的 prompt 测试固定回归样本。 |

## 替换、合并与废弃

| 计划 | 关系 | 目标 | 原因 |
|---|---|---|---|
| translatebar-v1 | 替代 | [TranslateBar.md](../TranslateBar.md) | 原始草案缺少已验证模型 id、明确响应路径、手动翻译模式和退出行为。 |
| translatebar-v1 | 来源 | [TranslateBar.fixed.md](../TranslateBar.fixed.md) | fixed 草案是当前受治理计划的实现基线。 |
| service-settings-and-install | 扩展 | [translatebar-v1](plans/translatebar-v1.md) | 将 v1 的硬编码服务配置改为用户可配置，并把 Release App 安装到用户应用目录。 |
| install-cleanup-and-login-item | 扩展 | [service-settings-and-install](plans/service-settings-and-install.md) | 规范后续构建安装流程，避免 Launchpad 重复项，并补上登录项/开机自启动。 |
| model-list-selection | 扩展 | [service-settings-and-install](plans/service-settings-and-install.md) | 将模型路径手动输入扩展为从 `/v1/models` 读取和选择。 |
| streaming-translation | 扩展 | [service-settings-and-install](plans/service-settings-and-install.md) | 将非流式翻译扩展为可选流式输出。 |
| deepseek-cloud-support-implementation | 扩展 | [streaming-translation](plans/streaming-translation.md) | 将本地单 provider 架构扩展为多 provider（本地 + DeepSeek 云端），复用流式/非流式双路径和模型列表组件。 |
| auto-language-detection | 扩展 | [translatebar-v1](plans/translatebar-v1.md) | 将 v1 的“包含任意中文即翻英”自动检测规则扩展为主语言占比判断，减少英文主文本夹带中文字符时的误判。 |
| unit-test-coverage | 来源 | [superpowers 单元测试覆盖率设计](superpowers/specs/2026-06-27-unit-test-coverage-design.md) | 将 superpowers 中的 90%+ 单元测试覆盖率功能计划合并进治理体系。 |

## 当前阻塞项

| 问题 | 建议处理 | 影响 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|---|
| SwiftUI `onChange` API 可用性取决于 deployment target | 已确定：macOS 15.0 target，使用两参数闭包语法 `{ _, newValue in }`，编译通过。 | 较旧 deployment target 下可能构建失败 | 否 | 已解决 |
| 草案服务代码的部分取消路径可能让 loading 状态停留为 true | 已修复：TranslationService 使用 UUID-based 任务身份校验（`currentTranslateId`），确保取消后旧任务不覆写新任务的 loading 状态。 | 取消请求后 UI 可能残留进度状态 | 否 | 已解决 |
| 模型路径绑定当前用户机器 | 第一版本地使用可继续硬编码；分发前改为配置项 | App 无法直接跨机器使用 | 否 | 暂缓 |
| 配置化会改变请求失败信息 | 已实现：错误提示展示当前配置的 endpoint，非法 endpoint 和空模型路径会提前报错。 | 配置错误时用户难以诊断 | 否 | 已解决 |
| 后续构建可能重新注册 DerivedData 中的 `TranslateBar.app` | 已解决：`install-cleanup-and-login-item` 提供了 `scripts/install_app.sh`，构建后自动清理 DerivedData 重复产物并只保留 `~/Applications/TranslateBar.app`。 | 启动台搜索可能再次出现多个同名 App | 否 | 已解决 |
| 模型列表接口的 endpoint 推导方式未验证 | 已解决：`model-list-selection` 已完成，`/v1/models` 响应为标准 OpenAI 格式（`data[].id`），`TranslationConfiguration.modelsEndpoint` 从 chat endpoint 推导。 | 模型列表可能请求到错误地址 | 否 | 已解决 |
| 流式响应格式未验证 | 已解决：`streaming-translation` 已完成，SSE 为标准 OpenAI 格式（`choices[0].delta.content`，`[DONE]` 结束），`URLSession.AsyncBytes.lines` 逐行解析。 | parser 可能无法兼容服务输出 | 否 | 已解决 |
| 自动语言检测遇到英文主文本夹带少量中文字符会误判 | 已解决：`auto-language-detection` 实施完成，用主语言占比替代”包含任意中文”规则。 | 自动模式可能把英文句子错误翻译为英文 | 否 | 已解决 |

## 证据链接

专项计划是 Step 0、实施细节、完成标准和验证结果的事实源。本索引只保留证据入口：

| 计划 | 证据入口 |
|---|---|
| translatebar-v1 | [Step 0](plans/translatebar-v1.md#step-0-证据)，[完成标准](plans/translatebar-v1.md#完成标准)，[测试覆盖率](plans/translatebar-v1.md#测试覆盖率) |
| service-settings-and-install | [Step 0](plans/service-settings-and-install.md#step-0-证据)，[完成标准](plans/service-settings-and-install.md#完成标准)，[测试覆盖率](plans/service-settings-and-install.md#测试覆盖率) |
| install-cleanup-and-login-item | [Step 0](plans/install-cleanup-and-login-item.md#step-0-证据)，[完成标准](plans/install-cleanup-and-login-item.md#完成标准)，[测试覆盖率](plans/install-cleanup-and-login-item.md#测试覆盖率) |
| model-list-selection | [Step 0](plans/model-list-selection.md#step-0-证据)，[完成标准](plans/model-list-selection.md#完成标准)，[测试覆盖率](plans/model-list-selection.md#测试覆盖率) |
| streaming-translation | [Step 0](plans/streaming-translation.md#step-0-证据)，[完成标准](plans/streaming-translation.md#完成标准)，[测试覆盖率](plans/streaming-translation.md#测试覆盖率) |
| deepseek-cloud-support-implementation | [实施目标](plans/deepseek-cloud-support-implementation.md#实施目标)，[完成条件](plans/deepseek-cloud-support-implementation.md#完成条件) |
| auto-language-detection | [Step 0](plans/auto-language-detection.md#step-0-证据)，[完成条件](plans/auto-language-detection.md#完成条件)，[验证方式](plans/auto-language-detection.md#验证方式) |
| unit-test-coverage | [Step 0](plans/unit-test-coverage.md#step-0-证据)，[完成标准](plans/unit-test-coverage.md#完成标准)，[测试覆盖率](plans/unit-test-coverage.md#测试覆盖率) |
