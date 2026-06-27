# Wingman MCP 测试报告

> 测试项目：TranslateBar（SwiftUI + AppKit，macOS 菜单栏翻译 App）  
> 测试日期：2026-06-27  
> Wingman MCP 版本：当前会话配置  
> 本地模型：Qwen3.6-35B-A3B-4bit

---

## 一、测试概览

对 Wingman MCP 全部 5 个工具在 TranslateBar 项目上进行了功能测试，覆盖文件摘要、文本压缩、命令输出压缩、Diff 审查四个场景。工具整体可用，但在 Swift 项目上存在语言适配差异。

| 工具 | 调用次数 | 成功率 | 模型参与 | 权威性 |
|------|---------|--------|---------|--------|
| `aux_summarize_file` | 3 | 100% | ✗（heuristic fallback） | ⚠️ 非权威 |
| `aux_compress_text` | 2 | 100% | ✓（本地 LLM） | ⚠️ 非权威 |
| `aux_compress_command_output` | 1 | 100% | ✓（本地 LLM） | ⚠️ 非权威 |
| `aux_review_diff` | 1 | 100% | ✓（本地 LLM） | ⚠️ 非权威 |
| `aux_review_diff_by_file` | 0 | — | — | — |

> **权威性说明**：所有 Wingman 工具输出均标注 `is_authoritative: false`，这是设计如此——Wingman 定位为辅助性分析，最终决策必须回查原文。

---

## 二、逐工具详细测评

### 2.1 `aux_summarize_file` — 文件摘要

**用途**：对源码文件做结构摘要（符号提取、import 分析、行数统计）。

#### 测试用例

| 文件 | 行数 | 提取符号数 | fallback |
|------|------|-----------|----------|
| `TranslationService.swift` | 262 | 2 | ✓ |
| `AppDelegate.swift` | 50 | 1 | ✓ |
| `TranslatePanelView.swift` | 286 | 6 | ✓ |

#### 分析

- **全部走 heuristic fallback 路径**（`fallback_used: true`）。原因：正则模式主要针对 TypeScript/JavaScript，对 Swift 语法（`struct`、`@MainActor`、`ObservableObject`）识别偏差大。
- **符号识别问题**：将 `ScrollView`、`VStack`、`HStack`、`Button` 等 SwiftUI 组件构造函数误识别为顶层函数，未识别 `class`、`struct`、`enum` 等 Swift 原生类型声明。
- **import 分析准确**：正确识别 `Foundation`、`Cocoa`、`SwiftUI`、`AppKit` 等 import。
- **行数统计准确**：非空行、注释行计数与实际一致。
- 工具诚实标注了 `must_verify_in_source: true` 和 uncertainties 列表，说明了局限。

#### 结论

| 维度 | 评分 | 说明 |
|------|------|------|
| 可用性 | ⚠️ 谨慎使用 | Swift 项目走 heuristic 回退，TS/JS 项目预期更好 |
| 准确性 | ⭐⭐ | 符号提取对非 TS/JS 语言有较大偏差 |
| 诚实性 | ⭐⭐⭐⭐⭐ | 明确标注 fallback、非权威、不确定性来源 |

---

### 2.2 `aux_compress_text` — 文本压缩

**用途**：将长文本压缩为结构化摘要 + 关键事实列表。

#### 测试用例 1：项目 README 文本（中文为主）

**输入**：195 字的中文项目介绍

**输出质量**：
- ✅ 准确提取 13 条关键事实
- ✅ 正确理解 LSUIElement、NSPopover、SSE、SMAppService 等技术概念
- ✅ 生成了一段通顺的英文摘要
- Token 消耗：563 prompt + 466 completion = 1029 total

**关键事实示例**：
> "The app uses an NSPopover triggered by clicking the menu bar icon"
> "Streaming translation is supported via Server-Sent Events (SSE) for real-time progress display"
> "Translation tasks are cancelled using UUIDs to prevent older results from overwriting newer ones"

#### 测试用例 2：Models.swift 代码片段（英文/Swift）

**输入**：约 70 行的 Swift 数据模型代码

**输出质量**：
- ✅ 准确识别 TranslationMode 枚举的三个 case 及其中文标签
- ✅ 正确分析 ChatCompletionRequest/Response 的 Codable 嵌套结构
- ✅ 识别 CodingKeys 的 `finish_reason` → `finishReason` 映射
- ✅ 提取 TranslationError 的 5 个 case 及中文 errorDescription
- ✅ 生成简洁的英文摘要
- Token 消耗：786 prompt + 361 completion = 1147 total

#### 结论

| 维度 | 评分 | 说明 |
|------|------|------|
| 可用性 | ✅ 推荐 | 中英文混合内容处理良好 |
| 准确性 | ⭐⭐⭐⭐⭐ | 关键事实完整，无遗漏或幻觉 |
| 效率 | ⭐⭐⭐⭐ | 约 1000 tokens/次，开销合理 |
| 结构化 | ⭐⭐⭐⭐⭐ | summary + key_facts + meta 格式清晰 |

---

### 2.3 `aux_compress_command_output` — 命令输出压缩

**用途**：压缩编译/测试/lint 等命令输出，提取 findings（error/warning/failure）。

#### 测试用例：xcodebuild Release 构建输出

**输入**：约 30 行的构建日志（dsymutil → CopySwiftLibs → ExtractAppIntentsMetadata → CodeSign → Validate → RegisterWithLaunchServices → BUILD SUCCEEDED）

**输出质量**：
- ✅ 正确识别 **BUILD SUCCEEDED**（exit code 0）
- ✅ 提取 1 条 warning：`AppIntents.framework dependency not found`
- ✅ 建议源码检查命令
- ✅ 报告统计准确：`failures: 0, errors: 0, warnings: 1, failed_files: 0`
- Token 消耗：1312 prompt + 239 completion = 1551 total

**结构亮点**：
- `findings[]` 数组，每个 finding 带有 `kind`（warning）、`confidence`（high）、`evidence`（原始日志原文）
- `repeated_errors[]` 自动去重
- `suggested_source_checks[]` 给出可操作的检查建议
- `uncertainties[]` 诚实标注不确定性

#### 结论

| 维度 | 评分 | 说明 |
|------|------|------|
| 可用性 | ✅ 推荐 | CI 日志分析利器 |
| 准确性 | ⭐⭐⭐⭐⭐ | 分类准确，无漏报 |
| 结构化 | ⭐⭐⭐⭐⭐ | findings/repeated/suggestions 层次分明 |
| 实用性 | ⭐⭐⭐⭐⭐ | 长构建日志的"首读"入口 |

---

### 2.4 `aux_review_diff` — Diff 审查

**用途**：对 unified diff 做 checklist 式提交前审查，识别风险。

#### 测试用例：模拟 Models.swift 的 diff

模拟了 2 个变更：
1. 新增 `jaToZh` 翻译模式枚举值
2. `APIError.param` → `APIError.parameter` 重命名

**输出质量**：

| 发现 | 严重度 | 准确度 |
|------|--------|--------|
| `param` → `parameter` 重命名可能导致 JSON 反序列化失败 | 🔴 HIGH | ✅ 准确 |
| 新增 `jaToZh` 可能破坏 switch 穷举匹配 | 🟡 MEDIUM | ✅ 准确 |
| 建议 4 个针对性测试 | — | ✅ 合理 |
| 建议 3 个源码检查点 | — | ✅ 合理 |

**额外发现**：
- 同时包含了 `heuristic_signals`（启发式信号），如"所有新增行都是空白/注释"，标注为 `confidence: low`——证明工具在多个层面同时分析
- Token 消耗：965 prompt + 570 completion = 1535 total

#### 结论

| 维度 | 评分 | 说明 |
|------|------|------|
| 可用性 | ✅ 推荐 | 提交前快速扫查 |
| 准确性 | ⭐⭐⭐⭐⭐ | 风险分级准确，建议有针对性 |
| 覆盖度 | ⭐⭐⭐⭐ | 兼容性 + 穷举 + 反序列化，覆盖主要风险面 |
| 实用性 | ⭐⭐⭐⭐⭐ | 作为第一道防线，辅助人工 review |

---

## 三、综合评估

### 3.1 语言适配性

| 语言 | `summarize_file` | `compress_text` | `compress_cmd` | `review_diff` |
|------|:---:|:---:|:---:|:---:|
| TypeScript/JavaScript | ✅ 预期最佳 | ✅ | ✅ | ✅ |
| Swift | ⚠️ heuristic | ✅ | ✅ | ✅ |
| Python/Go/Rust 等 | ⚠️ 待验证 | ✅ | ✅ | ✅ |

> `compress_text`、`compress_cmd`、`review_diff` 三个工具使用本地 LLM 做语义分析，不受语言限制。仅 `summarize_file` 依赖语言相关的正则模式。

### 3.2 推荐使用场景

| 场景 | 工具 | 优先级 |
|------|------|--------|
| 构建/CI 日志太长，需要快速定位问题 | `compress_command_output` | 🥇 |
| 想了解一个长文件/文档的核心内容 | `compress_text` | 🥇 |
| 提交前快速扫查 diff 风险 | `review_diff` | 🥈 |
| 大 diff 按文件拆分独立审查 | `review_diff_by_file` | 🥈 |
| TS/JS 项目快速了解文件结构 | `summarize_file` | 🥉 |
| Swift/其他语言项目了解文件结构 | 直接用 Read + 人工扫描 | — |

### 3.3 性能数据

| 工具 | 平均 Token 消耗 | 模型 |
|------|---------------|------|
| `summarize_file` | 0（纯正则） | — |
| `compress_text` | ~1100 | Qwen3.6-35B-A3B-4bit |
| `compress_command_output` | ~1550 | Qwen3.6-35B-A3B-4bit |
| `review_diff` | ~1535 | Qwen3.6-35B-A3B-4bit |

> 模型为本地部署，无外部 API 调用延迟。

### 3.4 设计哲学

Wingman 的核心设计约束：

1. **辅助性而非权威性**——所有输出标 `is_authoritative: false`，强制回查原文
2. **诚实性优先**——uncertainties 和 limitations 显式列出，不假装知道不知道的事
3. **结构化输出**——findings/key_facts/risks 等字段消费友好，可被下游工具链解析
4. **本地优先**——优先使用本地模型，不依赖外部服务

---

## 四、未测试工具

### `aux_review_diff_by_file`

未测试。根据文档，其功能是将大 diff 按文件/hunk 拆分后独立分析再汇总。适合多文件大 diff。使用方式与 `aux_review_diff` 类似，但多了 `max_chars_per_file` 和 `max_files` 参数控制拆分粒度。

---

## 五、建议

1. **Swift 项目的 `summarize_file`**：考虑向 Wingman 贡献 Swift 正则模式，或直接使用 `compress_text` 替代（传入文件内容即可获得更好的语义摘要）
2. **CI 集成**：`compress_command_output` 可作为 CI pipeline 的日志后处理步骤，结构化输出便于自动告警
3. **pre-commit hook**：`review_diff` 可集成到 pre-commit hook 中自动扫描高风险变更
4. **大 diff 场景**：后续可测试 `review_diff_by_file` 在多文件重构中的表现
