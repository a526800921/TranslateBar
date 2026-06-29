# DeepSeek 云端模型支持实施文档

## 实施目标

为 TranslateBar 增加 DeepSeek 云端模型支持，同时保留现有本地模型行为。

目标云端配置：

- API Base URL：`https://api.deepseek.com/v1`
- Chat endpoint：`https://api.deepseek.com/v1/chat/completions`
- Model：`deepseek-v4-flash`
- API key 来源：用户在 TranslateBar 设置中手动填写
- API key 持久化：使用 `UserDefaults` 保存，第一版不使用 Keychain
- 关闭思考：本地和云端请求体都加入 `chat_template_kwargs.enable_thinking = false`

## 实施原则

1. 默认行为不变：未切换云端时继续使用本地模型。
2. API key 不写入仓库、不进入日志；设置 UI 使用 `SecureField` 输入，避免明文展示。
3. 本地 provider 不发送 `Authorization` header。
4. 本地和云端 provider 都发送 `chat_template_kwargs.enable_thinking=false`，确保关闭思考。
5. 云端 provider 的非流式和流式请求都必须带鉴权和关闭思考参数。
6. 不重写 `TranslationService` 的防抖、取消、UUID 任务身份校验和 loading 状态机。
7. “恢复默认”不自动清空 API key，API key 通过单独的“清除 API Key”操作删除。

## 涉及文件

- `TranslateBar/TranslationConfiguration.swift`
- `TranslateBar/Models.swift`
- `TranslateBar/TranslationService.swift`
- `TranslateBar/ModelListService.swift`
- `TranslateBar/TranslatePanelView.swift`
- `TranslateBarTests/TranslationConfigurationTests.swift`
- `TranslateBarTests/ModelsTests.swift`
- `TranslateBarTests/TranslationServiceTests.swift`
- `TranslateBarTests/ModelListServiceTests.swift`
- `TranslateBarTests/Mocks/MockURLSession.swift`

## 数据结构设计

### Provider 枚举

新增：

```swift
enum TranslationProvider: String, CaseIterable, Identifiable {
    case local
    case deepseek

    var id: String { rawValue }
}
```

建议显示名：

```swift
var displayName: String {
    switch self {
    case .local:
        return "本地"
    case .deepseek:
        return "DeepSeek"
    }
}
```

### TranslationConfiguration 新字段

新增 key：

```swift
static let provider = "translationProvider"
static let cloudAPIKey = "translationCloudAPIKey"
static let cloudEndpoint = "translationCloudEndpoint"
static let cloudModel = "translationCloudModel"
static let cloudDisableThinking = "translationCloudDisableThinking"
static let cloudTimeoutSeconds = "translationCloudTimeoutSeconds"
```

新增默认值：

```swift
static let defaultProvider = TranslationProvider.local
static let defaultCloudEndpoint = "https://api.deepseek.com/v1/chat/completions"
static let defaultCloudModel = "deepseek-v4-flash"
static let defaultCloudDisableThinking = true
static let defaultCloudTimeoutSeconds = 30.0
```

配置实例建议包含：

```swift
let provider: TranslationProvider
let endpointString: String
let model: String
let streamingEnabled: Bool
let apiKey: String?
let disableThinking: Bool
let timeoutInterval: TimeInterval
```

### API key 持久化

第一版使用 `UserDefaults` 保存 API key，不读取 `/Users/jafish/Documents/work/Wingman/.env`，也不接入 Keychain。

```swift
let apiKey = defaults.string(forKey: Keys.cloudAPIKey)?
    .trimmingCharacters(in: .whitespacesAndNewlines)
```

规则：

- API key 只用于构造 `Authorization` header。
- API key 允许为空；仅在 DeepSeek provider 发起翻译或读取模型列表时校验。
- 错误提示、日志、测试失败信息不得包含 API key 原文。
- UI 用 `SecureField` 输入 API key。
- “恢复默认”不清空 API key；另设“清除 API Key”按钮。

## 请求模型变更

### ChatCompletionRequest

新增可选字段：

```swift
let chatTemplateKwargs: ChatTemplateKwargs?
```

新增结构：

```swift
struct ChatTemplateKwargs: Encodable {
    let enableThinking: Bool

    enum CodingKeys: String, CodingKey {
        case enableThinking = "enable_thinking"
    }
}
```

`ChatCompletionRequest.CodingKeys` 增加：

```swift
case chatTemplateKwargs = "chat_template_kwargs"
```

构造规则：

- 本地 provider：`ChatTemplateKwargs(enableThinking: false)`
- DeepSeek provider：`ChatTemplateKwargs(enableThinking: false)`

## TranslationService 实施步骤

### 1. 配置校验

`makeConfiguration` 增加 DeepSeek 校验：

- endpoint 不能为空。
- model 不能为空。
- provider 为 `.deepseek` 时，API key 必须存在且非空。
- API key 缺失时返回新增错误。

新增错误：

```swift
case missingAPIKey
```

错误文案：

```text
DeepSeek API Key 未配置，请在设置中填写 API Key。
```

### 2. 请求构建

建议抽出私有 helper，减少流式/非流式重复：

```swift
private func makeRequest(
    endpoint: URL,
    configuration: TranslationConfiguration,
    stream: Bool,
    prompt: String
) throws -> URLRequest
```

该 helper 负责：

- 设置 `POST`
- 设置 timeout
- 设置 `Content-Type`
- DeepSeek provider 设置 `Authorization`
- 编码 `ChatCompletionRequest`

### 3. 非流式路径

`performNonStreamingTranslation` 保持原状态流程，只把手写 request/payload 替换为 `makeRequest(...)`。

### 4. 流式路径

`performStreamingTranslation` 同样替换为 `makeRequest(...)`。

### 5. 错误提示

`readableError` 中网络连接错误不要固定写“本地翻译服务”。

建议按当前配置输出：

- 本地：`无法连接本地翻译服务，请确认 <endpoint> 可访问。`
- DeepSeek：`无法连接 DeepSeek 翻译服务，请检查网络、API key 或 <endpoint>。`

## ModelListService 实施步骤

### 1. 模型列表 endpoint

当前 `modelsEndpoint` 从 `/v1/chat/completions` 推导 `/v1/models`，DeepSeek endpoint 同样兼容。

### 2. 鉴权

请求 `/v1/models` 时：

- DeepSeek provider 带 `Authorization: Bearer <apiKey>`
- 本地 provider 不带 Authorization

### 3. API key 缺失

DeepSeek provider 缺 key 时，直接设置错误：

```text
DeepSeek API Key 未配置，无法读取模型列表。
```

不发网络请求。

## TranslatePanelView 实施步骤

### 1. 增加 provider AppStorage

```swift
@AppStorage(TranslationConfiguration.Keys.provider) private var provider = TranslationProvider.local.rawValue
```

UI 使用 `Picker` 或 segmented control：

- 本地
- DeepSeek

### 2. 设置区展示策略

本地模式：

- 显示服务地址
- 显示模型路径/模型列表
- 显示流式输出

DeepSeek 模式：

- 显示 DeepSeek endpoint，只读或可编辑均可，第一版建议可编辑但默认固定。
- 显示模型：默认 `deepseek-v4-flash`
- 使用 `SecureField` 输入 API key，并持久化保存到 `UserDefaults`
- 显示“关闭思考”开关，默认开启
- 不显示 API key 明文；可提供“清除 API Key”按钮
- 可显示 key 状态：`已检测到 API Key` / `未检测到 API Key`

### 3. 切换 provider

切换 provider 时：

- `service.cancel()`
- 清空错误状态或保留当前输入。
- 下一次翻译读取新配置。

## 测试实施

### MockURLSession

增加记录最后请求：

```swift
var lastDataRequest: URLRequest?
var lastBytesRequest: URLRequest?
```

在 `data(for:)` 和 `bytesStream(for:)` 中赋值，便于断言 header/body。

### TranslationConfigurationTests

新增测试：

1. `test_current_defaultProviderIsLocal`
2. `test_current_deepseekDefaults`
3. `test_current_deepseekReadsAPIKeyFromDefaults`
4. `test_current_deepseekTrimsAPIKey`
5. `test_current_deepseekMissingAPIKey`
6. `test_restoreDefaultsDoesNotClearAPIKey`

### ModelsTests

新增测试：

1. `test_requestEncode_withDisableThinking`
2. `test_requestEncode_disableThinkingUsesSnakeCase`

### TranslationServiceTests

新增测试：

1. `test_deepseekNonStreaming_addsAuthorizationHeader`
2. `test_deepseekNonStreaming_disablesThinking`
3. `test_deepseekStreaming_addsAuthorizationHeader`
4. `test_localRequest_doesNotAddAuthorizationHeader`
5. `test_localRequest_disablesThinking`
6. `test_deepseekMissingAPIKey_showsReadableError`

### ModelListServiceTests

新增测试：

1. `test_fetchModels_deepseekAddsAuthorizationHeader`
2. `test_fetchModels_localDoesNotAddAuthorizationHeader`
3. `test_fetchModels_deepseekMissingAPIKeyDoesNotRequest`

## 验证命令

```bash
xcodebuild test \
  -project TranslateBar.xcodeproj \
  -scheme TranslateBar \
  -destination 'platform=macOS'
```

GitNexus 收尾检查：

```text
detect_changes({ repo: "TranslateBar", scope: "all" })
```

## 手动验收

1. 启动 App。
2. 默认本地模式翻译仍可用。
3. 切换到 DeepSeek。
4. 输入中文，确认输出英文。
5. 输入英文，确认输出中文。
6. 打开流式输出，确认 DeepSeek 流式路径可用或给出可读错误。
7. 清空设置中的 API key，确认 UI 显示可诊断错误且不泄漏 key。
8. 重新填写 API key，确认翻译恢复。

## 完成条件

- 本地模型默认行为不变。
- DeepSeek 非流式请求成功。
- DeepSeek 流式请求成功或错误可诊断。
- DeepSeek 请求包含 `Authorization` header。
- DeepSeek 请求体包含 `chat_template_kwargs.enable_thinking=false`。
- 本地请求不包含 `Authorization` header。
- 本地请求体包含 `chat_template_kwargs.enable_thinking=false`。
- API key 持久化保存在 `UserDefaults`，但不进入仓库、UI 明文、日志或测试快照。
- 单元测试通过。
- `detect_changes()` 显示影响范围符合预期。
- `PLAN_MAP.md` 与本计划状态同步。
