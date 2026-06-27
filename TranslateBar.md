---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 4ac493c536677c9b88b69b7aa3aa5b7e_941d630c71d011f1986d525400d9a7a1
    ReservedCode1: YkAgpPz8ns6dsUKm5J93mSfQ0YVgVsHTESHH8SIr5WqVV27P/tDXQnJGGP0xatMTpcdLuG7Mz7JDDbh1Wfq24uHSK+VVjhIdv90D6HXlDbFlbSK/nwzhqmUZ6i2aV7iDv1HCQ6LTrDcDdnXWftZFMtwTEa34hsx5t4u+Cnd1EiPSGm/g+2l1xoiBpQA=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 4ac493c536677c9b88b69b7aa3aa5b7e_941d630c71d011f1986d525400d9a7a1
    ReservedCode2: YkAgpPz8ns6dsUKm5J93mSfQ0YVgVsHTESHH8SIr5WqVV27P/tDXQnJGGP0xatMTpcdLuG7Mz7JDDbh1Wfq24uHSK+VVjhIdv90D6HXlDbFlbSK/nwzhqmUZ6i2aV7iDv1HCQ6LTrDcDdnXWftZFMtwTEa34hsx5t4u+Cnd1EiPSGm/g+2l1xoiBpQA=
---

# TranslateBar — Swift 原生菜单栏翻译 App

> macOS 菜单栏实时翻译工具，调用本地 Hy-MT2-7B API，输入即翻译。

---

## 目录结构

```
TranslateBar/
├── TranslateBar.xcodeproj
├── Sources/
│   ├── main.swift                 # 入口
│   ├── AppDelegate.swift          # 菜单栏图标 + Popover
│   ├── TranslatePanelView.swift   # 翻译面板 UI
│   ├── TranslationService.swift   # API 调用 + 防抖
│   └── Assets.xcassets/           # 菜单栏图标 (AppIcon + translate_icon)
└── Info.plist                     # LSUIElement = YES
```

---

## 技术栈

| 层 | 方案 | 说明 |
|---|------|------|
| 菜单栏 | `NSStatusBar` + `NSStatusBarButton` | 系统原生，支持图标 |
| 弹出面板 | `NSPopover` + `NSHostingView` (SwiftUI) | 点击外部自动收起 |
| 输入框 | `TextEditor` (SwiftUI) | 可滚动多行 |
| 翻译结果 | `ScrollView` + `Text` | 只读显示 |
| 网络请求 | `URLSession` | 调 `http://127.0.0.1:8787` |
| 打包 | `xcodebuild archive` → `.app` | 双击运行 |

---

## 核心文件

### 1. `main.swift`

```swift
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // 隐藏 Dock 图标
app.run()
```

### 2. `AppDelegate.swift`

```swift
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "translate_icon")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
        }

        // Popover 面板
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient  // 点击外部自动关闭
        popover.contentViewController = NSHostingController(
            rootView: TranslatePanelView()
        )
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

### 3. `TranslatePanelView.swift`

```swift
import SwiftUI

struct TranslatePanelView: View {
    @StateObject private var service = TranslationService()
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 输入区域
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("输入")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("清空") {
                        inputText = ""
                        service.result = ""
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }

                TextEditor(text: $inputText)
                    .font(.system(size: 14))
                    .frame(height: 180)
                    .border(Color.secondary.opacity(0.2))
                    .onChange(of: inputText) { _ in
                        service.translate(text: inputText)
                    }
            }
            .padding(12)

            Divider()

            // 结果区域
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("翻译结果")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if service.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Spacer()
                    if !service.result.isEmpty {
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(service.result, forType: .string)
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }

                if service.errorMessage != nil {
                    Text(service.errorMessage!)
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if service.result.isEmpty {
                    Text("翻译结果将显示在这里")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        Text(service.result)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 500)
    }
}
```

### 4. `TranslationService.swift`

```swift
import Foundation
import Combine

class TranslationService: ObservableObject {
    @Published var result: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var currentTask: URLSessionDataTask?
    private var debounceTimer: Timer?

    private let apiURL = URL(string: "http://127.0.0.1:8787/v1/chat/completions")!
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        return URLSession(configuration: config)
    }()

    func translate(text: String) {
        // 防抖 0.5 秒
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performTranslation(text: text)
        }
    }

    private func performTranslation(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result = ""
            errorMessage = nil
            return
        }

        // 取消上一次未完成的请求
        currentTask?.cancel()
        currentTask = nil

        let (src, tgt) = detectLanguage(text)

        let prompt = """
        Translate the following text from \(src) to \(tgt). \
        Only output the translated result:

        \(text)
        """

        let body: [String: Any] = [
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.7,
            "top_p": 0.6,
            "top_k": 20,
            "repetition_penalty": 1.05,
            "max_tokens": 4096
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        isLoading = true
        errorMessage = nil

        currentTask = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }

            if let error = error as? URLError, error.code == .cancelled {
                return  // 被新请求抢占，静默
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String
            else {
                DispatchQueue.main.async {
                    self?.errorMessage = "翻译服务未启动，终端执行 fanyi"
                }
                return
            }

            DispatchQueue.main.async {
                self?.result = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        currentTask?.resume()
    }

    private func detectLanguage(_ text: String) -> (String, String) {
        let hasChinese = text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
        return hasChinese ? ("Chinese", "English") : ("English", "Chinese")
    }
}
```

### 5. `Info.plist`（关键配置）

```xml
<key>LSUIElement</key>
<true/>
```

> `LSUIElement = YES` 确保应用不出现在 Dock，仅菜单栏。

---

## 交互流程

```
[菜单栏图标 🌐]
    └─ 点击 → 弹出 Popover (400×500)
         ┌─────────────────────────────────┐
         │ 输入                         清空 │
         │ ┌─────────────────────────────┐ │
         │ │ (可滚动多行输入框)           │ │
         │ │                             │ │
         │ └─────────────────────────────┘ │
         │─────────────────────────────────│
         │ 翻译结果              🔄     复制 │
         │ ┌─────────────────────────────┐ │
         │ │ (只读，实时显示翻译结果)     │ │
         │ │                             │ │
         │ └─────────────────────────────┘ │
         └─────────────────────────────────┘

输入文本变化
    → 0.5s 防抖
    → POST localhost:8787/v1/chat/completions
    → 新请求到达 → cancel() 上一次 task
    → 响应返回 → 更新结果区
    → 不可达 → 显示 "翻译服务未启动，终端执行 fanyi"
```

---

## 开发步骤

| # | 步骤 | 说明 | 估时 |
|---|------|------|------|
| 1 | 新建项目 | Xcode → macOS → App，SwiftUI，删除 ContentView | 5min |
| 2 | 图标准备 | 18×18 / 36×36 @2x PNG 模板图，拖入 Assets | 10min |
| 3 | 编写 `main.swift` | 入口 + accessory 模式 | 5min |
| 4 | 编写 `AppDelegate.swift` | NSStatusBar + NSPopover | 20min |
| 5 | 编写 `TranslatePanelView.swift` | 输入框 + 结果区 UI | 25min |
| 6 | 编写 `TranslationService.swift` | 请求 + 防抖 + 取消 | 25min |
| 7 | 配置 `Info.plist` | LSUIElement = YES | 2min |
| 8 | 调试 | 启动 `fanyi` 后运行 App 测试 | 10min |
| 9 | 打包 | Product → Archive → Export .app | 5min |

总计约 **2 小时**，输出一个 3-5MB 的独立 `.app`。

---

## 打包命令（命令行方式）

```bash
cd TranslateBar
xcodebuild -project TranslateBar.xcodeproj \
  -scheme TranslateBar \
  -configuration Release \
  -archivePath ./build/TranslateBar.xcarchive \
  archive

xcodebuild -archivePath ./build/TranslateBar.xcarchive \
  -exportArchive \
  -exportPath ./build/ \
  -exportOptionsPlist exportOptions.plist
```

---

## 最终产出

| 文件 | 路径 | 说明 |
|------|------|------|
| TranslateBar.app | `./build/TranslateBar.app` | 双击运行，菜单栏图标 |
| 启动翻译服务 | 终端执行 `fanyi` | 先启动服务，再打开 App |

---

## 注意事项

- **必须先启动 `fanyi`**（翻译服务），否则 App 显示错误提示
- 图标使用**模板图**（`isTemplate = true`），系统自动适配深色/浅色模式
- 菜单栏空间有限，图标建议 18×18 像素纯色
- `NSPopover.behavior = .transient` 确保点击面板外部自动关闭
- 首包响应约 0.5-2 秒，取决于文本长度和模型推理速度
*（内容由AI生成，仅供参考）*
