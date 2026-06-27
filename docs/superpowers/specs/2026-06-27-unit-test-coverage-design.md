# 单元测试覆盖率提升至 90%+ — 设计文档

> 日期：2026-06-27 | 框架：XCTest + ViewInspector | 目标覆盖率：≥90%

## 一、目标

为 TranslateBar 项目添加 XCTest 单元测试，将代码覆盖率从 0% 提升到 90% 以上。

## 二、协议抽象层

为解耦系统依赖，新增两个协议文件：

### URLSessionProtocol（新增）
```swift
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse)
}
extension URLSession: URLSessionProtocol {}
```

`TranslationService` 和 `ModelListService` 通过构造函数注入（默认 `URLSession.shared`）。

### SMAppServiceProtocol（新增）
```swift
protocol SMAppServiceProtocol {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}
extension SMAppService: SMAppServiceProtocol {}
```

`LoginItemService` 通过构造函数注入（默认 `SMAppService.mainApp`）。

### 生产代码改动
每处仅一行——init 加带默认值的参数，现有调用方零改动。

## 三、测试文件清单

| 文件 | 预计覆盖率 | 测试内容 |
|------|----------|---------|
| ModelsTests.swift | 98% | Codable 编解码、CodingKeys 映射、TranslationMode 逻辑、TranslationError 描述 |
| TranslationConfigurationTests.swift | 96% | 默认值、current(from:)、endpoint/modelsEndpoint 计算属性 |
| TranslationServiceTests.swift | 88% | translate/cancel/makePrompt/makeConfiguration/parseErrorMessage/readableError/performTranslation 流式+非流式 |
| ModelListServiceTests.swift | 90% | fetchModels 成功/失败/取消、isLoading 生命周期 |
| LoginItemServiceTests.swift | 88% | refresh/toggle/enable/disable、LoginItemError |
| AppDelegateTests.swift | 65% | statusItem/popover 创建、togglePopover |
| TranslatePanelViewTests.swift | 78% | header/settings/input/result 各区域渲染与交互 |

**预期总覆盖率：~91%**

## 四、Mock 层

```
TranslateBarTests/Mocks/
├── MockURLSession.swift    — 模拟 URLSession data/bytes 方法
└── MockSMAppService.swift  — 模拟 SMAppService status/register/unregister
```

## 五、依赖

- ViewInspector（SwiftPM，from: "0.10.1"）— SwiftUI View 层级探查
- XCTest（系统内置）— 测试框架

## 六、Xcode 项目改动

- 新增 `TranslateBarTests` bundle target
- 新增 2 个协议文件到 TranslateBar group
- 新增 9 个测试相关文件到 TranslateBarTests group
