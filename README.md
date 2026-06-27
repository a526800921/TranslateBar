# TranslateBar

TranslateBar 是一个 macOS 菜单栏翻译 App。它通过本机 OpenAI Chat Completions 兼容服务调用本地翻译模型，适合把常用中英互译固定在菜单栏里使用。

## 当前功能

- 菜单栏常驻：App 启动后显示在 macOS 菜单栏，不占用 Dock 主窗口。
- 中英互译：支持自动判断、中译英、英译中三种模式。
- 自动翻译：输入内容变化后会自动防抖触发翻译，也可以手动点击“翻译”。
- 结果复制：翻译结果可一键复制到剪贴板。
- 服务配置：可在设置区修改 Chat Completions endpoint 和模型路径。
- 模型列表：可从当前服务的 `/v1/models` 读取模型列表，并选择 `data[].id` 作为当前模型。
- 流式输出：可在设置区开启流式输出，使用 SSE 增量显示翻译结果；默认关闭，非流式路径保留。
- 登录时启动：可在设置区开启或关闭 macOS 登录项。
- 安装清理：提供安装脚本，将 Release App 安装到 `~/Applications/TranslateBar.app`，并清理重复构建产物，避免启动台出现多个同名 App。

## 运行要求

- macOS 15.0 或更高版本。
- Xcode。
- 本地 OpenAI Chat Completions 兼容服务。

默认服务配置：

```text
Endpoint: http://127.0.0.1:8787/v1/chat/completions
Model: /Users/jafish/Documents/models/Hy-MT2-7B-4bit
```

服务需要支持：

- `POST /v1/chat/completions`
- 非流式响应路径：`choices[0].message.content`
- 可选流式响应：`stream: true`，SSE `data:` 行，增量路径 `choices[0].delta.content`，结束标记 `data: [DONE]`
- 可选模型列表：`GET /v1/models`，模型 id 路径 `data[].id`

## 安装

在项目根目录执行：

```bash
./scripts/install_app.sh
```

脚本会执行以下操作：

1. 构建 Release 版本。
2. 安装到 `~/Applications/TranslateBar.app`。
3. 清理 DerivedData 和项目根目录里的重复 `TranslateBar.app`。
4. 重新注册 LaunchServices。
5. 验证 App 签名和安装结果。

安装后可启动：

```bash
open ~/Applications/TranslateBar.app
```

## 使用方式

1. 启动 App 后，点击菜单栏里的 TranslateBar 图标。
2. 在输入框中输入要翻译的文本。
3. 选择“自动”“中译英”或“英译中”。
4. 查看翻译结果，必要时点击“复制”。
5. 点击齿轮按钮打开设置区，可修改服务地址、模型路径、刷新模型列表、开启流式输出或登录时启动。

## 开发

Debug 构建：

```bash
xcodebuild \
  -project TranslateBar.xcodeproj \
  -scheme TranslateBar \
  -configuration Debug \
  build
```

Release 安装建议统一使用：

```bash
./scripts/install_app.sh
```

## 计划文档

项目使用轻量计划治理记录阶段交付：

- [计划索引](docs/PLAN_MAP.md)
- [v1 实现计划](docs/plans/translatebar-v1.md)
- [服务设置与安装计划](docs/plans/service-settings-and-install.md)
- [安装清理与登录项计划](docs/plans/install-cleanup-and-login-item.md)
- [模型列表选择计划](docs/plans/model-list-selection.md)
- [流式翻译计划](docs/plans/streaming-translation.md)

## 已知边界

- App 不负责启动或管理本地模型服务。
- App 不自动下载模型。
- 当前产品范围主要面向中英互译。
- 如果服务地址不是 `/v1/chat/completions` 结尾，App 无法自动推导 `/v1/models`，仍可手动填写模型路径。
