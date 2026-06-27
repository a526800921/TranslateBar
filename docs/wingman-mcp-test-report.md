# Wingman MCP 测试报告

**日期**：2026-06-27（三轮测试：初始 → 更新 → 再更新）  
**测试范围**：全部 5 个 Wingman MCP 工具  
**使用模型**：`/Users/jafish/Documents/models/Qwen3.6-35B-A3B-4bit`（本地）

---

## 测试结果总览（最终状态）

| 工具 | 可用 | 模型调用 | 输出质量 | 备注 |
|------|:----:|:--------:|:--------:|------|
| `aux_summarize_file` | ✅ | ❌ Swift 跳过 | ⚠️ heuristic | 非 TS/JS 走 regex fallback，参数提取已改进 |
| `aux_compress_text` | ✅ | ✅ | ✅ 良好 | 无幻觉，日志提取准确 |
| `aux_review_diff` | ✅ | ✅ | ✅ 良好 | 日期幻觉已修复 |
| `aux_compress_command_output` | ✅ | ✅ | ⚠️ 格式相关 | tsc 完美，xcodebuild test 全绿仍标 failure |
| `aux_review_diff_by_file` | ✅ | ✅ | ✅ 良好 | 多文件分拆、top_risks 汇总 |

---

## 已修复（R1 → R3）

### ✅ Swift 函数参数提取

regex fallback 已改进，参数数量基本正确：

| 函数 | 实际 | R1 | R3 |
|------|------|:--:|:--:|
| `translate` | `(text:mode:)` | 0 ❌ | **2** ✅ |
| `makePrompt` | `(text:sourceLang:targetLang:)` | 0 ❌ | **2** ✅ |
| `parseErrorMessage` | `(data:)` | 0 ❌ | **1** ✅ |
| `readableError` | `(error:message:)` | 0 ❌ | **1** ✅ |

### ✅ 日期幻觉

R1 将 `2026-06-27` 误判为 future date typo，R2 起不再出现。

---

## 仍未修复

### ❌ xcodebuild test 全绿 → `kind: "test_failure"`

三轮测试全部复现。关键线索：

```
detector_hint:        "generic_log"      ← detector 不认识 xcodebuild 格式
model_detected_kind:  "test_output"      ← 模型识别对了
kind:                 "test_failure"     ← schema 缺 test_success 桶
kind_mismatch:        true               ← 工具自知矛盾
```

**对比 tsc 输入**——`detector_hint: "tsc_error"`，`kind: "type_error"`，`kind_mismatch: false`——完美。说明管道没问题，是两层短板叠加：

1. detector 没有 xcodebuild 格式规则，落到 `generic_log`
2. 结构化 schema 只有 `test_failure`，没有 `test_success` 或 `test_result`

**影响**：仅限 xcodebuild/非主流 test runner 输出。tsc、eslint 等标准工具没问题。消费时看 `reported_totals.failures` 即可规避。

---

| 维度 | 评价 |
|------|------|
| **工具可用性** | 5/5 全部连通 |
| **输出可信度** | tsc/eslint 类可靠；xcodebuild 需看 `reported_totals` |
| **Swift 项目适配** | `aux_summarize_file` 仅 heuristic，参数量基本对，semantic 不行 |
| **模型能力** | Qwen 35B-A3B-4bit，理解力够用但非完美；schema 缺口比模型问题更大 |

### 适用场景

| 场景 | 适合度 |
|------|:------:|
| TS/JS diff checklist 审查 | ✅ |
| 日志/命令输出结构化 | ✅ |
| 多文件 diff 分拆审查 | ✅ |
| tsc/eslint 输出压缩 | ✅ |
| Swift 代码 semantic 分析 | ❌ |
| xcodebuild test 分类 | ⚠️ 看 totals 别信 kind |

