# TranslateBar - macOS 菜单栏本地翻译 App 方案

> 目标：在 macOS 屏幕右上角菜单栏常驻一个翻译图标，点击后弹出翻译面板，调用本地 Hy-MT2-7B-4bit 服务完成中英互译。

---

## 1. 目标体验

- App 启动后不出现在 Dock，只在菜单栏显示一个翻译图标。
- 点击菜单栏图标，弹出一个 400x500 左右的翻译窗口。
- 提供“自动翻译”开关，默认启用；关闭后只通过按钮或 `Cmd + Return` 手动翻译。
- 只支持中文和英文互译，不做其他语言入口。
- 翻译结果可复制。
- 本地模型服务不可用、接口不兼容或返回错误时，面板中显示可诊断的错误信息。
- 弹窗顶部提供“退出”按钮，避免 `LSUIElement` App 无法从 Dock 退出。
- 第一版不支持开机自启动，后续稳定后再加登录项开关。

---

## 2. 前置假设

本地翻译服务已启动在：

```text
http://127.0.0.1:8787
```

已验证它提供 OpenAI Chat Completions 兼容接口：

```text
POST /v1/chat/completions
```

已验证模型列表接口返回的真实模型 id 是：

```text
/Users/jafish/Documents/models/Hy-MT2-7B-4bit
```

注意：短名 `Hy-MT2-7B-4bit` 会被服务当成 Hugging Face repo id 解析，并触发远程仓库查找错误。因此 App 中应显式使用完整本地路径作为 `model`。

---

## 3. 接口探测

先运行：

```bash
curl http://127.0.0.1:8787/v1/models
```

已验证返回：

```json
{
  "object": "list",
  "data": [
    {
      "id": "/Users/jafish/Documents/models/Hy-MT2-7B-4bit",
      "object": "model"
    }
  ]
}
```

继续测试 chat 接口：

```bash
curl http://127.0.0.1:8787/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "/Users/jafish/Documents/models/Hy-MT2-7B-4bit",
    "messages": [
      {
        "role": "user",
        "content": "Translate the following text to Chinese. Only output the translated result:\n\nhello world"
      }
    ],
    "temperature": 0.1,
    "max_tokens": 256,
    "stream": false
  }'
```

已验证返回结构：

```json
{
  "choices": [
    {
      "message": {
        "content": "你好，世界"
      }
    }
  ]
}
```

如果返回字段不是 `choices[0].message.content`，需要先按实际响应修改 `TranslationService` 的解析逻辑。

已验证结果位于：

```text
choices[0].message.content
```

补充：不传 `model` 时服务也能返回结果，响应中的模型名会显示为 `default_model`。为了避免未来服务配置变化，App 第一版仍建议显式传完整模型 id。

---

## 4. 推荐目录结构

```text
TranslateBar/
├── TranslateBar.xcodeproj
├── TranslateBar/
│   ├── TranslateBarApp.swift
│   ├── AppDelegate.swift
│   ├── TranslatePanelView.swift
│   ├── TranslationService.swift
│   ├── Models.swift
│   ├── Assets.xcassets/
│   └── Info.plist
└── TranslateBar.fixed.md
```

说明：

- `TranslateBarApp.swift`：SwiftUI App 入口，桥接 `AppDelegate`。
- `AppDelegate.swift`：创建菜单栏图标和 Popover。
- `TranslatePanelView.swift`：输入框、模式选择、结果区、复制、退出。
- `TranslationService.swift`：请求本地模型、取消上一次请求、错误诊断。
- `Models.swift`：请求和响应结构体，避免手写 `[String: Any]` 和脆弱 JSON 解析。
- `Info.plist`：配置 `LSUIElement = YES`。

---

## 5. 技术方案

| 模块 | 方案 | 说明 |
|---|---|---|
| 菜单栏 | `NSStatusBar` | macOS 原生菜单栏常驻图标 |
| 弹窗 | `NSPopover` + `NSHostingController` | 点击图标弹出 SwiftUI 面板 |
| UI | SwiftUI | 简洁、够用、维护成本低 |
| 网络 | `URLSession` + `async/await` | 比回调更容易处理取消和错误 |
| API | OpenAI Chat Completions 兼容格式 | 调用 `127.0.0.1:8787/v1/chat/completions` |
| App 类型 | `LSUIElement` | 隐藏 Dock 图标 |

---

## 6. 核心实现

### 6.1 `TranslateBarApp.swift`

```swift
import SwiftUI

@main
struct TranslateBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

### 6.2 `AppDelegate.swift`

```swift
import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "TranslateBar")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover)
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: TranslatePanelView())
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

### 6.3 `Models.swift`

```swift
import Foundation

struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stream
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Decodable {
    let choices: [ChatChoice]
}

struct ChatChoice: Decodable {
    let message: ChatMessage?
    let text: String?
}

struct APIErrorResponse: Decodable {
    let error: APIErrorDetail?
}

struct APIErrorDetail: Decodable {
    let message: String?
    let type: String?
}
```

### 6.4 `TranslationService.swift`

```swift
import Foundation

@MainActor
final class TranslationService: ObservableObject {
    @Published var result = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let endpoint = URL(string: "http://127.0.0.1:8787/v1/chat/completions")!
    private let model = "/Users/jafish/Documents/models/Hy-MT2-7B-4bit"
    private var currentTask: Task<Void, Never>?

    func translate(text: String, mode: TranslationMode) {
        currentTask?.cancel()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            result = ""
            errorMessage = nil
            isLoading = false
            return
        }

        currentTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else {
                return
            }

            await performTranslation(text: trimmedText, mode: mode)
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
    }

    private func performTranslation(text: String, mode: TranslationMode) async {
        isLoading = true
        errorMessage = nil

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload = ChatCompletionRequest(
                model: model,
                messages: [
                    ChatMessage(role: "user", content: makePrompt(text: text, mode: mode))
                ],
                temperature: 0.1,
                topP: 0.6,
                maxTokens: 4096,
                stream: false
            )

            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else {
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TranslationError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: parseErrorMessage(from: data)
                )
            }

            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let content = decoded.choices.first?.message?.content ?? decoded.choices.first?.text
            let translatedText = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if translatedText.isEmpty {
                throw TranslationError.emptyContent
            }

            result = translatedText
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readableError(error)
        }

        isLoading = false
    }

    private func makePrompt(text: String, mode: TranslationMode) -> String {
        let target = mode.targetDescription(for: text)

        return """
        Translate the following text to \(target).
        Only output the translated result. Do not explain, summarize, add markdown, or wrap the answer in quotes.

        \(text)
        """
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
           let message = apiError.error?.message,
           !message.isEmpty {
            return message
        }

        return String(data: data, encoding: .utf8)?.prefix(500).description ?? "Unknown error"
    }

    private func readableError(_ error: Error) -> String {
        if let translationError = error as? TranslationError {
            return translationError.localizedDescription
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost:
                return "无法连接本地翻译服务，请确认 127.0.0.1:8787 已启动。"
            case .timedOut:
                return "翻译请求超时，模型可能仍在推理或文本过长。"
            default:
                return "网络错误：\(urlError.localizedDescription)"
            }
        }

        return "翻译失败：\(error.localizedDescription)"
    }
}

enum TranslationMode: String, CaseIterable, Identifiable {
    case auto = "自动"
    case zhToEn = "中译英"
    case enToZh = "英译中"

    var id: String { rawValue }

    func targetDescription(for text: String) -> String {
        switch self {
        case .zhToEn:
            return "English"
        case .enToZh:
            return "Chinese"
        case .auto:
            return containsChinese(text) ? "English" : "Chinese"
        }
    }

    private func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }
}

enum TranslationError: LocalizedError {
    case invalidResponse
    case emptyContent
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "翻译服务返回了无效响应。"
        case .emptyContent:
            return "翻译服务返回了空结果，请检查模型输出格式。"
        case let .httpError(statusCode, message):
            return "翻译服务返回 HTTP \(statusCode)：\(message)"
        }
    }
}
```

### 6.5 `TranslatePanelView.swift`

```swift
import AppKit
import SwiftUI

struct TranslatePanelView: View {
    @StateObject private var service = TranslationService()
    @State private var inputText = ""
    @State private var mode: TranslationMode = .auto
    @State private var autoTranslate = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            inputArea
            Divider()
            resultArea
        }
        .frame(width: 420, height: 520)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Toggle("自动翻译", isOn: $autoTranslate)
                .toggleStyle(.switch)

            Picker("", selection: $mode) {
                ForEach(TranslationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, newMode in
                if autoTranslate {
                    service.translate(text: inputText, mode: newMode)
                }
            }

            Button("退出") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("输入")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("清空") {
                    inputText = ""
                    service.cancel()
                    service.result = ""
                    service.errorMessage = nil
                }
                .disabled(inputText.isEmpty)

                Button("翻译") {
                    service.translate(text: inputText, mode: mode)
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }

            TextEditor(text: $inputText)
                .font(.system(size: 14))
                .frame(height: 170)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )
                .onChange(of: inputText) { _, newValue in
                    if autoTranslate {
                        service.translate(text: newValue, mode: mode)
                    }
                }
        }
        .padding(12)
    }

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("翻译结果")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if service.isLoading {
                    ProgressView()
                        .scaleEffect(0.65)
                }

                Spacer()

                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(service.result, forType: .string)
                }
                .disabled(service.result.isEmpty)
            }

            Group {
                if let errorMessage = service.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else if service.result.isEmpty {
                    Text("翻译结果将显示在这里")
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        Text(service.result)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .font(.system(size: 14))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
    }
}
```

### 6.6 `Info.plist`

```xml
<key>LSUIElement</key>
<true/>
```

如果使用 Xcode 的 build settings 管理 Info.plist，也可以在 `Info` 配置里添加：

```text
Application is agent (UIElement) = YES
```

---

## 7. 行为流程

```text
启动 App
  -> 隐藏 Dock 图标
  -> 菜单栏创建 TranslateBar 图标

点击图标
  -> 展示 NSPopover
  -> 用户输入文本

输入变化
  -> 取消上一次未完成任务
  -> 等待 700ms 防抖
  -> POST /v1/chat/completions
  -> 解析 choices[0].message.content
  -> 更新结果

请求失败
  -> 展示 HTTP 状态码、接口错误或网络错误

点击退出
  -> NSApp.terminate(nil)
```

---

## 8. 当前方案中的关键决策

### 自动翻译开关

复制粘贴翻译是主要使用方式，因此第一版默认启用自动翻译，不按文本长度判断。用户关闭“自动翻译”后，输入变化不会请求模型，只能通过“翻译”按钮或 `Cmd + Return` 手动触发。

自动翻译仍保留 700ms 防抖，连续粘贴或编辑时只发送最后一次请求。

### 使用 `stream: false`

第一版先不用流式输出，减少解析复杂度。等基础版本稳定后，再考虑支持 Server-Sent Events 流式结果。

### 使用 SF Symbol 图标

第一版用系统图标 `character.bubble`，不用单独准备 PNG。需要自定义品牌图标时，再加入 `Assets.xcassets`。

### 保留模式选择

`自动 / 中译英 / 英译中` 覆盖中英互译场景。自动检测只按中文字符判断：包含中文字符时翻译成英文，否则翻译成中文。

---

## 9. 待确认问题

继续推进前，建议先确认这几件事：

1. 8787 服务是否支持 `/v1/models`？已确认：支持。
2. `chat/completions` 请求是否必须传 `model`？已确认：不传也能用，但建议显式传完整模型 id。
3. 模型真实名称是否就是 `Hy-MT2-7B-4bit`？已确认：不是，真实 id 是 `/Users/jafish/Documents/models/Hy-MT2-7B-4bit`。
4. 返回结果是否位于 `choices[0].message.content`？已确认：是。
5. 需要纯中英互译，还是也要支持日文、韩文或其他语言？已确认：只做中英互译。
6. 想要输入即翻译，还是长文本必须手动点“翻译”？已确认：提供“自动翻译”开关，默认启用，不按文本长度判断；关闭后手动翻译。
7. 退出入口放在哪里？已确认：弹窗顶部放“退出”按钮。
8. 是否要支持开机自启动？已确认：第一版不做。

以上问题均已确认，当前文档可作为第一版实现基线。

---

## 10. 实施顺序

1. 用 `curl` 确认本地接口请求体和返回体。
2. 创建 macOS SwiftUI App 工程。
3. 实现菜单栏图标和 Popover。
4. 实现静态 UI。
5. 接入 `TranslationService`。
6. 增加错误显示、复制、清空、退出。
7. 测试服务未启动、短文本、长文本、连续输入、取消请求。
8. 打 Release 包。

第一版暂不实现开机自启动。

---

## 11. 第一版验收标准

- 双击 App 后 Dock 不出现图标。
- 菜单栏右上角出现翻译图标。
- 点击图标可以打开和关闭翻译面板。
- 输入 `hello world` 能返回中文翻译。
- 输入中文能返回英文翻译。
- “自动翻译”默认开启，输入变化后会自动请求翻译。
- 关闭“自动翻译”后，输入变化不会请求，点击“翻译”或按 `Cmd + Return` 后才请求。
- UI 只提供 `自动 / 中译英 / 英译中`。
- 本地服务未启动时显示明确错误。
- 点击复制后，系统剪贴板中是翻译结果。
- 点击退出后 App 进程结束。
- 第一版不提供开机自启动设置。
