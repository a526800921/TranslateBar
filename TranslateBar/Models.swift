import Foundation

// MARK: - Provider

enum TranslationProvider: String, CaseIterable, Identifiable {
    case local
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local:
            return "本地"
        case .deepseek:
            return "DeepSeek"
        }
    }
}

// MARK: - Request

struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let stream: Bool
    let chatTemplateKwargs: ChatTemplateKwargs?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stream
        case chatTemplateKwargs = "chat_template_kwargs"
    }
}

struct ChatTemplateKwargs: Encodable {
    let enableThinking: Bool

    enum CodingKeys: String, CodingKey {
        case enableThinking = "enable_thinking"
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

struct ModelListResponse: Decodable {
    let data: [ModelItem]
}

struct ModelItem: Decodable {
    let id: String
}

struct ChatCompletionChunk: Decodable {
    let choices: [ChunkChoice]
}

struct ChunkChoice: Decodable {
    let delta: ChunkDelta?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct ChunkDelta: Decodable {
    let content: String?
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
    case invalidEndpoint(String)
    case emptyModel
    case invalidResponse
    case emptyContent
    case httpError(statusCode: Int, message: String)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case let .invalidEndpoint(endpoint):
            return "服务地址无效：\(endpoint.isEmpty ? "空地址" : endpoint)"
        case .emptyModel:
            return "模型路径不能为空。"
        case .invalidResponse:
            return "翻译服务返回了无效响应。"
        case .emptyContent:
            return "翻译服务返回了空结果，请检查模型输出格式。"
        case let .httpError(statusCode, message):
            return "翻译服务返回 HTTP \(statusCode)：\(message)"
        case .missingAPIKey:
            return "DeepSeek API Key 未配置，请在设置中填写 API Key。"
        }
    }
}
