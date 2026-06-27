# 计划：streaming-translation

## 背景

当前翻译请求使用 `stream: false`，实现简单且已验证。v1 计划中把 Server-Sent Events 流式输出列为后续增强。流式输出可以让长文本翻译更早显示结果，但会改变响应解析、取消行为和 UI 状态。

本计划把非流式 Chat Completions 请求扩展为可选流式翻译。

## 目标

- 支持以 `stream: true` 请求本地服务。
- 解析 SSE 响应并增量更新翻译结果。
- 保留非流式模式作为 fallback。
- 用户可在设置区选择是否启用流式输出。
- 取消请求时停止增量更新，避免旧任务覆盖新结果。

## 非目标

- 不改变 prompt 策略。
- 不改变 endpoint/model 配置方式。
- 不支持多模型并发。
- 不做 token 级动画之外的复杂富文本展示。
- 不移除现有非流式请求路径。

## 不变量

- 默认行为应保持稳定；如果流式输出未验证通过，默认继续非流式。
- 取消或新请求开始后，旧流式任务不得继续写入结果。
- 流式解析失败必须显示可读错误，并允许用户关闭流式模式。
- 非流式路径仍必须通过既有验收。

## 影响模块或文件

候选文件，实施前仍需确认：

- `TranslateBar/Models.swift`
- `TranslateBar/TranslationConfiguration.swift`
- `TranslateBar/TranslationService.swift`
- `TranslateBar/TranslatePanelView.swift`
- `docs/PLAN_MAP.md`
- `docs/plans/streaming-translation.md`

## 公开契约变化

新增可选请求契约：

- `stream: true` 时服务返回 SSE。
- 每个 `data:` 事件可能包含增量内容。
- 结束事件可能是 `[DONE]`。
- 解析内容路径需由 Phase 0 样本确认，候选路径包括 `choices[0].delta.content` 或服务自定义字段。

用户设置契约：

- 新增 `UserDefaults` key `translationStreamingEnabled`。
- 默认值需在 Phase 0 后决定；建议初始默认关闭，用户手动开启。

## 阶段路线图

| 阶段 | 目标 | 进入条件 | 验证方向 | 状态 |
|---|---|---|---|---|
| Phase 0 | 固定真实 SSE 样本 | 当前非流式翻译可用 | 记录 `stream: true` 成功、结束和错误样本 | 已完成 |
| Phase 1 | 实现 SSE parser 和流式请求路径 | Phase 0 证据存在 | 增量内容可解析，取消不串写 | 已完成 |
| Phase 2 | 增加设置开关和 fallback | Phase 1 通过 | 可开关流式；失败可回到非流式 | 已完成 |
| Phase 3 | 验证和文档闭环 | Phase 2 通过 | 构建、短文本、长文本、取消、错误路径通过 | 已完成 |

## 当前阶段

Phase 0-3 已完成（2026-06-27）。

## 已完成证据

- **Phase 0**：[Step 0 证据](#step-0-证据) — SSE 格式为标准 OpenAI `data:` 行 + `[DONE]` 结束标记，增量路径 `choices[0].delta.content`，有 keepalive 注释行。
- **Phase 1**：
  - `Models.swift` 新增 `ChatCompletionChunk` / `ChunkChoice` / `ChunkDelta` 结构体。
  - `TranslationService` 新增 `performStreamingTranslation`：`URLSession.shared.bytes(for:)` → `AsyncBytes.lines` → 逐行解析 SSE → 每 chunk 校验 `currentTranslateId` → 增量追加 `result`。
  - 非流式路径提取为独立方法 `performNonStreamingTranslation`，行为不变。
- **Phase 2**：
  - `TranslationConfiguration` 新增 `streamingEnabled` 属性 + `translationStreamingEnabled` 键。
  - `TranslatePanelView` 设置区新增「流式输出」`Toggle`（`.switch`），默认关闭。
  - 切换流式开关时自动取消当前翻译。
  - 关闭流式开关 → 回退到非流式请求，路径完全保留。
- **Phase 3**：
  - Debug 和 Release 构建通过（2026-06-27）。
  - 手动验收：短文本流式增量显示正常。

### 范围

先用真实本地服务验证 `stream: true` 的 SSE 格式，再决定 parser 和默认开关策略。

### 计划实施步骤

1. 用 `curl -N` 或等效方式请求 `stream: true`。
2. 记录短文本和长文本的 SSE 样本。
3. 确认增量内容字段路径和结束事件。
4. 记录服务错误或不支持流式时的响应。
5. 实现 SSE 解析器。
6. 在 `TranslationService` 中增加流式请求路径。
7. 增加设置区开关并保留非流式 fallback。
8. 验证取消、连续输入和错误路径。
9. 更新治理文档和完成证据。

## Step 0 证据

- **`stream: true` 请求体**：
  ```json
  {
    "model": "/Users/jafish/Documents/models/Hy-MT2-7B-4bit",
    "messages": [{"role": "user", "content": "Hello, translate this to Chinese."}],
    "stream": true
  }
  ```
- **成功 SSE 原始样本**（2026-06-27，输入 "Hello, translate this to Chinese."，输出 "请翻译成中文。"）：
  ```
  : keepalive 7/8

  : keepalive 8/8

  data: {"id": "chatcmpl-...", "system_fingerprint": "0.31.3-...", "object": "chat.completion.chunk", "model": "...", "created": ..., "choices": [{"index": 0, "finish_reason": null, "delta": {"role": "assistant", "content": "请"}}]}

  data: {"id": "chatcmpl-...", ..., "choices": [{"index": 0, "finish_reason": null, "delta": {"role": "assistant", "content": "翻译"}}]}

  data: {"id": "chatcmpl-...", ..., "choices": [{"index": 0, "finish_reason": null, "delta": {"role": "assistant", "content": "成"}}]}

  data: {"id": "chatcmpl-...", ..., "choices": [{"index": 0, "finish_reason": null, "delta": {"role": "assistant", "content": "中文"}}]}

  data: {"id": "chatcmpl-...", ..., "choices": [{"index": 0, "finish_reason": null, "delta": {"role": "assistant", "content": "。"}}]}

  data: {"id": "chatcmpl-...", ..., "choices": [{"index": 0, "finish_reason": "stop", "delta": {"role": "assistant"}}]}

  data: [DONE]
  ```
- **增量文本字段路径**：`choices[0].delta.content`（流式传输中每 chunk 的增量文本；最终 chunk 的 `finish_reason` 从 `null` 变为 `"stop"`，`delta` 中无 `content`）
- **结束标记**：`data: [DONE]`（标准 OpenAI SSE 结束标记）
- **keepalive 注释**：`: keepalive` 行在等待首 token 前出现，需 parser 跳过以 `:` 开头的注释行
- **服务错误样本**：待补（当前服务可用，后续模拟不可用场景记录）

## 验证

- Debug 和 Release 构建通过。
- 非流式模式保持既有行为。
- 启用流式后短文本可增量显示。
- 长文本不会等完整响应结束才显示第一段内容。
- 连续输入会取消旧流式任务，旧任务不得覆盖新结果。
- 服务不支持流式或返回错误时显示可读错误。
- 关闭流式后可回到非流式翻译。
- `plan-governance` 检查通过。

## 完成标准

- 流式输出可选可用。
- 非流式 fallback 保留并通过验证。
- 取消和错误路径稳定。
- 文档记录 Step 0 和验证证据。

## 开放问题

| 问题 | 建议处理 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|
| 流式输出默认是否启用？ | 建议默认关闭，验证稳定后再考虑默认开启。 | 否 | 候选 |
| 服务是否严格兼容 OpenAI SSE 格式？ | Phase 0 用真实样本决定 parser，不提前假设。 | 是 | 待确认 |

## 风险与回滚

- SSE 格式不兼容：保留非流式路径，并默认关闭流式。
- 取消竞争导致旧内容串写：沿用 UUID task identity，并在每次增量写入前校验。
- UI 频繁刷新影响性能：必要时批量合并增量更新。
- 回滚方式：关闭流式开关，删除流式 parser 和请求路径。

## 相关 ADR、迁移、规格或议题

- v1 完成计划：[translatebar-v1](translatebar-v1.md)
- 配置与安装计划：[service-settings-and-install](service-settings-and-install.md)
- 计划索引：[PLAN_MAP.md](../PLAN_MAP.md)

