# TranslateBar

macOS 菜单栏翻译 App，支持本地模型和 DeepSeek 云端模型的中英互译。

## 快速开始

```bash
git clone https://github.com/a526800921/TranslateBar.git
xattr -cr TranslateBar/dist/TranslateBar.app
open TranslateBar/dist/TranslateBar.app
```

启动后在设置中切换到 DeepSeek 并填写 API Key 即可使用。

> 仅支持 Apple Silicon (arm64)，macOS 15.0+。Ad-hoc 签名，首次需 `xattr -cr` 移除 Gatekeeper 隔离。

## 使用

1. 点击菜单栏"译"字图标弹出面板
2. 输入待翻译文本
3. 选择翻译模式：自动 / 中译英 / 英译中
4. 齿轮按钮 → 设置翻译服务、API Key、流式输出、登录项等

## 翻译模式

| 模式 | 行为 |
|------|------|
| 自动 | 主语言占比判断——中文为主则翻英文，英文为主则翻中文 |
| 中译英 | 始终翻成英文 |
| 英译中 | 始终翻成中文 |

## 翻译服务

| Provider | 默认地址 | 鉴权 |
|----------|----------|------|
| 本地 | `http://127.0.0.1:8787/v1/chat/completions` | 无 |
| DeepSeek | `https://api.deepseek.com/v1/chat/completions` | API Key |

服务需兼容 OpenAI Chat Completions 格式（非流式 `choices[0].message.content`，流式 SSE `choices[0].delta.content`，模型列表 `GET /v1/models`）。

## 开发

```bash
./scripts/build_and_run.sh    # Release 构建、启动、更新根目录 TranslateBar.app
```

## 测试

```bash
xcodebuild test \
  -project TranslateBar.xcodeproj \
  -scheme TranslateBar \
  -destination 'platform=macOS,arch=arm64'
```

166 个测试，7 个测试套件。Mock 层通过 `URLSessionProtocol` / `SMAppServiceProtocol` 协议抽象注入。

## 计划文档

- [计划索引](docs/PLAN_MAP.md)
- [DeepSeek 云端支持](docs/plans/deepseek-cloud-support-implementation.md)
- [自动语言检测](docs/plans/auto-language-detection.md)
- 更多：`docs/plans/`
