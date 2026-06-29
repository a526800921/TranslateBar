# 计划：auto-language-detection

## 状态

待实施

## 背景

当前 `TranslationMode.auto.targetDescription(for:)` 使用简单规则判断自动翻译方向：

- 输入中包含任意中文 Unicode 标量，则认为源语言是中文，目标语言为英文。
- 否则认为源语言是英文或非中文，目标语言为中文。

这个规则在英文文本中夹带少量中文词、菜单栏图标名、产品名或引用字符时会误判。例如：

```text
App has started. Now it's the "译" character icon with regular font weight + rounded border, see the effect?
```

这句话的主语言是英文，但因为包含一个中文字符 `译`，当前规则会判定为中文源文，目标语言变成英文。用户预期是翻译成中文。

## 目标

1. 自动模式改为根据主语言占比判断翻译方向。
2. 英文主文本中夹带少量中文字符时，目标语言应为中文。
3. 中文主文本或中文占比较高的中英混合文本，目标语言仍为英文。
4. 保留显式 `中译英` 和 `英译中` 模式的现有行为。
5. 增加单元测试覆盖混合文本、边界字符、纯中文、纯英文和短文本场景。

## 非目标

- 不引入第三方语言检测库。
- 不调用模型做语言识别。
- 不新增 UI 设置项。
- 不支持多语言精细识别；自动模式仍只决定“翻成中文”或“翻成英文”。
- 不改变 prompt 的其他结构。

## 涉及文件

- `TranslateBar/Models.swift`
- `TranslateBarTests/ModelsTests.swift`
- 如测试间接依赖 prompt，可补充 `TranslateBarTests/TranslationServiceTests.swift`

## Step 0 证据

### 当前失败样本

输入：

```text
App has started. Now it's the "译" character icon with regular font weight + rounded border, see the effect?
```

当前行为：

- 因包含中文字符 `译`，`auto` 模式目标语言为 `English`。

期望行为：

- 主语言是英文，`auto` 模式目标语言应为 `Chinese`。

### 当前测试基线

现有测试已经覆盖：

- `test_targetDescription_autoChineseText`
- `test_targetDescription_autoEnglishText`
- `test_containsChinese_pureChinese`
- `test_containsChinese_mixedCNandEN`
- `test_containsChinese_boundary0x4E00`
- `test_containsChinese_boundary0x9FFF`
- `test_containsChinese_emptyString`

其中 `test_containsChinese_mixedCNandEN` 当前将 `Hello 世界` 判定为 `English`。新规则需要重新定义这种混合文本的预期。

## 方案

### 主语言占比规则

新增或替换当前私有判断逻辑：

```swift
private func isMostlyChinese(_ text: String) -> Bool {
    let scalars = text.unicodeScalars
    let chineseCount = scalars.filter { scalar in
        (0x4E00...0x9FFF).contains(scalar.value)
    }.count
    let latinCount = scalars.filter { scalar in
        (0x41...0x5A).contains(scalar.value) ||
        (0x61...0x7A).contains(scalar.value)
    }.count

    guard chineseCount + latinCount > 0 else {
        return false
    }

    if chineseCount <= 2, latinCount >= 10 {
        return false
    }

    return Double(chineseCount) / Double(chineseCount + latinCount) >= 0.3
}
```

`auto` 模式使用：

```swift
return isMostlyChinese(text) ? "English" : "Chinese"
```

### 判断说明

- 只统计 CJK 基本区中文字符和英文字母，不统计数字、标点、空格、引号和符号。
- `chineseCount <= 2 && latinCount >= 10` 时，认为中文只是引用、图标名或短词，不主导文本。
- 中文占比达到 30% 时，认为中文是主语言或足够主导，目标语言为英文。
- 没有中文也没有英文字母时，沿用当前默认目标中文。

## 当前阶段步骤

1. 修改 `TranslationMode.auto` 的语言判断逻辑。
2. 将 `containsChinese` 重命名或替换为 `isMostlyChinese`，保持私有实现。
3. 更新 `ModelsTests` 中自动模式测试：
   - 英文主文本夹带单个中文字符 → `Chinese`
   - 英文主文本夹带两个中文字符且英文较长 → `Chinese`
   - `Hello 世界` 按新规则判定为 `Chinese`，因为中文占比不足 30%
   - `你好 world` 按占比判定，中文占比达到阈值时为 `English`
   - 纯中文 → `English`
   - 纯英文 → `Chinese`
   - 数字/符号-only → `Chinese`
   - CJK 边界字符仍可统计为中文
4. 如 `TranslationService.makePrompt` 测试依赖自动方向，补充一个英文夹中文的 prompt 测试。
5. 运行完整测试。
6. 运行 GitNexus `detect_changes()`。

## 验证方式

自动化测试：

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

手动验收：

1. 选择 `自动` 模式。
2. 输入：
   ```text
   App has started. Now it's the "译" character icon with regular font weight + rounded border, see the effect?
   ```
3. 期望翻译结果为中文。
4. 输入纯中文句子，期望翻译结果为英文。
5. 输入中英混合但中文占主要比例的句子，期望翻译结果为英文。

## 完成条件

- 英文主文本夹带少量中文字符时，自动模式目标语言为中文。
- 中文主文本或中文占比较高文本时，自动模式目标语言为英文。
- 显式 `中译英`、`英译中` 行为不变。
- 单元测试覆盖新规则和回归样本。
- 完整测试通过。
- GitNexus `detect_changes()` 影响范围符合预期。

## 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| 阈值 30% 对部分混合文本仍可能不符合用户预期 | 中 | 先覆盖当前真实样本；后续根据更多样本调整阈值 |
| 日文汉字或其他 CJK 字符会被当作中文 | 低 | 当前 App 只决定中英方向，暂不扩展多语识别 |
| 英文很短且夹中文时判断不稳定 | 中 | 用短文本规则降低单个中文引用导致的误判 |
| 更改 `Hello 世界` 旧测试预期 | 低 | 在计划和测试名中明确新规则为主语言占比 |

## 回滚方案

如新规则带来更多误判，可回滚为旧的 `containsChinese` 判断，或将阈值和短文本规则调整为更保守的值。
