import XCTest
@testable import TranslateBar

final class ModelsTests: XCTestCase {
    // MARK: - ChatCompletionRequest

    func test_requestEncode_containsAllFields() throws {
        let request = ChatCompletionRequest(
            model: "test-model",
            messages: [ChatMessage(role: "user", content: "hello")],
            temperature: 0.1,
            topP: 0.6,
            maxTokens: 4096,
            stream: false,
            chatTemplateKwargs: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["model"] as? String, "test-model")
        XCTAssertEqual(dict?["temperature"] as? Double, 0.1)
        XCTAssertEqual(dict?["top_p"] as? Double, 0.6)
        XCTAssertEqual(dict?["max_tokens"] as? Int, 4096)
        XCTAssertEqual(dict?["stream"] as? Bool, false)
    }

    func test_requestEncode_streamTrue() throws {
        let request = ChatCompletionRequest(
            model: "m", messages: [], temperature: 0, topP: 1, maxTokens: 100, stream: true, chatTemplateKwargs: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["stream"] as? Bool, true)
    }

    func test_requestEncode_messagesNested() throws {
        let msg = ChatMessage(role: "system", content: "You are a translator.")
        let request = ChatCompletionRequest(
            model: "m", messages: [msg], temperature: 0, topP: 1, maxTokens: 100, stream: false, chatTemplateKwargs: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let msgs = dict?["messages"] as? [[String: Any]]
        XCTAssertEqual(msgs?.first?["role"] as? String, "system")
        XCTAssertEqual(msgs?.first?["content"] as? String, "You are a translator.")
    }

    // MARK: - ChatMessage

    func test_chatMessageCodableRoundTrip() throws {
        let msg = ChatMessage(role: "user", content: "你好")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.role, "user")
        XCTAssertEqual(decoded.content, "你好")
    }

    // MARK: - ChatCompletionResponse

    func test_chatCompletionResponse_decodeWithMessage() throws {
        let json = #"{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}"#
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.choices.first?.message?.content, "Hello")
    }

    func test_chatCompletionResponse_decodeWithText() throws {
        let json = #"{"choices":[{"text":"Hello"}]}"#
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.choices.first?.text, "Hello")
        XCTAssertNil(response.choices.first?.message)
    }

    func test_chatCompletionResponse_decodeEmptyChoices() throws {
        let json = #"{"choices":[]}"#
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(response.choices.isEmpty)
    }

    // MARK: - APIErrorResponse

    func test_apiErrorResponse_decodeWithError() throws {
        let json = #"{"error":{"message":"Model not found","type":"invalid_request_error"}}"#
        let response = try JSONDecoder().decode(APIErrorResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.error?.message, "Model not found")
        XCTAssertEqual(response.error?.type, "invalid_request_error")
    }

    func test_apiErrorResponse_decodeNullError() throws {
        let json = #"{"error":null}"#
        let response = try JSONDecoder().decode(APIErrorResponse.self, from: json.data(using: .utf8)!)
        XCTAssertNil(response.error)
    }

    // MARK: - ModelListResponse

    func test_modelListResponse_decodeNormal() throws {
        let json = #"{"data":[{"id":"model-a"},{"id":"model-b"}]}"#
        let response = try JSONDecoder().decode(ModelListResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.data.map(\.id), ["model-a", "model-b"])
    }

    func test_modelListResponse_decodeEmptyData() throws {
        let json = #"{"data":[]}"#
        let response = try JSONDecoder().decode(ModelListResponse.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(response.data.isEmpty)
    }

    // MARK: - ChatCompletionChunk (SSE)

    func test_chunk_decodeWithDeltaContent() throws {
        let json = #"{"choices":[{"delta":{"content":"你好"},"finish_reason":null}]}"#
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(chunk.choices.first?.delta?.content, "你好")
    }

    func test_chunk_decodeNoContent() throws {
        let json = #"{"choices":[{"delta":{},"finish_reason":"stop"}]}"#
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json.data(using: .utf8)!)
        XCTAssertNil(chunk.choices.first?.delta?.content)
        XCTAssertEqual(chunk.choices.first?.finishReason, "stop")
    }

    func test_chunk_finishReasonCodingKey() throws {
        let json = #"{"choices":[{"delta":{"content":""},"finish_reason":"length"}]}"#
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(chunk.choices.first?.finishReason, "length")
    }

    // MARK: - ChatTemplateKwargs

    func test_requestEncode_withDisableThinking() throws {
        let request = ChatCompletionRequest(
            model: "m",
            messages: [ChatMessage(role: "user", content: "hi")],
            temperature: 0,
            topP: 1,
            maxTokens: 100,
            stream: false,
            chatTemplateKwargs: ChatTemplateKwargs(enableThinking: false)
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let kwargs = dict?["chat_template_kwargs"] as? [String: Any]
        XCTAssertEqual(kwargs?["enable_thinking"] as? Bool, false)
    }

    func test_requestEncode_disableThinkingUsesSnakeCase() throws {
        let kwargs = ChatTemplateKwargs(enableThinking: true)
        let data = try JSONEncoder().encode(kwargs)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // snake_case key should be "enable_thinking", not "enableThinking"
        XCTAssertEqual(dict?["enable_thinking"] as? Bool, true)
        XCTAssertNil(dict?["enableThinking"])
    }

    // MARK: - TranslationProvider

    func test_translationProvider_rawValues() {
        XCTAssertEqual(TranslationProvider.local.rawValue, "local")
        XCTAssertEqual(TranslationProvider.deepseek.rawValue, "deepseek")
    }

    func test_translationProvider_displayNames() {
        XCTAssertEqual(TranslationProvider.local.displayName, "本地")
        XCTAssertEqual(TranslationProvider.deepseek.displayName, "DeepSeek")
    }

    func test_translationProvider_allCases() {
        XCTAssertEqual(TranslationProvider.allCases.count, 2)
    }

    func test_translationProvider_idEqualsRawValue() {
        for provider in TranslationProvider.allCases {
            XCTAssertEqual(provider.id, provider.rawValue)
        }
    }

    // MARK: - TranslationMode

    func test_translationMode_rawValues() {
        XCTAssertEqual(TranslationMode.auto.rawValue, "自动")
        XCTAssertEqual(TranslationMode.zhToEn.rawValue, "中译英")
        XCTAssertEqual(TranslationMode.enToZh.rawValue, "英译中")
    }

    func test_translationMode_allCases() {
        XCTAssertEqual(TranslationMode.allCases.count, 3)
    }

    func test_translationMode_idEqualsRawValue() {
        for mode in TranslationMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func test_targetDescription_zhToEn() {
        XCTAssertEqual(TranslationMode.zhToEn.targetDescription(for: "任意文本"), "English")
    }

    func test_targetDescription_enToZh() {
        XCTAssertEqual(TranslationMode.enToZh.targetDescription(for: "any text"), "Chinese")
    }

    func test_targetDescription_autoChineseText() {
        XCTAssertEqual(TranslationMode.auto.targetDescription(for: "你好世界"), "English")
    }

    func test_targetDescription_autoEnglishText() {
        XCTAssertEqual(TranslationMode.auto.targetDescription(for: "Hello world"), "Chinese")
    }

    func test_targetDescription_autoNumbersOnly() {
        XCTAssertEqual(TranslationMode.auto.targetDescription(for: "12345"), "Chinese")
    }

    func test_isMostlyChinese_pureChinese() {
        let mode = TranslationMode.auto
        XCTAssertEqual(mode.targetDescription(for: "你好"), "English")
    }

    func test_isMostlyChinese_pureEnglish() {
        let mode = TranslationMode.auto
        XCTAssertEqual(mode.targetDescription(for: "Hello world"), "Chinese")
    }

    func test_isMostlyChinese_boundary0x4E00() {
        let mode = TranslationMode.auto
        let char = String(UnicodeScalar(0x4E00)!)
        XCTAssertEqual(mode.targetDescription(for: char), "English")
    }

    func test_isMostlyChinese_boundary0x9FFF() {
        let mode = TranslationMode.auto
        let char = String(UnicodeScalar(0x9FFF)!)
        XCTAssertEqual(mode.targetDescription(for: char), "English")
    }

    func test_isMostlyChinese_emptyString() {
        let mode = TranslationMode.auto
        XCTAssertEqual(mode.targetDescription(for: ""), "Chinese")
    }

    func test_isMostlyChinese_numbersOnly() {
        let mode = TranslationMode.auto
        XCTAssertEqual(mode.targetDescription(for: "12345"), "Chinese")
    }

    // MARK: - isMostlyChinese 占比规则

    func test_isMostlyChinese_singleChineseInEnglish() {
        let mode = TranslationMode.auto
        // chineseCount=1, latinCount≥10 → 中文只是引用 → target Chinese
        XCTAssertEqual(mode.targetDescription(for: "App has started with character 译 icon"), "Chinese")
    }

    func test_isMostlyChinese_twoChineseInLongEnglish() {
        let mode = TranslationMode.auto
        // chineseCount=2, latinCount≥10 → short-text rule → target Chinese
        XCTAssertEqual(mode.targetDescription(for: "This application supports translation 中文 English"), "Chinese")
    }

    func test_isMostlyChinese_step0Sample() {
        let mode = TranslationMode.auto
        let text = """
        App has started. Now it's the "译" character icon with regular font weight + rounded border, see the effect?
        """
        // chineseCount=1, latinCount≥10 → 英文主导夹带中文引用 → target Chinese
        XCTAssertEqual(mode.targetDescription(for: text), "Chinese")
    }

    func test_isMostlyChinese_helloWorldMixed() {
        let mode = TranslationMode.auto
        // "Hello 世界": chineseCount=2, latinCount=5 → 2/(2+5)=28.6% < 30% → target Chinese
        XCTAssertEqual(mode.targetDescription(for: "Hello 世界"), "Chinese")
    }

    func test_isMostlyChinese_chineseDominant() {
        let mode = TranslationMode.auto
        // "你好 world": chineseCount=2, latinCount=5 → 2/7=28.6% < 30% → target Chinese
        // Need a case with 30%+: "你好你好 world" → 4/(4+5)=44.4% → target English
        XCTAssertEqual(mode.targetDescription(for: "你好你好 world"), "English")
    }

    func test_isMostlyChinese_chineseMajorInMix() {
        let mode = TranslationMode.auto
        // "你好你好你好你好 world": 8/(8+5)=61.5% → target English
        XCTAssertEqual(mode.targetDescription(for: "你好你好你好你好 world"), "English")
    }

    // MARK: - TranslationError

    func test_translationError_invalidEndpointEmpty() {
        let error = TranslationError.invalidEndpoint("")
        XCTAssertTrue(error.errorDescription?.contains("空地址") ?? false)
    }

    func test_translationError_invalidEndpointWithValue() {
        let error = TranslationError.invalidEndpoint("bad url")
        XCTAssertTrue(error.errorDescription?.contains("bad url") ?? false)
    }

    func test_translationError_emptyModel() {
        let error = TranslationError.emptyModel
        XCTAssertTrue(error.errorDescription?.contains("模型路径不能为空") ?? false)
    }

    func test_translationError_invalidResponse() {
        let error = TranslationError.invalidResponse
        XCTAssertTrue(error.errorDescription?.contains("无效响应") ?? false)
    }

    func test_translationError_emptyContent() {
        let error = TranslationError.emptyContent
        XCTAssertTrue(error.errorDescription?.contains("空结果") ?? false)
    }

    func test_translationError_httpError() {
        let error = TranslationError.httpError(statusCode: 500, message: "Internal Server Error")
        let desc = error.errorDescription ?? ""
        XCTAssertTrue(desc.contains("500"))
        XCTAssertTrue(desc.contains("Internal Server Error"))
    }

    func test_translationError_conformsToLocalizedError() {
        let error: LocalizedError = TranslationError.emptyModel
        XCTAssertNotNil(error.errorDescription)
    }
}
