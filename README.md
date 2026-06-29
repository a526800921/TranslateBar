# TranslateBar

TranslateBar 是一个 macOS 菜单栏翻译 App，支持本地模型和 DeepSeek 云端模型的中英互译。

## 快速开始

```bash
git clone https://github.com/a526800921/TranslateBar.git
xattr -cr TranslateBar/TranslateBar.app      # 移除 Gatekeeper 隔离
open TranslateBar/TranslateBar.app           # 或直接双击
```

启动后在设置中切换到 DeepSeek 并填写 API Key 即可使用。仅支持 **Apple Silicon (arm64)**，macOS 15.0+。

## 翻译服务

App 支持两种 provider，在设置中切换：

| Provider | 说明 |
|----------|------|
| 本地 | 连接本机 OpenAI Chat Completions 兼容服务（`http://127.0.0.1:8787/v1/chat/completions`） |
| DeepSeek | 云端 API（`https://api.deepseek.com/v1/chat/completions`），需填写 API Key |

服务需要支持：

- `POST /v1/chat/completions`
- 非流式响应路径：`choices[0].message.content`
- 可选流式响应：`stream: true`，SSE `data:` 行，增量路径 `choices[0].delta.content`，结束标记 `data: [DONE]`
- 可选模型列表：`GET /v1/models`，模型 id 路径 `data[].id`

## 当前功能

- 菜单栏常驻：点击”译”字图标弹出面板，不占用 Dock。
- 中英互译：自动 / 中译英 / 英译中三种模式。
- 自动翻译：300ms 防抖，输入停止后自动触发。
- 流式输出：可选开启，SSE 增量显示翻译结果。
- 模型列表：从 `/v1/models` 读取可用模型。
- 登录时启动：可选开启或关闭。

## 开发

构建与启动：

```bash
./scripts/build_and_run.sh    # Release 构建、启动，同时更新根目录 TranslateBar.app
```

## 测试

```bash
# 运行全部测试（含覆盖率）
xcodebuild test \
  -project TranslateBar.xcodeproj \
  -scheme TranslateBar \
  -destination 'platform=macOS,arch=arm64' \
  -enableCodeCoverage YES
```

当前覆盖率：**90.2%**（136 个测试，核心逻辑 96.5%）。

测试架构：
- 协议抽象层（`URLSessionProtocol` / `SMAppServiceProtocol`）通过依赖注入解耦网络和系统服务
- Mock 层（`MockURLSession` / `MockSMAppService`）模拟外部依赖
- `TranslatePanelView` 子视图可见性改为 internal，支持独立渲染测试
- `URLProtocol` 子类覆盖 `URLSession` 协议扩展的流式方法

## 计划文档

- [计划索引](docs/PLAN_MAP.md)
- [DeepSeek 云端支持](docs/plans/deepseek-cloud-support-implementation.md)
- [自动语言检测](docs/plans/auto-language-detection.md)
- 更多：`docs/plans/`

## 已知边界

- App 不负责启动或管理本地模型服务。
- 仅 arm64，Intel Mac 不支持。
- Ad-hoc 签名，首次需 `xattr -cr` 移除 Gatekeeper 隔离。
