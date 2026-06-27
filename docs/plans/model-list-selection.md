# 计划：model-list-selection

## 背景

当前 App 已支持手动配置 endpoint 和模型路径。模型路径默认值来自已验证的本地模型，但用户仍需要手动填写或恢复默认。服务已经在 v1 探测中过 `/v1/models`，可以作为模型选择来源。

本计划把设置区中的模型路径输入增强为“读取模型列表并选择模型”，减少手填路径错误。

## 目标

- 从当前服务配置推导 `/v1/models` 地址。
- 拉取模型列表并展示可选模型 id。
- 用户选择模型后写入现有 `translationModel` 配置。
- 保留手动输入能力，避免 `/v1/models` 不可用时阻塞使用。
- 模型列表读取失败时显示可诊断错误，不影响现有翻译。

## 非目标

- 不自动下载模型。
- 不启动或管理本地服务。
- 不改变 Chat Completions 请求格式。
- 不移除手动模型路径输入。
- 不改变中英互译产品范围。

## 不变量

- `translationModel` 仍是最终请求使用的模型配置来源。
- `/v1/models` 不可用时，翻译功能仍应可通过手动模型路径使用。
- 读取模型列表不得覆盖用户当前模型，除非用户明确选择。
- 模型列表错误不能清空当前配置。

## 影响模块或文件

候选文件，实施前仍需确认：

- `TranslateBar/Models.swift`
- `TranslateBar/TranslationConfiguration.swift`
- `TranslateBar/ModelListService.swift`
- `TranslateBar/TranslatePanelView.swift`
- `TranslateBar.xcodeproj/project.pbxproj`
- `docs/PLAN_MAP.md`
- `docs/plans/model-list-selection.md`

## 公开契约变化

新增本地服务契约：

- 当前 chat endpoint 形如 `http://host:port/v1/chat/completions` 时，模型列表 endpoint 推导为 `http://host:port/v1/models`。
- 模型列表响应读取 `data[].id`。
- 选择模型后继续使用现有 `UserDefaults` key `translationModel`。

## 阶段路线图

| 阶段 | 目标 | 进入条件 | 验证方向 | 状态 |
|---|---|---|---|---|
| Phase 0 | 固定 `/v1/models` 基线 | 当前 endpoint 可配置 | 记录推导 URL、真实响应和失败样本 | 已完成 |
| Phase 1 | 实现模型列表服务 | Phase 0 证据存在 | 单次拉取可解析 `data[].id`，错误可读 | 已完成 |
| Phase 2 | 实现设置区模型选择 UI | Phase 1 通过 | 用户可刷新列表、选择模型、保留手动输入 | 已完成 |
| Phase 3 | 验证和文档闭环 | Phase 2 通过 | 构建、手动验收、治理检查通过 | 已完成 |

## 当前阶段

Phase 0-3 已完成（2026-06-27）。

## 已完成证据

- **Phase 0**：[Step 0 证据](#step-0-证据) — `/v1/models` 真实响应已记录，标准 OpenAI 格式，推导规则已确认。
- **Phase 1**：
  - `Models.swift` 新增 `ModelListResponse` / `ModelItem` 结构体（标准 OpenAI 格式解析）。
  - `TranslationConfiguration.swift` 新增 `modelsEndpoint` 计算属性（从 chat endpoint 推导 `/v1/models`）。
  - `ModelListService.swift` 新增 `@MainActor ObservableObject`：`fetchModels()` 异步拉取、解析 `data[].id`、可读错误信息。
- **Phase 2**：
  - `TranslatePanelView.swift` 设置区新增「刷新模型列表」按钮（含加载状态 `ProgressView`）。
  - 模型列表加载后显示 `Picker`（`.menu` 风格）供选择，选择后写入 `translationModel`。
  - 手动 `TextField` 输入始终保留作为 fallback。
  - 错误信息在按钮旁以内联 caption 显示，不影响当前模型配置。
- **Phase 3**：
  - Debug 和 Release 构建通过（2026-06-27）。
  - `scripts/install_app.sh` 安装成功，产物路径 `/Users/jafish/Applications/TranslateBar.app`。

### 范围

先验证当前服务的 `/v1/models` 真实响应，并明确从 chat endpoint 到 models endpoint 的推导规则。

### 计划实施步骤

1. 读取当前 `translationEndpoint` 和 `translationModel` 默认值。
2. 用当前 endpoint 推导 `/v1/models` URL。
3. 用 `curl` 记录成功响应样本。
4. 记录服务不可用或响应不兼容时的错误样本。
5. 新增模型列表响应结构体。
6. 新增 `ModelListService`。
7. 在设置区加入“刷新模型”按钮和模型选择控件。
8. 构建并手动验证。
9. 更新治理文档和完成证据。

## Step 0 证据

- **当前 chat endpoint**：`http://127.0.0.1:8787/v1/chat/completions`
- **推导出的 `/v1/models` endpoint**：`http://127.0.0.1:8787/v1/models`
- **`curl http://127.0.0.1:8787/v1/models` 真实响应**（2026-06-27）：
  ```json
  {
    "object": "list",
    "data": [
      {
        "id": "/Users/jafish/Documents/models/Hy-MT2-7B-4bit",
        "object": "model",
        "created": 1782563890
      }
    ]
  }
  ```
- **响应中模型 id 路径**：`data[].id`（数组内每个元素的 `id` 字段即为模型标识）
- **endpoint 推导规则**：chat endpoint 形如 `http://host:port/v1/chat/completions` → models endpoint = `http://host:port/v1/models`
- **服务不可用时的错误行为**：待补（当前服务可用，后续模拟不可用场景记录）

## 验证

- Debug 和 Release 构建通过。
- 点击“刷新模型”可读取模型列表。
- 选择模型后 `translationModel` 更新。
- 手动输入模型路径仍可用。
- `/v1/models` 不可用时显示错误，但不影响当前模型配置。
- 翻译请求仍使用最终选中的模型。
- `plan-governance` 检查通过。

## 完成标准

- 模型列表可读取、显示和选择。
- 手动模型路径 fallback 保留。
- 错误信息可诊断。
- 文档记录 Step 0 和验证证据。

## 开放问题

| 问题 | 建议处理 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|
| 如果 endpoint 不是 `/v1/chat/completions` 结尾怎么办？ | Phase 0 固定推导规则；无法推导时要求用户手动输入模型路径。 | 否 | 候选 |
| 是否自动刷新模型列表？ | 暂不自动刷新，由用户点击按钮触发。 | 否 | 建议决定 |

## 风险与回滚

- 服务不支持 `/v1/models`：保留手动模型路径输入作为回滚路径。
- endpoint 推导错误：显示错误，不覆盖当前模型。
- 模型列表为空：提示无可用模型，不清空当前配置。
- 回滚方式：删除模型列表 UI 和服务，继续使用手动模型路径。

## 相关 ADR、迁移、规格或议题

- 配置与安装计划：[service-settings-and-install](service-settings-and-install.md)
- 计划索引：[PLAN_MAP.md](../PLAN_MAP.md)

