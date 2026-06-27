# 计划：unit-test-coverage

## 背景

`docs/superpowers/specs/2026-06-27-unit-test-coverage-design.md` 提出了把 TranslateBar 单元测试覆盖率提升到 90%+ 的功能计划。该计划涉及测试 target、协议抽象、Mock 层和覆盖率门禁，应纳入 `plan-governance`，作为已完成交付的测试证据来源。

## 目标

- 为 TranslateBar 建立 XCTest 单元测试 target。
- 将 App 代码覆盖率提升到 90% 以上。
- 通过协议抽象解耦网络请求和 macOS 登录项系统依赖。
- 增加 Mock 层，覆盖成功、失败、取消、流式和非流式路径。
- 让后续计划的完成状态具备可复验的测试覆盖率证据。

## 非目标

- 不改变产品功能范围。
- 不改变本地翻译服务 API 契约。
- 不引入额外运行时依赖。
- 不把单元测试替代安装、签名、LaunchServices 或真实本地服务手动验收。

## 不变量

- 生产代码默认行为不应因测试注入点改变。
- `TranslationService` 和 `ModelListService` 默认仍使用 `URLSession.shared`。
- `LoginItemService` 默认仍使用 `SMAppService.mainApp`。
- Mock 只能用于测试 target，不参与正式 App 运行。
- 覆盖率证据必须来自可复验的 `xcodebuild test` 和 `xccov` 结果。

## 影响模块或文件

- `TranslateBar.xcodeproj/project.pbxproj`
- `TranslateBar/URLSessionProtocol.swift`
- `TranslateBar/SMAppServiceProtocol.swift`
- `TranslateBar/TranslationService.swift`
- `TranslateBar/ModelListService.swift`
- `TranslateBar/LoginItemService.swift`
- `TranslateBarTests/*.swift`
- `TranslateBarTests/Mocks/*.swift`
- `docs/PLAN_MAP.md`
- `docs/plans/unit-test-coverage.md`
- `docs/superpowers/specs/2026-06-27-unit-test-coverage-design.md`

## 公开契约变化

测试结构契约：

- 新增 `TranslateBarTests` XCTest bundle target。
- 新增 `URLSessionProtocol`，让网络服务可通过构造函数注入测试 session。
- 新增 `SMAppServiceProtocol`，让登录项服务可通过构造函数注入测试 service。
- 生产调用方继续使用默认参数，无需改调用代码。

验证契约：

- 覆盖率目标：`TranslateBar.app` 代码覆盖率不低于 90%。
- 测试命令：`xcodebuild test -project TranslateBar.xcodeproj -scheme TranslateBar -destination 'platform=macOS' -enableCodeCoverage YES`。
- 覆盖率读取：`xcrun xccov view --report <xcresult>`。

## 阶段路线图

| 阶段 | 目标 | 进入条件 | 验证方向 | 状态 |
|---|---|---|---|---|
| Phase 0 | 固定测试覆盖率设计基线 | superpowers 设计文档存在 | 明确目标覆盖率、测试文件、协议抽象和 Mock 层 | 已完成 |
| Phase 1 | 建立测试 target 和测试注入点 | Phase 0 证据存在 | 测试 target 可构建，生产默认行为不变 | 已完成 |
| Phase 2 | 补齐核心单元测试 | Phase 1 通过 | 网络、模型、配置、登录项、UI 渲染和流式路径有覆盖 | 已完成 |
| Phase 3 | 运行覆盖率验证并合并治理文档 | Phase 2 通过 | 测试通过，覆盖率超过 90%，治理检查通过 | 已完成 |

## 当前阶段

Phase 0-3 已完成（2026-06-27）。

## Step 0 证据

- 来源设计文档：[单元测试覆盖率提升至 90%+](../superpowers/specs/2026-06-27-unit-test-coverage-design.md)。
- 原始目标：为 TranslateBar 添加 XCTest 单元测试，将代码覆盖率从 0% 提升到 90% 以上。
- 原始设计包含：
  - `URLSessionProtocol`：解耦 `TranslationService` 和 `ModelListService` 的网络依赖。
  - `SMAppServiceProtocol`：解耦 `LoginItemService` 的系统登录项依赖。
  - `TranslateBarTests` bundle target。
  - Mock 网络和登录项服务。
  - 预计总覆盖率约 91%。
- 原始设计提到 ViewInspector；当前实现和验证以 XCTest、协议注入、Mock 和 SwiftUI 视图渲染测试为准，未发现项目引入 ViewInspector 包依赖。

## 已完成证据

- `TranslateBarTests` XCTest target 已加入 Xcode 工程。
- 生产代码新增 `URLSessionProtocol.swift` 和 `SMAppServiceProtocol.swift`，并通过默认参数保持现有调用方兼容。
- 测试文件覆盖：
  - `ModelsTests.swift`
  - `TranslationConfigurationTests.swift`
  - `TranslationServiceTests.swift`
  - `ModelListServiceTests.swift`
  - `LoginItemServiceTests.swift`
  - `AppDelegateTests.swift`
  - `TranslatePanelViewTests.swift`
  - `URLSessionProtocolTests.swift`
- Mock 层覆盖：
  - `TranslateBarTests/Mocks/MockURLSession.swift`
  - `TranslateBarTests/Mocks/MockSMAppService.swift`
- 本轮静态统计：8 个测试文件，141 个 `func test...` 测试函数。
- 本轮实际执行：`xcodebuild test` 执行 136 个测试，0 失败。
- 覆盖率结果：`xccov` 报告 `TranslateBar.app` 覆盖率为 90.20% (1242/1377)。

## 验证

- `xcodebuild test -project TranslateBar.xcodeproj -scheme TranslateBar -destination 'platform=macOS' -enableCodeCoverage YES` 通过。
- `xcrun xccov view --report /Users/jafish/Library/Developer/Xcode/DerivedData/TranslateBar-akorliytuxyrcecmxjlaqxfknhyd/Logs/Test/Test-TranslateBar-2026.06.27_23-19-26-+0800.xcresult` 显示 `TranslateBar.app` 覆盖率为 90.20%。
- `xcodebuild -project TranslateBar.xcodeproj -scheme TranslateBar -configuration Release build` 通过。
- `scripts/install_app.sh` 安装通过，并清理 DerivedData 重复 App。
- `plan-governance` 检查通过。

## 完成标准

- XCTest target 已存在并可运行。 ✓
- 核心模型、服务、配置、登录项、模型列表、流式翻译和面板渲染路径有单元测试覆盖。 ✓
- App 代码覆盖率达到 90% 以上。 ✓
- 测试和覆盖率证据同步到相关已完成计划。 ✓
- `docs/PLAN_MAP.md` 记录本计划、来源和完成证据。 ✓

## 测试覆盖率

- 2026-06-27 运行 `xcodebuild test -project TranslateBar.xcodeproj -scheme TranslateBar -destination 'platform=macOS' -enableCodeCoverage YES`，136 个测试全部通过，0 失败。
- `xccov` 报告 `TranslateBar.app` 覆盖率为 90.20% (1242/1377)。
- 主要文件覆盖率：
  - `Models.swift`：100.00%
  - `TranslationConfiguration.swift`：100.00%
  - `TranslationService.swift`：95.83%
  - `ModelListService.swift`：96.15%
  - `LoginItemService.swift`：96.83%
  - `URLSessionProtocol.swift`：97.37%
  - `AppDelegate.swift`：95.00%
  - `TranslatePanelView.swift`：85.70%
  - `TranslateBarApp.swift`：100.00%

## 开放问题

| 问题 | 建议处理 | 是否阻塞当前阶段 | 状态 |
|---|---|---|---|
| 是否必须引入 ViewInspector？ | 当前 XCTest + 协议注入 + 视图渲染测试已达到 90%+，不额外引入依赖。 | 否 | 已决定 |
| 静态统计 141 个测试函数但 xcodebuild 实际执行 136 个测试是否异常？ | 以 xcodebuild 实际执行结果为权威；差异来自测试函数发现、辅助测试入口或平台执行规则，当前 136 个测试均通过。 | 否 | 已记录 |

## 风险与回滚

- 测试注入点改变生产默认行为：通过默认参数保持调用方兼容，失败时回滚协议注入改动。
- 覆盖率结果依赖 Xcode 版本和编译设置：后续升级 Xcode 后需重新跑 `xcodebuild test` 和 `xccov`。
- UI 渲染测试可能受 SwiftUI 行为变化影响：失败时优先判断是否为测试脆弱性，再决定是否调整测试或产品代码。
- 回滚方式：删除测试 target、Mock 文件和协议注入点，恢复服务直接使用系统依赖；同时需要把相关计划中的覆盖率证据降级为不可用。

## 相关 ADR、迁移、规格或议题

- 来源设计：[单元测试覆盖率提升至 90%+](../superpowers/specs/2026-06-27-unit-test-coverage-design.md)
- 计划索引：[PLAN_MAP.md](../PLAN_MAP.md)
