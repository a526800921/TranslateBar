import Foundation


@MainActor
final class TranslationService: ObservableObject {
    @Published var result = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentTask: Task<Void, Never>?
    private var currentTranslateId: UUID?
    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    func translate(text: String, mode: TranslationMode) {
        currentTask?.cancel()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            result = ""
            errorMessage = nil
            isLoading = false
            currentTranslateId = nil
            return
        }

        let id = UUID()
        currentTranslateId = id

        currentTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.performTranslation(text: trimmedText, mode: mode, id: id)
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        currentTranslateId = nil
        isLoading = false
    }

    private func performTranslation(text: String, mode: TranslationMode, id: UUID) async {
        guard currentTranslateId == id else { return }
        let t0 = CFAbsoluteTimeGetCurrent()

        isLoading = true
        errorMessage = nil

        do {
            let configuration = try makeConfiguration()
            let tConfig = CFAbsoluteTimeGetCurrent()

            guard let endpoint = configuration.endpoint else {
                throw TranslationError.invalidEndpoint(configuration.endpointString)
            }

            if configuration.streamingEnabled {
                try await performStreamingTranslation(
                    text: text,
                    mode: mode,
                    configuration: configuration,
                    endpoint: endpoint,
                    id: id,
                    tStart: t0
                )
            } else {
                try await performNonStreamingTranslation(
                    text: text,
                    mode: mode,
                    configuration: configuration,
                    endpoint: endpoint,
                    id: id,
                    tStart: t0
                )
            }
        } catch is CancellationError {
            return
        } catch {
            guard currentTranslateId == id else { return }
            errorMessage = readableError(error)
        }

        if currentTranslateId == id {
            isLoading = false
        }
    }

    // MARK: - Request Builder

    private func makeRequest(
        endpoint: URL,
        configuration: TranslationConfiguration,
        stream: Bool,
        prompt: String
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if configuration.provider == .deepseek {
            guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
                throw TranslationError.missingAPIKey
            }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = ChatCompletionRequest(
            model: configuration.model,
            messages: [
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.1,
            topP: 0.6,
            maxTokens: 4096,
            stream: stream,
            chatTemplateKwargs: ChatTemplateKwargs(enableThinking: false)
        )

        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    // MARK: - Non-Streaming

    private func performNonStreamingTranslation(
        text: String,
        mode: TranslationMode,
        configuration: TranslationConfiguration,
        endpoint: URL,
        id: UUID,
        tStart: CFAbsoluteTime
    ) async throws {
        let t0 = CFAbsoluteTimeGetCurrent()
        let request = try makeRequest(
            endpoint: endpoint,
            configuration: configuration,
            stream: false,
            prompt: makePrompt(text: text, mode: mode)
        )
        let tReq = CFAbsoluteTimeGetCurrent()

        let (data, response) = try await session.data(for: request)
        let tNet = CFAbsoluteTimeGetCurrent()
        let networkMs = (tNet - tReq) * 1000
        guard currentTranslateId == id else { return }

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
        let tParse = CFAbsoluteTimeGetCurrent()
        let content = decoded.choices.first?.message?.content ?? decoded.choices.first?.text
        let translatedText = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if translatedText.isEmpty {
            throw TranslationError.emptyContent
        }

        guard currentTranslateId == id else { return }
        result = translatedText
    }

    // MARK: - Streaming

    private func performStreamingTranslation(
        text: String,
        mode: TranslationMode,
        configuration: TranslationConfiguration,
        endpoint: URL,
        id: UUID,
        tStart: CFAbsoluteTime
    ) async throws {
        let t0 = CFAbsoluteTimeGetCurrent()
        let request = try makeRequest(
            endpoint: endpoint,
            configuration: configuration,
            stream: true,
            prompt: makePrompt(text: text, mode: mode)
        )
        let tReq = CFAbsoluteTimeGetCurrent()

        let (byteStream, response) = try await session.bytesStream(for: request)
        let tConn = CFAbsoluteTimeGetCurrent()
        guard currentTranslateId == id else { return }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            var errorBody = Data()
            for try await byte in byteStream {
                errorBody.append(byte)
                if errorBody.count >= 500 { break }
            }
            let message = String(data: errorBody, encoding: .utf8) ?? ""
            throw TranslationError.httpError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        guard currentTranslateId == id else { return }
        result = ""
        var firstToken = true
        var firstTokenTime: CFAbsoluteTime = 0
        var totalChars = 0

        for try await line in lines(from: byteStream) {
            guard currentTranslateId == id else { return }

            if line.hasPrefix(":") { continue }
            if line == "data: [DONE]" { break }
            guard line.hasPrefix("data: ") else { continue }

            let jsonString = String(line.dropFirst(6))
            guard let jsonData = jsonString.data(using: .utf8) else { continue }

            do {
                let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: jsonData)
                if let content = chunk.choices.first?.delta?.content {
                    if firstToken {
                        firstTokenTime = CFAbsoluteTimeGetCurrent()
                        let ttfb = (firstTokenTime - tReq) * 1000
                        firstToken = false
                    }
                    result += content
                    totalChars += content.count
                }
            } catch {
                continue
            }
        }

        let tEnd = CFAbsoluteTimeGetCurrent()
        let totalMs = (tEnd - tStart) * 1000
        let genMs = firstToken ? 0 : (tEnd - firstTokenTime) * 1000

        if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard currentTranslateId == id else { return }
            throw TranslationError.emptyContent
        }
    }

    func makePrompt(text: String, mode: TranslationMode) -> String {
        let target = mode.targetDescription(for: text)

        return """
        Translate the following text to \(target).
        Only output the translated result. Do not explain, summarize, add markdown, or wrap the answer in quotes.

        \(text)
        """
    }

    func parseErrorMessage(from data: Data) -> String {
        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
           let message = apiError.error?.message,
           !message.isEmpty {
            return message
        }

        return String(data: data, encoding: .utf8)?.prefix(500).description ?? "Unknown error"
    }

    func makeConfiguration(defaults: UserDefaults = .standard) throws -> TranslationConfiguration {
        let configuration = TranslationConfiguration.current(defaults: defaults)

        if configuration.endpointString.isEmpty {
            throw TranslationError.invalidEndpoint(configuration.endpointString)
        }

        if configuration.model.isEmpty {
            throw TranslationError.emptyModel
        }

        if configuration.provider == .deepseek {
            guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
                throw TranslationError.missingAPIKey
            }
        }

        return configuration
    }

    /// 将字节流按换行符拆分为字符串行
    private func lines(from stream: AsyncThrowingStream<UInt8, any Error>) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                do {
                    for try await byte in stream {
                        if byte == 0x0A { // \n
                            if let line = String(data: buffer, encoding: .utf8) {
                                continuation.yield(line)
                            }
                            buffer = Data()
                        } else {
                            buffer.append(byte)
                        }
                    }
                    if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func readableError(_ error: Error) -> String {
        if let translationError = error as? TranslationError {
            return translationError.localizedDescription
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost:
                let config = TranslationConfiguration.current()
                if config.provider == .deepseek {
                    return "无法连接 DeepSeek 翻译服务，请检查网络、API key 或 \(config.endpointString)。"
                }
                return "无法连接本地翻译服务，请确认 \(config.endpointString) 可访问。"
            case .timedOut:
                return "翻译请求超时，模型可能仍在推理或文本过长。"
            default:
                return "网络错误：\(urlError.localizedDescription)"
            }
        }

        return "翻译失败：\(error.localizedDescription)"
    }
}
