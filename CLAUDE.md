# CLAUDE.md

本文件为 Claude Code 提供在 TranslateBar 仓库中工作的指引。

## 项目概述

TranslateBar 是一个 macOS 菜单栏翻译 App。隐藏在菜单栏中（`LSUIElement = true`），点击图标弹出 `NSPopover`，调用本地 OpenAI Chat Completions 兼容服务（`http://127.0.0.1:8787/v1/chat/completions`）和模型 `/Users/jafish/Documents/models/Hy-MT2-7B-4bit` 完成中英互译。

## 构建与安装

```bash
# 构建（Debug 或 Release）
xcodebuild -project TranslateBar.xcodeproj -scheme TranslateBar -configuration Release build

# 正式安装：构建 → 安装到 ~/Applications → 清理重复产物 → 重新注册 LaunchServices
./scripts/install_app.sh
```

**重要**：裸跑 `xcodebuild build`（或 Xcode IDE 中 Build）会将 DerivedData 中的产物注册到 LaunchServices，导致 Launchpad 出现重复项。正式安装始终用 `./scripts/install_app.sh`——它会先用 `lsregister -u` 卸载过期条目再删除文件，最后只注册 `~/Applications/TranslateBar.app`。

## 架构

```
TranslateBarApp.swift          — @main 入口，通过 @NSApplicationDelegateAdaptor 桥接 AppDelegate
  └─ AppDelegate.swift         — NSStatusBar 图标 + NSPopover + NSHostingController(rootView: TranslatePanelView())
       └─ TranslatePanelView.swift — 主界面：header（自动翻译开关、模式选择、退出/设置按钮）、
                                      设置区（endpoint/model 配置、登录项开关）、
                                      输入区（TextEditor + 清空/翻译按钮）、
                                      结果区（翻译结果、复制按钮、错误显示）
            ├─ TranslationService.swift  — @MainActor ObservableObject，调用本地 API，基于 UUID 的任务取消
            ├─ TranslationConfiguration.swift — UserDefaults 持久化的 endpoint/model 配置
            ├─ LoginItemService.swift    — SMAppService.mainApp 封装（enable/disable/refresh），中文错误信息
            └─ Models.swift              — ChatCompletionRequest/Response、ChatMessage、TranslationMode、TranslationError
```

### 关键机制

- **任务取消**：`TranslationService` 使用 `currentTranslateId: UUID?` 识别过期任务。每次新翻译前取消上一个 `Task` 并分配新 UUID；写入结果前检查 `currentTranslateId == id`，防止旧任务覆写新任务的结果。
- **防抖 300ms**：自动翻译模式下，输入变化后等待 300ms 再发起请求。
- **配置**：`TranslationConfiguration` 通过 `@AppStorage` 读写 `UserDefaults`（键名 `translationEndpoint`、`translationModel`），`current()` 工厂方法提供默认值。
- **自动语言检测**：`TranslationMode.auto` 通过检测 CJK 统一汉字区间（`0x4E00–0x9FFF`）判断输入是否含中文——有中文 → 译成英文，否则 → 译成中文。
- **登录项**：`LoginItemService` 封装 `SMAppService.mainApp`，默认关闭，Toggle 在设置区，错误以中文提示。

### 部署目标

- macOS 15.0（`MACOSX_DEPLOYMENT_TARGET = 15.0`）
- Swift 5.0
- arm64（Apple Silicon）
- 签名：自动，Hardened Runtime 开启

## 开发治理

本项目采用计划驱动开发。计划索引、依赖关系和完成证据见 `docs/PLAN_MAP.md`。改变 API 契约、打包行为或启动行为的多步骤修改需要走计划流程，一次性小修不在此列。

已完成计划：
- `translatebar-v1` — 核心菜单栏翻译 App
- `service-settings-and-install` — 可配置 endpoint/model，安装到 ~/Applications
- `install-cleanup-and-login-item` — 构建/安装/清理脚本，登录项开关
- `model-list-selection` — 从 `/v1/models` 读取并选择模型
- `streaming-translation` — 可选 SSE 流式翻译输出
- `unit-test-coverage` — XCTest 覆盖率提升到 90%+

原始规格基线见 `TranslateBar.fixed.md`。

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **TranslateBar** (713 symbols, 1756 relationships, 19 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/TranslateBar/context` | Codebase overview, check index freshness |
| `gitnexus://repo/TranslateBar/clusters` | All functional areas |
| `gitnexus://repo/TranslateBar/processes` | All execution flows |
| `gitnexus://repo/TranslateBar/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
